import Combine
import CoreGraphics
import Foundation

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
    private var hasDetectedSpeechContent = false
    private let minimumListeningDuration: TimeInterval = 0.7
    private let minimumTranscriptCharacterCount = 3
    // Combine is kept internally to bridge SpeechRecognizing's thread-safe publishers.
    private var cancellables: Set<AnyCancellable> = []

    init(speech: SpeechRecognizing) {
        self.speech = speech
        bindSpeechState()
    }

    static func makeDefault() -> OrbEngine {
        OrbEngine(speech: SpeechRecognizerService(locale: .current))
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
        hasDetectedSpeechContent = false
        listeningStartedAt = Date()
        state = .listening
        speech.startRecording()
    }

    @discardableResult
    func stopListening() -> Bool {
        guard isRecording else { return false }
        guard canStopListeningNow else { return false }

        state = .transcribing
        speech.stopRecording()

        Task { [weak self] in
            await self?.awaitFinalTranscriptAndFinalize()
        }
        return true
    }

    func stopListeningAndFinalize() async -> String? {
        guard stopListening() else { return nil }
        for _ in 0..<30 {
            let best = finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !best.isEmpty {
                return best
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return nil
    }

    func finalizeTranscript() {
        let current = finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? transcript
            : finalTranscript
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isMeaningfulTranscript(trimmed) else {
            if !isRecording {
                state = .idle
            }
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
        for _ in 0..<30 {
            let best = speech.finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !best.isEmpty {
                finalTranscript = best
                transcript = best
                finalizeTranscript()
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        let fallback = speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isMeaningfulTranscript(fallback) {
            state = .idle
            return
        }

        finalTranscript = fallback
        transcript = fallback
        finalizeTranscript()
    }

    private var canStopListeningNow: Bool {
        guard let listeningStartedAt else { return false }
        return Date().timeIntervalSince(listeningStartedAt) >= minimumListeningDuration
    }

    private func isMeaningfulTranscript(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumTranscriptCharacterCount else { return false }
        guard hasDetectedSpeechContent || !trimmed.isEmpty else { return false }
        return trimmed.rangeOfCharacter(from: .alphanumerics) != nil
    }

    private func bindSpeechState() {
        speech.isRecordingPublisher
            .sink { [weak self] value in
                guard let self else { return }
                self.isRecording = value
                if value {
                    self.state = .listening
                }
            }
            .store(in: &cancellables)

        speech.transcriptPublisher
            .sink { [weak self] value in
                guard let self else { return }
                self.transcript = value
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    self.hasDetectedSpeechContent = true
                }
            }
            .store(in: &cancellables)

        speech.finalTranscriptPublisher
            .sink { [weak self] value in
                guard let self else { return }
                self.finalTranscript = value
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, self.state == .transcribing || self.state == .listening {
                    self.finalizeTranscript()
                }
            }
            .store(in: &cancellables)

        speech.permissionStatusPublisher
            .sink { [weak self] status in
                guard let self else { return }
                self.permissionStatus = status
                switch status {
                case .granted, .notDetermined:
                    break
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
