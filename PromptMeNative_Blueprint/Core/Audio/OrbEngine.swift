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
        transcript = ""
        finalTranscript = ""
        lastDeliveredTranscript = ""
        listeningStartedAt = Date()
        state = .listening
        speech.startRecording()
    }

    @discardableResult
    func stopListening() -> Bool {
        guard isRecording,
              let listeningStartedAt,
              Date().timeIntervalSince(listeningStartedAt) >= minimumListeningDuration else { return false }

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
            let best = finalTranscript.trimmingCharacters(in: transcriptTrimCharacterSet)
            if !best.isEmpty {
                return best
            }
            try? await Task.sleep(nanoseconds: finalTranscriptPollingSleepNanoseconds)
        }
        return nil
    }

    func finalizeTranscript() {
        let trimmedFinal = finalTranscript.trimmingCharacters(in: transcriptTrimCharacterSet)
        let trimmed = trimmedFinal.isEmpty
            ? transcript.trimmingCharacters(in: transcriptTrimCharacterSet)
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
            let best = speech.finalTranscript.trimmingCharacters(in: transcriptTrimCharacterSet)
            if !best.isEmpty {
                (finalTranscript, transcript) = (best, best)
                finalizeTranscript()
                return
            }
            try? await Task.sleep(nanoseconds: finalTranscriptPollingSleepNanoseconds)
        }

        let fallbackCandidate = speech.transcript.trimmingCharacters(in: transcriptTrimCharacterSet)
        guard isMeaningfulTranscript(fallbackCandidate) else {
            state = .idle
            return
        }

        (finalTranscript, transcript) = (fallbackCandidate, fallbackCandidate)
        finalizeTranscript()
    }

    private func isMeaningfulTranscript(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: transcriptTrimCharacterSet)
        guard trimmed.count >= 3 else { return false }
        return trimmed.rangeOfCharacter(from: .alphanumerics) != nil
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
                let trimmed = value.trimmingCharacters(in: transcriptTrimCharacterSet)
                if !trimmed.isEmpty
                    && (self.state == .transcribing || self.state == .listening) {
                    self.finalizeTranscript()
                }
            }
            .store(in: &cancellables)

        speech.permissionStatusPublisher
            .sink { [weak self] status in
                guard let self else { return }
                self.permissionStatus = status
                switch status {
                case .speechDenied:
                    self.state = .failure("Speech recognition permission denied.")
                case .microphoneDenied:
                    self.state = .failure("Microphone permission denied.")
                case .restricted:
                    self.state = .failure("Speech recognition is restricted on this device.")
                case .unavailable:
                    self.state = .failure("Speech recognition is unavailable.")
                case .error(let message):
                    self.state = .failure(message)
                case .granted, .notDetermined:
                    break
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
