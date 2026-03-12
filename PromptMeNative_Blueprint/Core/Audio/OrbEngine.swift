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
    private var hasDetectedSpeechContent = false
    private let minimumListeningDuration: TimeInterval = 0.7
    private let minimumTranscriptCharacterCount = 3
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
        Self.needsPermissionSettingsAction(for: permissionStatus)
    }

    var permissionMessage: String {
        Self.permissionMessage(for: permissionStatus)
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
        guard Self.shouldBeginStopListening(
            isRecording: isRecording,
            canStopListeningNow: canStopListeningNow
        ) else { return false }

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
        let trimmed = Self.preferredTranscriptCandidate(finalTranscript: finalTranscript, transcript: transcript)
        guard isMeaningfulTranscript(trimmed) else {
            if Self.shouldResetToIdleAfterDiscardedTranscript(isRecording: isRecording) {
                state = .idle
            }
            return
        }
        guard Self.shouldDeliverTranscriptCandidate(
            trimmedTranscript: trimmed,
            lastDeliveredTranscript: lastDeliveredTranscript
        ) else { return }

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
        if !Self.shouldAcceptFallbackTranscriptCandidate(
            text: fallback,
            hasDetectedSpeechContent: hasDetectedSpeechContent,
            minimumTranscriptCharacterCount: minimumTranscriptCharacterCount
        ) {
            state = .idle
            return
        }

        finalTranscript = fallback
        transcript = fallback
        finalizeTranscript()
    }

    private var canStopListeningNow: Bool {
        Self.hasMetMinimumListeningDuration(
            listeningStartedAt: listeningStartedAt,
            now: Date(),
            minimumListeningDuration: minimumListeningDuration
        )
    }

    private func isMeaningfulTranscript(_ text: String) -> Bool {
        Self.isMeaningfulTranscriptCandidate(
            text: text,
            hasDetectedSpeechContent: hasDetectedSpeechContent,
            minimumTranscriptCharacterCount: minimumTranscriptCharacterCount
        )
    }

    private func bindSpeechState() {
        speech.isRecordingPublisher
            .sink { [weak self] value in
                guard let self else { return }
                self.isRecording = value
                if let nextState = Self.recordingTransitionState(isRecording: value) {
                    self.state = nextState
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
                if Self.shouldFinalizeOnFinalTranscriptUpdate(
                    trimmedFinalTranscript: trimmed,
                    state: self.state
                ) {
                    self.finalizeTranscript()
                }
            }
            .store(in: &cancellables)

        speech.permissionStatusPublisher
            .sink { [weak self] status in
                guard let self else { return }
                self.permissionStatus = status
                if let failureState = Self.failureState(for: status) {
                    self.state = failureState
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

    /// Pure mapping from permission status to user-facing failure text.
    nonisolated static func failureMessage(for status: SpeechRecognizerService.PermissionStatus) -> String? {
        switch status {
        case .granted, .notDetermined:
            return nil
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
        }
    }

    /// Pure mapping from permission status to OrbEngine failure state.
    nonisolated static func failureState(for status: SpeechRecognizerService.PermissionStatus) -> State? {
        guard let message = failureMessage(for: status) else { return nil }
        return .failure(message)
    }

    /// Pure mapping from recording-flag updates to state transitions.
    nonisolated static func recordingTransitionState(isRecording: Bool) -> State? {
        isRecording ? .listening : nil
    }

    /// Pure helper for transcript selection so behavior can be unit-tested
    /// independently of actor state and side effects.
    nonisolated static func preferredTranscriptCandidate(
        finalTranscript: String,
        transcript: String
    ) -> String {
        let trimmedFinal = finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFinal.isEmpty {
            return trimmedFinal
        }
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Pure helper for transcript-delivery dedupe.
    nonisolated static func shouldDeliverTranscriptCandidate(
        trimmedTranscript: String,
        lastDeliveredTranscript: String
    ) -> Bool {
        trimmedTranscript != lastDeliveredTranscript
    }

    /// Pure helper for deciding whether a discarded transcript should reset state to idle.
    nonisolated static func shouldResetToIdleAfterDiscardedTranscript(isRecording: Bool) -> Bool {
        !isRecording
    }

    /// Pure helper for fallback transcript acceptance during finalize polling.
    nonisolated static func shouldAcceptFallbackTranscriptCandidate(
        text: String,
        hasDetectedSpeechContent: Bool,
        minimumTranscriptCharacterCount: Int = 3
    ) -> Bool {
        isMeaningfulTranscriptCandidate(
            text: text,
            hasDetectedSpeechContent: hasDetectedSpeechContent,
            minimumTranscriptCharacterCount: minimumTranscriptCharacterCount
        )
    }

    /// Pure helper for stop-listening eligibility.
    nonisolated static func shouldBeginStopListening(
        isRecording: Bool,
        canStopListeningNow: Bool
    ) -> Bool {
        isRecording && canStopListeningNow
    }

    /// Pure helper for transcript meaningfulness checks.
    nonisolated static func isMeaningfulTranscriptCandidate(
        text: String,
        hasDetectedSpeechContent: Bool,
        minimumTranscriptCharacterCount: Int = 3
    ) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumTranscriptCharacterCount else { return false }
        guard hasDetectedSpeechContent || !trimmed.isEmpty else { return false }
        return trimmed.rangeOfCharacter(from: .alphanumerics) != nil
    }

    /// Pure mapping from permission status to user-facing permission helper text.
    nonisolated static func permissionMessage(for status: SpeechRecognizerService.PermissionStatus) -> String {
        switch status {
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

    /// Pure mapping for whether opening Settings is a meaningful recovery action.
    nonisolated static func needsPermissionSettingsAction(
        for status: SpeechRecognizerService.PermissionStatus
    ) -> Bool {
        switch status {
        case .speechDenied, .microphoneDenied, .restricted:
            return true
        case .notDetermined, .granted, .unavailable, .error:
            return false
        }
    }

    /// Pure helper for minimum listen-duration gating before stop is allowed.
    nonisolated static func hasMetMinimumListeningDuration(
        listeningStartedAt: Date?,
        now: Date,
        minimumListeningDuration: TimeInterval
    ) -> Bool {
        guard let listeningStartedAt else { return false }
        return now.timeIntervalSince(listeningStartedAt) >= minimumListeningDuration
    }

    /// Pure gate for whether a final-transcript publisher update should trigger finalize.
    nonisolated static func shouldFinalizeOnFinalTranscriptUpdate(
        trimmedFinalTranscript: String,
        state: State
    ) -> Bool {
        guard !trimmedFinalTranscript.isEmpty else { return false }
        return state == .transcribing || state == .listening
    }
}

// MARK: - Conformance
extension OrbEngine: OrbEngineProtocol {}
