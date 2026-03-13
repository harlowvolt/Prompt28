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
        setState(.idle)
    }

    func startListening() {
        prepareForListeningStart()
        speech.startRecording()
    }

    @discardableResult
    func stopListening() -> Bool {
        guard isRecording, hasMetMinimumListeningDuration else { return false }

        beginTranscribingAndFinalize()
        return true
    }

    func stopListeningAndFinalize() async -> String? {
        guard stopListening() else { return nil }
        return await pollForFinalTranscript(currentFinalTranscriptSnapshot)
    }

    func finalizeTranscript() {
        let trimmed = preferredFinalizedTranscriptText()
        guard isMeaningfulTranscript(trimmed) else {
            if !isRecording { setState(.idle) }
            return
        }
        guard trimmed != lastDeliveredTranscript else { return }

        deliverFinalizedTranscript(trimmed)
    }

    func markGenerating() {
        setState(.generating)
    }

    func markSuccess() {
        setState(.success)
    }

    func markFailure(_ message: String) {
        setFailureState(message)
    }

    func markIdle() {
        setState(.idle)
    }

    private func awaitFinalTranscriptAndFinalize() async {
        if let best = await pollForFinalTranscript(speechFinalTranscriptSnapshot) {
            finalizeUsingTranscriptCandidate(best)
            return
        }

        finalizeWithFallbackTranscriptIfMeaningful()
    }

    private func pollForFinalTranscript(_ provider: () -> String) async -> String? {
        for _ in 0..<finalTranscriptPollingAttempts {
            let candidate = trimmedTranscriptText(provider())
            if !candidate.isEmpty {
                return candidate
            }
            try? await Task.sleep(nanoseconds: finalTranscriptPollingSleepNanoseconds)
        }
        return nil
    }

    private func prepareForListeningStart() {
        (transcript, finalTranscript, lastDeliveredTranscript) = ("", "", "")
        listeningStartedAt = Date()
        setState(.listening)
    }

    private var hasMetMinimumListeningDuration: Bool {
        guard let listeningStartedAt else { return false }
        return Date().timeIntervalSince(listeningStartedAt) >= minimumListeningDuration
    }

    private func beginTranscribingAndFinalize() {
        setState(.transcribing)
        speech.stopRecording()
        startFinalizationAwaitTask()
    }

    private func startFinalizationAwaitTask() {
        Task { [weak self] in
            await self?.awaitFinalTranscriptAndFinalize()
        }
    }

    private func currentFinalTranscriptSnapshot() -> String {
        trimmedCurrentFinalTranscript()
    }

    private func speechFinalTranscriptSnapshot() -> String {
        trimmedSpeechFinalTranscript()
    }

    private func finalizeUsingTranscriptCandidate(_ text: String) {
        updateCurrentTranscripts(with: text)
        finalizeTranscript()
    }

    private func finalizeWithFallbackTranscriptIfMeaningful() {
        let fallbackCandidate = trimmedSpeechTranscript()
        guard isMeaningfulTranscript(fallbackCandidate) else {
            setState(.idle)
            return
        }

        finalizeUsingTranscriptCandidate(fallbackCandidate)
    }

    private func updateCurrentTranscripts(with text: String) {
        (finalTranscript, transcript) = (text, text)
    }

    private func preferredFinalizedTranscriptText() -> String {
        let trimmedFinal = trimmedTranscriptText(finalTranscript)
        return trimmedFinal.isEmpty ? trimmedTranscriptText(transcript) : trimmedFinal
    }

    private func deliverFinalizedTranscript(_ text: String) {
        lastDeliveredTranscript = text
        setState(.ready(text: text))
        onFinalTranscript?(text)
    }

    private func trimmedCurrentFinalTranscript() -> String {
        trimmedTranscriptText(finalTranscript)
    }

    private func trimmedSpeechFinalTranscript() -> String {
        trimmedTranscriptText(speech.finalTranscript)
    }

    private func trimmedSpeechTranscript() -> String {
        trimmedTranscriptText(speech.transcript)
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

    private func setFailureState(_ message: String) {
        setState(.failure(message))
    }

    private func setState(_ newState: State) {
        state = newState
    }

    private var shouldFinalizeOnTranscriptUpdate: Bool {
        state == .transcribing || state == .listening
    }

    private func handleRecordingChange(_ value: Bool) {
        isRecording = value
        if value { setState(.listening) }
    }

    private func handleTranscriptChange(_ value: String) {
        transcript = value
    }

    private func handleFinalTranscriptChange(_ value: String) {
        finalTranscript = value
        let trimmed = trimmedTranscriptText(value)
        if !trimmed.isEmpty && shouldFinalizeOnTranscriptUpdate {
            finalizeTranscript()
        }
    }

    private func handlePermissionStatusChange(_ status: SpeechRecognizerService.PermissionStatus) {
        permissionStatus = status
        if let message = permissionFailureMessage(for: status) {
            setFailureState(message)
        }
    }

    private func handleAudioLevelChange(_ value: CGFloat) {
        audioLevel = value
    }

    private func bindSpeechState() {
        bindRecordingPublisher()
        bindTranscriptPublisher()
        bindFinalTranscriptPublisher()
        bindPermissionStatusPublisher()
        bindAudioLevelPublisher()
    }

    private func bindRecordingPublisher() {
        speech.isRecordingPublisher
            .sink { [weak self] value in
                guard let self else { return }
                self.handleRecordingChange(value)
            }
            .store(in: &cancellables)
    }

    private func bindTranscriptPublisher() {
        speech.transcriptPublisher
            .sink { [weak self] value in
                guard let self else { return }
                self.handleTranscriptChange(value)
            }
            .store(in: &cancellables)
    }

    private func bindFinalTranscriptPublisher() {
        speech.finalTranscriptPublisher
            .sink { [weak self] value in
                guard let self else { return }
                self.handleFinalTranscriptChange(value)
            }
            .store(in: &cancellables)
    }

    private func bindPermissionStatusPublisher() {
        speech.permissionStatusPublisher
            .sink { [weak self] status in
                guard let self else { return }
                self.handlePermissionStatusChange(status)
            }
            .store(in: &cancellables)
    }

    private func bindAudioLevelPublisher() {
        speech.audioLevelPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.handleAudioLevelChange(value)
            }
            .store(in: &cancellables)
    }

}

// MARK: - Conformance
extension OrbEngine: OrbEngineProtocol {}
