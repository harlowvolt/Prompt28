import Combine
import CoreGraphics
import Foundation

/// Protocol describing the observable surface and transition commands consumed
/// by views. `@MainActor` matches OrbEngine's isolation.
@MainActor
protocol OrbEngineProtocol: AnyObject {

    // MARK: Observable State
    var state: OrbEngine.State { get }
    var isRecording: Bool { get }
    var transcript: String { get }
    var finalTranscript: String { get }
    var permissionStatus: SpeechRecognizerService.PermissionStatus { get }
    var audioLevel: CGFloat { get }
    var onFinalTranscript: ((String) -> Void)? { get set }

    // MARK: Derived State
    var needsPermissionSettingsAction: Bool { get }
    var permissionMessage: String { get }

    // MARK: Commands
    func reset()
    func startListening()
    @discardableResult func stopListening() -> Bool
    func stopListeningAndFinalize() async -> String?
    func markGenerating()
    func markSuccess()
    func markFailure(_ message: String)
    func markIdle()
}

@MainActor
protocol OrbEngineFactoryProtocol {
    func makeOrbEngine() -> OrbEngine
}

struct LiveOrbEngineFactory: OrbEngineFactoryProtocol {
    var speechFactory: any SpeechRecognizerFactoryProtocol

    func makeOrbEngine() -> OrbEngine {
        OrbEngine.makeDefault(speechFactory: speechFactory)
    }
}

@Observable
@MainActor
final class OrbEngine {
    enum State: Equatable {
        case idle
        case listening
        case transcribing
        case ready(text: String)
        case generating
        case success
        case failure(String)
    }

    private(set) var state: State = .idle
    private(set) var isRecording = false
    private(set) var transcript = ""
    private(set) var finalTranscript = ""
    private(set) var permissionStatus: SpeechRecognizerService.PermissionStatus = .notDetermined
    private(set) var audioLevel: CGFloat = 0
    var onFinalTranscript: ((String) -> Void)?

    private let speech: SpeechRecognizing
    private var lastDeliveredTranscript = ""
    private var listeningStartedAt: Date?
    private let minimumListeningDuration: TimeInterval = 0.7
    private let minimumMeaningfulTranscriptLength = 3
    private let finalTranscriptPollingAttempts = 30
    private let finalTranscriptPollingSleepNanoseconds: UInt64 = 50_000_000
    private let transcriptTrimCharacterSet = CharacterSet.whitespacesAndNewlines
    // Combine is kept internally to bridge SpeechRecognizing's thread-safe publishers.
    private var cancellables: Set<AnyCancellable> = []

    init(speech: SpeechRecognizing) {
        self.speech = speech
        bindSpeechState()
    }

    static func makeDefault(
        speechFactory: any SpeechRecognizerFactoryProtocol,
        locale: Locale = .current
    ) -> OrbEngine {
        OrbEngine(speech: speechFactory.makeSpeechRecognizer(locale: locale))
    }

    var needsPermissionSettingsAction: Bool {
        switch permissionStatus {
        case .speechDenied, .microphoneDenied, .restricted:
            return true
        case .notDetermined, .granted, .unavailable, .error:
            return false
        }
    }

    var permissionMessage: String {
        switch permissionStatus {
        case .notDetermined, .granted:
            return ""
        case .speechDenied:
            return "Speech recognition access is required to transcribe your voice."
        case .microphoneDenied:
            return "Microphone access is required to capture your voice."
        case .restricted:
            return "Speech recognition is restricted on this device."
        case .unavailable:
            return "Speech recognizer is temporarily unavailable."
        case .error(let message):
            return message
        }
    }

    func reset() {
        speech.reset()
        state = .idle
    }

    func startListening() {
        (transcript, finalTranscript, lastDeliveredTranscript) = ("", "", "")
        listeningStartedAt = Date()
        state = .listening
        speech.startRecording()
    }

    @discardableResult
    func stopListening() -> Bool {
          let listeningDuration = listeningStartedAt.map { Date().timeIntervalSince($0) }
        guard isRecording,
              let listeningDuration,
              listeningDuration >= minimumListeningDuration else { return false }

        state = .transcribing
        speech.stopRecording()

        Task { [weak self] in
            await self?.awaitFinalTranscriptAndFinalize()
        }
        return true
    }

