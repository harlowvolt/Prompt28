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
protocol SpeechRecognizerFactoryProtocol {
    func makeSpeechRecognizer(locale: Locale) -> any SpeechRecognizing
}

struct LiveSpeechRecognizerFactory: SpeechRecognizerFactoryProtocol {
    func makeSpeechRecognizer(locale: Locale) -> any SpeechRecognizing {
        SpeechRecognizerService(locale: locale)
    }
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

    /// Dedicated serial queue for all audio-buffer processing (RMS / future FFT).
    /// AVAudioEngine's tap callback fires on this queue; the computed float is
    /// dispatched to MainActor for the Orb — the main thread never touches raw buffers.
    private static let audioProcessingQueue = DispatchQueue(
        label: "app.promptme.audio.processing",
        qos: .userInteractive
    )

    private let audioEngine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var watchdogTask: Task<Void, Never>?
    private var silenceTask: Task<Void, Never>?
    private var hasDetectedSpeech = false
    private var isStoppingIntentionally = false

    /// Audio level threshold below which silence is declared (0–1 normalised RMS).
    private static let silenceThreshold: CGFloat = 0.04
    /// Continuous silence duration in seconds before auto-stopping.
    private static let silenceDuration: TimeInterval = 1.8

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
            hasDetectedSpeech = false

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

        silenceTask?.cancel()
        silenceTask = nil

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
        silenceTask?.cancel()
        silenceTask = nil
        hasDetectedSpeech = false
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

        // Capture the request reference before entering the background audio thread closure.
        // installTap fires on AVAudioEngine's internal audio thread; we hop to
        // audioProcessingQueue so all RMS / future FFT math runs on a single,
        // named queue. Only the normalised scalar reaches MainActor.
        let capturedRequest = recognitionRequest
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            capturedRequest?.append(buffer)
            SpeechRecognizerService.audioProcessingQueue.async {
                let level = SpeechRecognizerService.computeAudioLevel(from: buffer)
                Task { @MainActor [weak self] in
                    self?.handleAudioLevel(level)
                }
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
        silenceTask?.cancel()
        silenceTask = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        cleanupRecognitionObjects()
        watchdogTask?.cancel()
        watchdogTask = nil
        isRecording = false
        isStoppingIntentionally = false
        hasDetectedSpeech = false
        audioLevel = 0
        deactivateAudioSessionIfNeeded()
        permissionStatus = .error(message)
    }

    /// Called on the MainActor for every audio buffer. Drives audioLevel and silence detection.
    @MainActor
    private func handleAudioLevel(_ level: CGFloat) {
        audioLevel = level
        guard isRecording else {
            silenceTask?.cancel()
            silenceTask = nil
            return
        }

        if level > Self.silenceThreshold {
            // Active audio — mark speech detected and reset any pending silence stop.
            hasDetectedSpeech = true
            silenceTask?.cancel()
            silenceTask = nil
        } else if hasDetectedSpeech && silenceTask == nil {
            // Silence after speech — start the auto-stop countdown.
            silenceTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.silenceDuration))
                guard let self, !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self, self.isRecording else { return }
                    self.stopRecording()
                }
            }
        }
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

        return Self.isExpectedTeardownRecognitionError(nsError)
    }

    /// Pure classification helper for transient speech-framework teardown errors.
    nonisolated static func isExpectedTeardownRecognitionError(_ error: NSError) -> Bool {
        if error.domain == "kAFAssistantErrorDomain" {
            return error.code == 1101 || error.code == 1107 || error.code == 1110
        }

        if error.domain == "SFSpeechErrorDomain" {
            return error.code == 203 || error.code == 216
        }

        return false
    }

    /// Pure function — safe to call from any thread. Returns a 0–1 normalised level.
    nonisolated private static func computeAudioLevel(from buffer: AVAudioPCMBuffer) -> CGFloat {
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
