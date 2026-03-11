import Foundation
import Combine
import CoreGraphics

@MainActor
final class OrbEngine: ObservableObject {
    enum State: Equatable {
        case idle
        case listening
        case transcribing
        case ready(text: String)
        case generating
        case success
        case failure(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var isRecording = false
    @Published private(set) var transcript = ""
    @Published private(set) var finalTranscript = ""
    @Published private(set) var permissionStatus: SpeechRecognizerService.PermissionStatus = .notDetermined
    @Published private(set) var audioLevel: CGFloat = 0

    private let speech: SpeechRecognizing
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
        state = .listening
        speech.startRecording()
    }

    func stopListeningAndFinalize() async -> String? {
        guard isRecording else { return nil }

        state = .transcribing
        speech.stopRecording()

        for _ in 0..<30 {
            let best = speech.finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !best.isEmpty {
                finalTranscript = best
                transcript = best
                state = .ready(text: best)
                return best
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        let fallback = speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.isEmpty {
            state = .failure("No speech detected.")
            return nil
        }

        finalTranscript = fallback
        transcript = fallback
        state = .ready(text: fallback)
        return fallback
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
            }
            .store(in: &cancellables)

        speech.finalTranscriptPublisher
            .sink { [weak self] value in
                guard let self else { return }
                self.finalTranscript = value
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, self.state == .transcribing || self.state == .listening {
                    self.state = .ready(text: trimmed)
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
