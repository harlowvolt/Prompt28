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
        guard isRecording && canStopListeningNow else { return false }

        state = .transcribing
        speech.stopRecording()

        Task { [weak self] in
            await self?.awaitFinalTranscriptAndFinalize()
        }
        return true
    }

    func stopListeningAndFinalize() async -> String? {
        guard stopListening() else { return nil }
        for _ in Self.finalTranscriptPollingAttemptRange() {
            let best = Self.normalizedTranscript(finalTranscript)
            if Self.hasNormalizedTranscriptContent(best) {
                return best
            }
            try? await Task.sleep(nanoseconds: Self.finalTranscriptPollingSleepNanoseconds())
        }
        return nil
    }

    func finalizeTranscript() {
        let trimmedFinal = finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = trimmedFinal.isEmpty
            ? transcript.trimmingCharacters(in: .whitespacesAndNewlines)
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
        for _ in Self.finalTranscriptPollingAttemptRange() {
            let best = Self.normalizedTranscript(speech.finalTranscript)
            if Self.hasNormalizedTranscriptContent(best) {
                let assignment = Self.transcriptAssignment(for: best)
                finalTranscript = assignment.finalTranscript
                transcript = assignment.transcript
                finalizeTranscript()
                return
            }
            try? await Task.sleep(nanoseconds: Self.finalTranscriptPollingSleepNanoseconds())
        }

        guard let fallback = Self.fallbackTranscriptCandidateAfterPolling(
            transcript: speech.transcript,
            hasDetectedSpeechContent: hasDetectedSpeechContent,
            minimumTranscriptCharacterCount: minimumTranscriptCharacterCount
        ) else {
            state = .idle
            return
        }

        let fallbackAssignment = Self.transcriptAssignment(for: fallback)
        finalTranscript = fallbackAssignment.finalTranscript
        transcript = fallbackAssignment.transcript
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
                self.state = value ? .listening : self.state
            }
            .store(in: &cancellables)

        speech.transcriptPublisher
            .sink { [weak self] value in
                guard let self else { return }
                self.transcript = value
                let trimmed = Self.normalizedTranscript(value)
                self.hasDetectedSpeechContent = self.hasDetectedSpeechContent || Self.hasNormalizedTranscriptContent(trimmed)
            }
            .store(in: &cancellables)

        speech.finalTranscriptPublisher
            .sink { [weak self] value in
                guard let self else { return }
                self.finalTranscript = value
                let trimmed = Self.normalizedTranscript(value)
                if Self.hasNormalizedTranscriptContent(trimmed)
                    && (self.state == .transcribing || self.state == .listening) {
                    self.finalizeTranscript()
                }
            }
            .store(in: &cancellables)

        speech.permissionStatusPublisher
            .sink { [weak self] status in
                guard let self else { return }
                self.permissionStatus = status
                if let message = Self.failureMessage(for: status) {
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

    /// Pure mapping from permission status to user-facing failure text.
    nonisolated static func failureMessage(for status: SpeechRecognizerService.PermissionStatus) -> String? {
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

    /// Pure helper for final transcript polling iteration bounds.
    nonisolated static func finalTranscriptPollingIterationLimit() -> Int {
        30
    }

    /// Pure helper for final transcript polling attempt range.
    nonisolated static func finalTranscriptPollingAttemptRange() -> Range<Int> {
        0..<finalTranscriptPollingIterationLimit()
    }

    /// Pure helper for final transcript polling sleep duration.
    nonisolated static func finalTranscriptPollingSleepNanoseconds() -> UInt64 {
        50_000_000
    }

    /// Pure helper for transcript whitespace normalization.
    nonisolated static func normalizedTranscript(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Pure helper for checking content after transcript normalization.
    nonisolated static func hasNormalizedTranscriptContent(_ normalizedText: String) -> Bool {
        !normalizedText.isEmpty
    }

    /// Pure helper for assigning finalized transcript values to engine fields.
    nonisolated static func transcriptAssignment(
        for text: String
    ) -> (finalTranscript: String, transcript: String) {
        (finalTranscript: text, transcript: text)
    }

    /// Pure helper for selecting fallback transcript after final-transcript polling.
    nonisolated static func fallbackTranscriptCandidateAfterPolling(
        transcript: String,
        hasDetectedSpeechContent: Bool,
        minimumTranscriptCharacterCount: Int = 3
    ) -> String? {
        let trimmed = normalizedTranscript(transcript)
        guard isMeaningfulTranscriptCandidate(
            text: trimmed,
            hasDetectedSpeechContent: hasDetectedSpeechContent,
            minimumTranscriptCharacterCount: minimumTranscriptCharacterCount
        ) else {
            return nil
        }
        return trimmed
    }

    /// Pure helper for transcript meaningfulness checks.
    nonisolated static func isMeaningfulTranscriptCandidate(
        text: String,
        hasDetectedSpeechContent: Bool,
        minimumTranscriptCharacterCount: Int = 3
    ) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard meetsMinimumTranscriptLength(
            trimmedText: trimmed,
            minimumTranscriptCharacterCount: minimumTranscriptCharacterCount
        ) else { return false }
        guard hasDetectedSpeechContent || !trimmed.isEmpty else { return false }
        return containsAlphanumericContent(trimmed)
    }

    /// Pure helper for transcript minimum-length validation.
    nonisolated static func meetsMinimumTranscriptLength(
        trimmedText: String,
        minimumTranscriptCharacterCount: Int
    ) -> Bool {
        trimmedText.count >= minimumTranscriptCharacterCount
    }

    /// Pure helper for alphanumeric content checks in transcript text.
    nonisolated static func containsAlphanumericContent(_ text: String) -> Bool {
        text.rangeOfCharacter(from: .alphanumerics) != nil
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

}

// MARK: - Conformance
extension OrbEngine: OrbEngineProtocol {}
