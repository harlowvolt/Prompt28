import Foundation
import SwiftUI
import Combine
import Speech
import AVFoundation

@MainActor
protocol SpeechRecognizing: AnyObject {
    var isRecording: Bool { get }
    var transcript: String { get }
    var finalTranscript: String { get }
    var permissionStatus: SpeechRecognizerService.PermissionStatus { get }
    var audioLevel: CGFloat { get }

    var isRecordingPublisher: AnyPublisher<Bool, Never> { get }
    var transcriptPublisher: AnyPublisher<String, Never> { get }
    var finalTranscriptPublisher: AnyPublisher<String, Never> { get }
    var permissionStatusPublisher: AnyPublisher<SpeechRecognizerService.PermissionStatus, Never> { get }
    var audioLevelPublisher: AnyPublisher<CGFloat, Never> { get }

    func startRecording()
    func stopRecording()
    func reset()
}

@MainActor
final class SpeechRecognizerService: NSObject, ObservableObject, SpeechRecognizing {

    enum PermissionStatus: Equatable {
        case notDetermined
        case granted
        case speechDenied
        case microphoneDenied
        case restricted
        case unavailable
        case error(String)
    }

    @Published private(set) var isRecording: Bool = false
    @Published private(set) var transcript: String = ""
    @Published private(set) var finalTranscript: String = ""
    @Published private(set) var permissionStatus: PermissionStatus = .notDetermined
    @Published private(set) var audioLevel: CGFloat = 0

    var isRecordingPublisher: AnyPublisher<Bool, Never> { $isRecording.eraseToAnyPublisher() }
    var transcriptPublisher: AnyPublisher<String, Never> { $transcript.eraseToAnyPublisher() }
    var finalTranscriptPublisher: AnyPublisher<String, Never> { $finalTranscript.eraseToAnyPublisher() }
    var permissionStatusPublisher: AnyPublisher<PermissionStatus, Never> { $permissionStatus.eraseToAnyPublisher() }
    var audioLevelPublisher: AnyPublisher<CGFloat, Never> { $audioLevel.eraseToAnyPublisher() }

    private let audioEngine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var watchdogTask: Task<Void, Never>?

    init(locale: Locale = .current) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
        super.init()
        self.recognizer?.delegate = self
        Task { await refreshPermissions() }
    }

    func startRecording() {
        Task {
            await refreshPermissions()

            guard permissionStatus == .granted else { return }
            guard !isRecording else { return }
            guard let recognizer, recognizer.isAvailable else {
                permissionStatus = .unavailable
                return
            }

            reset()

            do {
                try configureAudioSession()
                try startRecognition(with: recognizer)
                isRecording = true
                startWatchdog()
            } catch {
                permissionStatus = .error(error.localizedDescription)
                failAndStop(message: "Unable to start speech recognition.")
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil

        isRecording = false

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            finalTranscript = trimmed
        }

        audioLevel = 0
    }

    func reset() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        watchdogTask?.cancel()
        watchdogTask = nil

        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }

        transcript = ""
        finalTranscript = ""
        audioLevel = 0
        isRecording = false
    }

    private func refreshPermissions() async {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()

        switch speechStatus {
        case .notDetermined:
            let granted = await requestSpeechPermission()
            if !granted {
                permissionStatus = .speechDenied
                return
            }
        case .authorized:
            break
        case .denied:
            permissionStatus = .speechDenied
            return
        case .restricted:
            permissionStatus = .restricted
            return
        @unknown default:
            permissionStatus = .speechDenied
            return
        }

        let micGranted = await requestMicrophonePermission()
        permissionStatus = micGranted ? .granted : .microphoneDenied
    }

    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startRecognition(with recognizer: SFSpeechRecognizer) throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 16, *) {
            request.addsPunctuation = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)
            Task { @MainActor in
                self.updateAudioLevel(from: buffer)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            Task { @MainActor in
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.finalTranscript = result.bestTranscription.formattedString
                        self.stopRecording()
                    }
                }

                if error != nil {
                    self.failAndStop(message: "Speech recognition failed.")
                }
            }
        }
    }

    private func startWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard let self else { return }
            await MainActor.run {
                if self.isRecording {
                    self.stopRecording()
                }
            }
        }
    }

    private func failAndStop(message: String) {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        isRecording = false
        audioLevel = 0
        permissionStatus = .error(message)
    }

    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else {
            audioLevel = 0
            return
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            audioLevel = 0
            return
        }

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }

        let average = sum / Float(frameLength)
        let normalized = min(max(CGFloat(average * 8), 0), 1)
        audioLevel = normalized
    }
}

extension SpeechRecognizerService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if available {
                if case .unavailable = self.permissionStatus {
                    self.permissionStatus = .granted
                }
            } else {
                self.permissionStatus = .unavailable
                if self.isRecording {
                    self.failAndStop(message: "Speech recognizer became unavailable.")
                }
            }
        }
    }
}