    func stopListeningAndFinalize() async -> String? {
        guard stopListening() else { return nil }
        for _ in 0..<finalTranscriptPollingAttempts {
            let best = trimmedTranscriptText(finalTranscript)
            if !best.isEmpty {
                return best
            }
            try? await Task.sleep(nanoseconds: finalTranscriptPollingSleepNanoseconds)
        }
        return nil
    }

    func finalizeTranscript() {
        let trimmedFinal = trimmedTranscriptText(finalTranscript)
        let trimmed = trimmedFinal.isEmpty
            ? trimmedTranscriptText(transcript)
            : trimmedFinal
        guard isMeaningfulTranscript(trimmed) else {
            state = isRecording ? state : .idle
            return
        }
        guard trimmed != lastDeliveredTranscript else { return }

        lastDeliveredTranscript = trimmed
        state = .ready(text: trimmed)
        onFinalTranscript?(trimmed)
    }

    func markGenerating() {
        state = .generating
    }

    func markSuccess() {
        state = .success
    }

    func markFailure(_ message: String) {
        state = .failure(message)
    }

    func markIdle() {
        state = .idle
    }

    private func awaitFinalTranscriptAndFinalize() async {
        for _ in 0..<finalTranscriptPollingAttempts {
            let best = trimmedTranscriptText(speech.finalTranscript)
            if !best.isEmpty {
                (finalTranscript, transcript) = (best, best)
                finalizeTranscript()
                return
            }
            try? await Task.sleep(nanoseconds: finalTranscriptPollingSleepNanoseconds)
        }

        let fallbackCandidate = trimmedTranscriptText(speech.transcript)
        guard isMeaningfulTranscript(fallbackCandidate) else {
            state = .idle
            return
        }

        (finalTranscript, transcript) = (fallbackCandidate, fallbackCandidate)
        finalizeTranscript()
    }

    private func trimmedTranscriptText(_ text: String) -> String {
        text.trimmingCharacters(in: transcriptTrimCharacterSet)
    }

    private func isMeaningfulTranscript(_ text: String) -> Bool {
        let trimmed = trimmedTranscriptText(text)
        guard trimmed.count >= minimumMeaningfulTranscriptLength else { return false }
        return trimmed.rangeOfCharacter(from: .alphanumerics) != nil
    }

    private func permissionFailureMessage(
        for status: SpeechRecognizerService.PermissionStatus
    ) -> String? {
        switch status {
        case .speechDenied:
            return "Speech recognition permission denied."
        case .microphoneDenied:
            return "Microphone permission denied."
        case .restricted:
            return "Speech recognition is restricted on this device."
        case .unavailable:
            return "Speech recognition is unavailable."
        case .error(let message):
            return message
        case .granted, .notDetermined:
            return nil
        }
    }

    private var shouldFinalizeOnTranscriptUpdate: Bool {
        state == .transcribing || state == .listening
    }

    private func bindSpeechState() {
        speech.isRecordingPublisher
            .sink { [weak self] value in
                guard let self else { return }
                self.isRecording = value
                self.state = value ? .listening : self.state
            }
            .store(in: &cancellables)

        speech.transcriptPublisher
            .sink { [weak self] value in
                guard let self else { return }
                self.transcript = value
            }
            .store(in: &cancellables)

        speech.finalTranscriptPublisher
            .sink { [weak self] value in
                guard let self else { return }
                self.finalTranscript = value
                let trimmed = self.trimmedTranscriptText(value)
                if !trimmed.isEmpty && self.shouldFinalizeOnTranscriptUpdate {
                    self.finalizeTranscript()
                }
            }
            .store(in: &cancellables)

        speech.permissionStatusPublisher
            .sink { [weak self] status in
                guard let self else { return }
                self.permissionStatus = status
                if let message = self.permissionFailureMessage(for: status) {
                    self.state = .failure(message)
                }
            }
            .store(in: &cancellables)

        speech.audioLevelPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.audioLevel = value
            }
            .store(in: &cancellables)
    }

}

// MARK: - Conformance
extension OrbEngine: OrbEngineProtocol {}
