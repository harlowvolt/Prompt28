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
    private var isStoppingIntentionally = false

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
            isStoppingIntentionally = false

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

        isStoppingIntentionally = true

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        watchdogTask?.cancel()
        watchdogTask = nil

        isRecording = false

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            finalTranscript = trimmed
        }

        audioLevel = 0

        // If recognizer never emits a final callback, clean up after a short grace period.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.8))
            await MainActor.run {
                guard let self else { return }
                self.recognitionTask?.cancel()
                self.recognitionTask = nil
                self.recognitionRequest = nil
                self.deactivateAudioSessionIfNeeded()
            }
        }
    }

    func reset() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        isStoppingIntentionally = false

        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }

        deactivateAudioSessionIfNeeded()

        transcript = ""
        finalTranscript = ""
        audioLevel = 0
        isRecording = false
    }

    private func refreshPermissions() async {
        guard recognizer != nil else {
            permissionStatus = .unavailable
            return
        }

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
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: [])
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
        let format = inputNode.inputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)
            // Compute RMS entirely on the audio thread — only dispatch the scalar to main
            let level = SpeechRecognizerService.computeAudioLevel(from: buffer)
            Task { @MainActor in
                self.audioLevel = level
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
                        self.cleanupRecognitionObjects()
                        self.deactivateAudioSessionIfNeeded()
                        self.stopRecording()
                        self.isStoppingIntentionally = false
                    }
                }

                if let error {
                    if self.shouldIgnoreRecognitionError(error) {
                        self.cleanupRecognitionObjects()
                        self.deactivateAudioSessionIfNeeded()
                        self.isStoppingIntentionally = false
                        return
                    }

                    let cleaned = self.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.isEmpty {
                        self.failAndStop(message: "Speech recognition failed.")
                    } else {
                        self.finalTranscript = cleaned
                        self.stopRecording()
                    }
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
        cleanupRecognitionObjects()
        watchdogTask?.cancel()
        watchdogTask = nil
        isRecording = false
        isStoppingIntentionally = false
        audioLevel = 0
        deactivateAudioSessionIfNeeded()
        permissionStatus = .error(message)
    }

    private func cleanupRecognitionObjects() {
        recognitionTask = nil
        recognitionRequest = nil
    }

    private func deactivateAudioSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func shouldIgnoreRecognitionError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Ignore expected cancellation/teardown errors when user intentionally stops.
        if isStoppingIntentionally {
            return true
        }

        // Assistant and speech framework transient cancellation codes commonly appear during teardown.
        if nsError.domain == "kAFAssistantErrorDomain" {
            return nsError.code == 1101 || nsError.code == 1107 || nsError.code == 1110
        }

        if nsError.domain == "SFSpeechErrorDomain" {
            return nsError.code == 203 || nsError.code == 216
        }

        return false
    }

    /// Pure function — safe to call from any thread. Returns a 0–1 normalised level.
    private static func computeAudioLevel(from buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }

        let average = sum / Float(frameLength)
        return min(max(CGFloat(average * 8), 0), 1)
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
