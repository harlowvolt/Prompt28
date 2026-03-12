import Testing
import Foundation
@testable import Prompt28

// MARK: - UsageTracker Tests

/// Tests for the Keychain-backed freemium usage counter.
/// Each test calls tracker.reset() before asserting to isolate state.
@Suite("UsageTracker")
struct UsageTrackerTests {

    private func makeTracker() -> UsageTracker {
        let tracker = UsageTracker(keychain: KeychainService())
        tracker.reset()
        return tracker
    }

    @Test("Starter plan: first 10 generations are allowed")
    func starterAllowsTenGenerations() {
        let tracker = makeTracker()
        for _ in 0..<UsageTracker.freeMonthlyLimit {
            #expect(tracker.canGenerate(for: .starter))
            tracker.recordGeneration()
        }
    }

    @Test("Starter plan: generation is blocked after limit")
    func starterBlocksAfterLimit() {
        let tracker = makeTracker()
        for _ in 0..<UsageTracker.freeMonthlyLimit { tracker.recordGeneration() }
        #expect(!tracker.canGenerate(for: .starter))
    }

    @Test("Pro, Unlimited, and Dev plans always allow generation")
    func paidPlansAlwaysGenerate() {
        let tracker = makeTracker()
        // Exhaust the free limit to confirm paid plans ignore it
        for _ in 0..<(UsageTracker.freeMonthlyLimit + 5) { tracker.recordGeneration() }
        #expect(tracker.canGenerate(for: .pro))
        #expect(tracker.canGenerate(for: .unlimited))
        #expect(tracker.canGenerate(for: .dev))
    }

    @Test("sync advances local count when server reports more usage")
    func syncAdvancesWhenServerIsAhead() {
        let tracker = makeTracker()
        for _ in 0..<3 { tracker.recordGeneration() }
        #expect(tracker.count == 3)

        // Server reports 2 remaining out of 10 → 8 used on server side, ahead of local 3
        tracker.sync(promptsRemaining: 2, plan: .starter)
        #expect(tracker.count == 8)
    }

    @Test("sync does not rewind when local count exceeds server usage")
    func syncDoesNotRewind() {
        let tracker = makeTracker()
        for _ in 0..<7 { tracker.recordGeneration() }
        #expect(tracker.count == 7)

        // Server reports 6 remaining → 4 used on server, behind local 7
        tracker.sync(promptsRemaining: 6, plan: .starter)
        #expect(tracker.count == 7, "Local count must not rewind to match lagging server state")
    }

    @Test("sync is a no-op for non-starter plans")
    func syncIgnoresNonStarterPlans() {
        let tracker = makeTracker()
        for _ in 0..<3 { tracker.recordGeneration() }

        tracker.sync(promptsRemaining: 1, plan: .pro)
        tracker.sync(promptsRemaining: 1, plan: .unlimited)
        tracker.sync(promptsRemaining: 1, plan: .dev)
        #expect(tracker.count == 3)
    }

    @Test("reset clears count and re-enables starter generation")
    func resetClearsStateAndReenables() {
        let tracker = makeTracker()
        for _ in 0..<UsageTracker.freeMonthlyLimit { tracker.recordGeneration() }
        #expect(!tracker.canGenerate(for: .starter))

        tracker.reset()
        #expect(tracker.count == 0)
        #expect(tracker.canGenerate(for: .starter))
    }

    @Test("count matches number of recordGeneration calls")
    func countReflectsRecordedGenerations() {
        let tracker = makeTracker()
        let expected = 4
        for _ in 0..<expected { tracker.recordGeneration() }
        #expect(tracker.count == expected)
    }
}

// MARK: - AppPreferences Tests

@Suite("AppPreferences")
struct AppPreferencesTests {

    @Test("Default preferences have expected values")
    func defaultValues() {
        let prefs = AppPreferences.default
        #expect(prefs.saveHistory == true)
        #expect(prefs.aiModeDefault == true)
        #expect(prefs.selectedMode == .ai)
    }

    @Test("AppPreferences round-trips through JSON encoding")
    func codableRoundtrip() throws {
        let original = AppPreferences(saveHistory: false, aiModeDefault: false, selectedMode: .human)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)
        #expect(decoded.saveHistory == false)
        #expect(decoded.aiModeDefault == false)
        #expect(decoded.selectedMode == .human)
    }

    @Test("Two equal AppPreferences instances satisfy Equatable")
    func equality() {
        let a = AppPreferences.default
        let b = AppPreferences.default
        #expect(a == b)
    }

    @Test("Changing selectedMode produces non-equal AppPreferences")
    func inequalityOnModeChange() {
        var modified = AppPreferences.default
        modified.selectedMode = .human
        #expect(modified != AppPreferences.default)
    }
}

// MARK: - PromptMode Tests

@Suite("PromptMode")
struct PromptModeTests {

    @Test("Raw values match expected strings")
    func rawValues() {
        #expect(PromptMode.ai.rawValue == "ai")
        #expect(PromptMode.human.rawValue == "human")
    }

    @Test("PromptMode decodes from JSON string")
    func decodesFromJSON() throws {
        let aiJSON = #""ai""#.data(using: .utf8)!
        let humanJSON = #""human""#.data(using: .utf8)!
        #expect(try JSONDecoder().decode(PromptMode.self, from: aiJSON) == .ai)
        #expect(try JSONDecoder().decode(PromptMode.self, from: humanJSON) == .human)
    }

    @Test("PromptMode encodes to expected JSON string")
    func encodesToJSON() throws {
        let data = try JSONEncoder().encode(PromptMode.human)
        let string = String(data: data, encoding: .utf8)
        #expect(string == #""human""#)
    }

    @Test("All cases are covered by CaseIterable")
    func allCasesCount() {
        #expect(PromptMode.allCases.count == 2)
    }
}

// MARK: - PlanType Tests

@Suite("PlanType")
struct PlanTypeTests {

    @Test("Starter is the restrictive free plan")
    func starterRawValue() {
        #expect(PlanType.starter.rawValue == "starter")
    }

    @Test("All paid plan raw values decode correctly")
    func paidPlanDecoding() throws {
        let plans: [(String, PlanType)] = [
            ("pro", .pro), ("unlimited", .unlimited), ("dev", .dev)
        ]
        for (raw, expected) in plans {
            let data = "\"\(raw)\"".data(using: .utf8)!
            let decoded = try JSONDecoder().decode(PlanType.self, from: data)
            #expect(decoded == expected)
        }
    }
}

// MARK: - Audio Helper Mapping Tests

@Suite("Speech Error Classification")
struct SpeechErrorClassificationTests {

    @Test("Expected teardown assistant errors are classified")
    func assistantTeardownErrors() {
        #expect(SpeechRecognizerService.isExpectedTeardownRecognitionError(
            NSError(domain: "kAFAssistantErrorDomain", code: 1101)
        ))
        #expect(SpeechRecognizerService.isExpectedTeardownRecognitionError(
            NSError(domain: "kAFAssistantErrorDomain", code: 1107)
        ))
        #expect(SpeechRecognizerService.isExpectedTeardownRecognitionError(
            NSError(domain: "kAFAssistantErrorDomain", code: 1110)
        ))
    }

    @Test("Expected teardown speech-framework errors are classified")
    func speechFrameworkTeardownErrors() {
        #expect(SpeechRecognizerService.isExpectedTeardownRecognitionError(
            NSError(domain: "SFSpeechErrorDomain", code: 203)
        ))
        #expect(SpeechRecognizerService.isExpectedTeardownRecognitionError(
            NSError(domain: "SFSpeechErrorDomain", code: 216)
        ))
    }

    @Test("Non-teardown errors are not classified")
    func nonTeardownErrors() {
        #expect(!SpeechRecognizerService.isExpectedTeardownRecognitionError(
            NSError(domain: "kAFAssistantErrorDomain", code: 999)
        ))
        #expect(!SpeechRecognizerService.isExpectedTeardownRecognitionError(
            NSError(domain: "OtherDomain", code: 1101)
        ))
    }
}

@Suite("Orb Permission Failure Mapping")
struct OrbPermissionFailureMappingTests {

    @Test("Non-error statuses do not produce failure message")
    func nonErrorStatuses() {
        #expect(OrbEngine.failureMessage(for: .notDetermined) == nil)
        #expect(OrbEngine.failureMessage(for: .granted) == nil)
    }

    @Test("Permission-related statuses map to expected failure text")
    func permissionStatusMappings() {
        #expect(OrbEngine.failureMessage(for: .speechDenied) == "Speech recognition permission denied.")
        #expect(OrbEngine.failureMessage(for: .microphoneDenied) == "Microphone permission denied.")
        #expect(OrbEngine.failureMessage(for: .restricted) == "Speech recognition is restricted on this device.")
        #expect(OrbEngine.failureMessage(for: .unavailable) == "Speech recognition is unavailable.")
    }

    @Test("Error status returns passthrough message")
    func passthroughErrorStatus() {
        #expect(OrbEngine.failureMessage(for: .error("boom")) == "boom")
    }
}

@Suite("Orb Transcript Candidate")
struct OrbTranscriptCandidateTests {

    @Test("Prefers non-empty final transcript after trimming")
    func prefersFinalTranscript() {
        let result = OrbEngine.preferredTranscriptCandidate(
            finalTranscript: "  final result  ",
            transcript: "live value"
        )
        #expect(result == "final result")
    }

    @Test("Falls back to live transcript when final is empty")
    func fallsBackToLiveTranscript() {
        let result = OrbEngine.preferredTranscriptCandidate(
            finalTranscript: "   ",
            transcript: "  live value  "
        )
        #expect(result == "live value")
    }

    @Test("Returns empty when both sources are empty")
    func returnsEmptyWhenBothAreEmpty() {
        let result = OrbEngine.preferredTranscriptCandidate(
            finalTranscript: "   ",
            transcript: "\n\t"
        )
        #expect(result.isEmpty)
    }
}

@Suite("Orb Polled Final Transcript Candidate")
struct OrbPolledFinalTranscriptCandidateTests {

    @Test("Returns trimmed transcript when non-empty")
    func returnsTrimmedCandidate() {
        #expect(OrbEngine.polledFinalTranscriptCandidate("  result value  ") == "result value")
    }

    @Test("Returns nil when transcript is empty after trimming")
    func returnsNilForEmptyCandidate() {
        #expect(OrbEngine.polledFinalTranscriptCandidate(" \n\t ") == nil)
    }
}

@Suite("Orb Final Transcript Polling Limit")
struct OrbFinalTranscriptPollingLimitTests {

    @Test("Polling limit is positive and stable")
    func pollingLimit() {
        #expect(OrbEngine.finalTranscriptPollingIterationLimit() > 0)
        #expect(OrbEngine.finalTranscriptPollingIterationLimit() == 30)
    }
}

@Suite("Orb Final Transcript Polling Range")
struct OrbFinalTranscriptPollingRangeTests {

    @Test("Polling range starts at zero and matches limit")
    func pollingRangeShape() {
        let range = OrbEngine.finalTranscriptPollingAttemptRange()
        #expect(range.lowerBound == 0)
        #expect(range.count == OrbEngine.finalTranscriptPollingIterationLimit())
    }
}

@Suite("Orb Final Transcript Polling Sleep")
struct OrbFinalTranscriptPollingSleepTests {

    @Test("Polling sleep duration is positive and stable")
    func pollingSleepDuration() {
        #expect(OrbEngine.finalTranscriptPollingSleepNanoseconds() > 0)
        #expect(OrbEngine.finalTranscriptPollingSleepNanoseconds() == 50_000_000)
    }
}

@Suite("Orb Transcript Normalization")
struct OrbTranscriptNormalizationTests {

    @Test("Trims leading and trailing whitespace/newlines")
    func trimsWhitespace() {
        #expect(OrbEngine.normalizedTranscript("  hello world \n") == "hello world")
    }

    @Test("Preserves internal spacing while trimming edges")
    func preservesInternalSpacing() {
        #expect(OrbEngine.normalizedTranscript("  hello   world  ") == "hello   world")
    }
}

@Suite("Orb Normalized Transcript Content")
struct OrbNormalizedTranscriptContentTests {

    @Test("Returns true for non-empty normalized text")
    func returnsTrueForContent() {
        #expect(OrbEngine.hasNormalizedTranscriptContent("value"))
    }

    @Test("Returns false for empty normalized text")
    func returnsFalseForEmpty() {
        #expect(!OrbEngine.hasNormalizedTranscriptContent(""))
    }
}

@Suite("Orb Transcript Delivery Dedupe")
struct OrbTranscriptDeliveryDedupeTests {

    @Test("Delivers when candidate differs from last delivered")
    func deliversDifferentCandidate() {
        #expect(OrbEngine.shouldDeliverTranscriptCandidate(
            trimmedTranscript: "new value",
            lastDeliveredTranscript: "old value"
        ))
    }

    @Test("Skips when candidate matches last delivered")
    func skipsDuplicateCandidate() {
        #expect(!OrbEngine.shouldDeliverTranscriptCandidate(
            trimmedTranscript: "same value",
            lastDeliveredTranscript: "same value"
        ))
    }
}

@Suite("Orb Transcript Delivery State Mapping")
struct OrbTranscriptDeliveryStateMappingTests {

    @Test("Maps delivered transcript to ready state")
    func mapsToReadyState() {
        #expect(OrbEngine.stateAfterDeliveringTranscript("hello") == .ready(text: "hello"))
    }
}

@Suite("Orb Transcript Assignment")
struct OrbTranscriptAssignmentTests {

    @Test("Assignment copies text into both transcript fields")
    func assignmentCopiesBothFields() {
        let assignment = OrbEngine.transcriptAssignment(for: "hello")
        #expect(assignment.finalTranscript == "hello")
        #expect(assignment.transcript == "hello")
    }
}

@Suite("Orb Fallback Rejection State Mapping")
struct OrbFallbackRejectionStateMappingTests {

    @Test("Rejected fallback maps to idle state")
    func mapsToIdleState() {
        #expect(OrbEngine.stateAfterRejectingFallbackCandidate() == .idle)
    }
}

@Suite("Orb Idle Reset Decision")
struct OrbIdleResetDecisionTests {

    @Test("Resets to idle when recording is false")
    func resetsWhenNotRecording() {
        #expect(OrbEngine.shouldResetToIdleAfterDiscardedTranscript(isRecording: false))
    }

    @Test("Does not reset to idle when recording is true")
    func doesNotResetWhenRecording() {
        #expect(!OrbEngine.shouldResetToIdleAfterDiscardedTranscript(isRecording: true))
    }
}

@Suite("Orb Discarded Transcript State Mapping")
struct OrbDiscardedTranscriptStateMappingTests {

    @Test("Maps to idle when not recording")
    func mapsToIdleWhenNotRecording() {
        #expect(OrbEngine.stateAfterDiscardingTranscriptCandidate(
            currentState: .listening,
            isRecording: false
        ) == .idle)
    }

    @Test("Preserves current state when still recording")
    func preservesCurrentStateWhenRecording() {
        #expect(OrbEngine.stateAfterDiscardingTranscriptCandidate(
            currentState: .listening,
            isRecording: true
        ) == .listening)
    }
}

@Suite("Orb Stop Listening Eligibility")
struct OrbStopListeningEligibilityTests {

    @Test("Requires both recording and minimum duration")
    func requiresBothConditions() {
        #expect(OrbEngine.shouldBeginStopListening(isRecording: true, canStopListeningNow: true))

        #expect(!OrbEngine.shouldBeginStopListening(isRecording: false, canStopListeningNow: true))
        #expect(!OrbEngine.shouldBeginStopListening(isRecording: true, canStopListeningNow: false))
        #expect(!OrbEngine.shouldBeginStopListening(isRecording: false, canStopListeningNow: false))
    }
}

@Suite("Orb Stop Listening State Mapping")
struct OrbStopListeningStateMappingTests {

    @Test("Beginning stop-listening maps to transcribing")
    func mapsToTranscribing() {
        #expect(OrbEngine.stateAfterBeginningStopListening() == .transcribing)
    }
}

@Suite("Orb Fallback Transcript Acceptance")
struct OrbFallbackTranscriptAcceptanceTests {

    @Test("Accepts meaningful fallback transcript")
    func acceptsMeaningfulFallback() {
        #expect(OrbEngine.shouldAcceptFallbackTranscriptCandidate(
            text: "fallback text",
            hasDetectedSpeechContent: true,
            minimumTranscriptCharacterCount: 3
        ))
    }

    @Test("Rejects non-meaningful fallback transcript")
    func rejectsNonMeaningfulFallback() {
        #expect(!OrbEngine.shouldAcceptFallbackTranscriptCandidate(
            text: "--",
            hasDetectedSpeechContent: false,
            minimumTranscriptCharacterCount: 3
        ))
    }
}

@Suite("Orb Fallback Transcript Candidate Selection")
struct OrbFallbackTranscriptCandidateSelectionTests {

    @Test("Returns trimmed fallback when candidate is acceptable")
    func returnsTrimmedFallback() {
        #expect(OrbEngine.fallbackTranscriptCandidateAfterPolling(
            transcript: "  spoken words  ",
            hasDetectedSpeechContent: true,
            minimumTranscriptCharacterCount: 3
        ) == "spoken words")
    }

    @Test("Returns nil when fallback candidate is not acceptable")
    func returnsNilForRejectedFallback() {
        #expect(OrbEngine.fallbackTranscriptCandidateAfterPolling(
            transcript: "--",
            hasDetectedSpeechContent: false,
            minimumTranscriptCharacterCount: 3
        ) == nil)
    }
}

@Suite("Orb Fallback Transcript Trimming")
struct OrbFallbackTranscriptTrimmingTests {

    @Test("Trims leading and trailing whitespace/newlines")
    func trimsFallbackTranscript() {
        #expect(OrbEngine.trimmedFallbackTranscript("  fallback text\n") == "fallback text")
    }

    @Test("Returns empty string when transcript is all whitespace")
    func returnsEmptyForWhitespaceOnlyTranscript() {
        #expect(OrbEngine.trimmedFallbackTranscript(" \n\t ").isEmpty)
    }
}

@Suite("Orb Transcript Meaning")
struct OrbTranscriptMeaningTests {

    @Test("Rejects short text below minimum character count")
    func rejectsShortText() {
        #expect(!OrbEngine.isMeaningfulTranscriptCandidate(
            text: "ok",
            hasDetectedSpeechContent: true,
            minimumTranscriptCharacterCount: 3
        ))
    }

    @Test("Rejects text without alphanumeric characters")
    func rejectsNonAlphanumericText() {
        #expect(!OrbEngine.isMeaningfulTranscriptCandidate(
            text: "--- ...",
            hasDetectedSpeechContent: true,
            minimumTranscriptCharacterCount: 3
        ))
    }

    @Test("Accepts valid alphanumeric text when speech detected")
    func acceptsDetectedSpeechText() {
        #expect(OrbEngine.isMeaningfulTranscriptCandidate(
            text: "hello 123",
            hasDetectedSpeechContent: true,
            minimumTranscriptCharacterCount: 3
        ))
    }

    @Test("Accepts non-empty alphanumeric text even when speech flag is false")
    func acceptsAlphanumericFallback() {
        #expect(OrbEngine.isMeaningfulTranscriptCandidate(
            text: "  fallback value  ",
            hasDetectedSpeechContent: false,
            minimumTranscriptCharacterCount: 3
        ))
    }
}

@Suite("Orb Alphanumeric Content Detection")
struct OrbAlphanumericContentDetectionTests {

    @Test("Detects alphanumeric content")
    func detectsAlphanumeric() {
        #expect(OrbEngine.containsAlphanumericContent("abc"))
        #expect(OrbEngine.containsAlphanumericContent("123"))
        #expect(OrbEngine.containsAlphanumericContent("---x---"))
    }

    @Test("Rejects strings without alphanumeric content")
    func rejectsNonAlphanumeric() {
        #expect(!OrbEngine.containsAlphanumericContent("--- ..."))
        #expect(!OrbEngine.containsAlphanumericContent(" \n\t "))
    }
}

@Suite("Orb Transcript Minimum Length")
struct OrbTranscriptMinimumLengthTests {

    @Test("Returns true when length meets threshold")
    func meetsThreshold() {
        #expect(OrbEngine.meetsMinimumTranscriptLength(
            trimmedText: "abc",
            minimumTranscriptCharacterCount: 3
        ))
    }

    @Test("Returns false when length is below threshold")
    func belowThreshold() {
        #expect(!OrbEngine.meetsMinimumTranscriptLength(
            trimmedText: "ab",
            minimumTranscriptCharacterCount: 3
        ))
    }
}

@Suite("Orb Speech Content Detection Flag")
struct OrbSpeechContentDetectionFlagTests {

    @Test("Remains true once speech content has been detected")
    func remainsTrueWhenAlreadyDetected() {
        #expect(OrbEngine.updatedSpeechContentDetectionFlag(
            currentValue: true,
            trimmedTranscript: ""
        ))
    }

    @Test("Turns true when transcript contains content")
    func turnsTrueWithContent() {
        #expect(OrbEngine.updatedSpeechContentDetectionFlag(
            currentValue: false,
            trimmedTranscript: "hello"
        ))
    }

    @Test("Stays false when no prior detection and transcript is empty")
    func staysFalseWithoutContent() {
        #expect(!OrbEngine.updatedSpeechContentDetectionFlag(
            currentValue: false,
            trimmedTranscript: ""
        ))
    }
}

@Suite("Orb Listening Duration")
struct OrbListeningDurationTests {

    @Test("Rejects stop when listening start timestamp is missing")
    func rejectsMissingStartTime() {
        #expect(!OrbEngine.hasMetMinimumListeningDuration(
            listeningStartedAt: nil,
            now: Date(),
            minimumListeningDuration: 0.7
        ))
    }

    @Test("Rejects stop when elapsed duration is below threshold")
    func rejectsBelowThreshold() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let now = Date(timeIntervalSinceReferenceDate: 1_000.6)
        #expect(!OrbEngine.hasMetMinimumListeningDuration(
            listeningStartedAt: start,
            now: now,
            minimumListeningDuration: 0.7
        ))
    }

    @Test("Allows stop when elapsed duration meets threshold")
    func allowsAtThreshold() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let now = Date(timeIntervalSinceReferenceDate: 1_000.7)
        #expect(OrbEngine.hasMetMinimumListeningDuration(
            listeningStartedAt: start,
            now: now,
            minimumListeningDuration: 0.7
        ))
    }
}

@Suite("Orb Permission Message Mapping")
struct OrbPermissionMessageMappingTests {

    @Test("Non-blocking statuses return empty message")
    func nonBlockingStatuses() {
        #expect(OrbEngine.permissionMessage(for: .notDetermined).isEmpty)
        #expect(OrbEngine.permissionMessage(for: .granted).isEmpty)
    }

    @Test("Denied/restricted/unavailable statuses map to expected text")
    func deniedAndRestrictedMappings() {
        #expect(OrbEngine.permissionMessage(for: .speechDenied) == "Speech recognition access is required to transcribe your voice.")
        #expect(OrbEngine.permissionMessage(for: .microphoneDenied) == "Microphone access is required to capture your voice.")
        #expect(OrbEngine.permissionMessage(for: .restricted) == "Speech recognition is restricted on this device.")
        #expect(OrbEngine.permissionMessage(for: .unavailable) == "Speech recognizer is temporarily unavailable.")
    }

    @Test("Error status returns passthrough message")
    func errorPassthrough() {
        #expect(OrbEngine.permissionMessage(for: .error("custom")) == "custom")
    }
}

@Suite("Orb Failure State Mapping")
struct OrbFailureStateMappingTests {

    @Test("Non-failing statuses map to nil state")
    func nonFailingStatuses() {
        #expect(OrbEngine.failureState(for: .notDetermined) == nil)
        #expect(OrbEngine.failureState(for: .granted) == nil)
    }

    @Test("Permission-related statuses map to failure state")
    func permissionFailures() {
        #expect(OrbEngine.failureState(for: .speechDenied) == .failure("Speech recognition permission denied."))
        #expect(OrbEngine.failureState(for: .microphoneDenied) == .failure("Microphone permission denied."))
        #expect(OrbEngine.failureState(for: .restricted) == .failure("Speech recognition is restricted on this device."))
        #expect(OrbEngine.failureState(for: .unavailable) == .failure("Speech recognition is unavailable."))
    }

    @Test("Error status maps to passthrough failure state")
    func passthroughError() {
        #expect(OrbEngine.failureState(for: .error("boom")) == .failure("boom"))
    }
}

@Suite("Orb Permission Failure Classification")
struct OrbPermissionFailureClassificationTests {

    @Test("Failing statuses are classified as failing")
    func failingStatuses() {
        #expect(OrbEngine.isFailingPermissionStatus(.speechDenied))
        #expect(OrbEngine.isFailingPermissionStatus(.microphoneDenied))
        #expect(OrbEngine.isFailingPermissionStatus(.restricted))
        #expect(OrbEngine.isFailingPermissionStatus(.unavailable))
        #expect(OrbEngine.isFailingPermissionStatus(.error("x")))
    }

    @Test("Non-failing statuses are not classified as failing")
    func nonFailingStatuses() {
        #expect(!OrbEngine.isFailingPermissionStatus(.granted))
        #expect(!OrbEngine.isFailingPermissionStatus(.notDetermined))
    }
}

@Suite("Orb Permission Status State Transition")
struct OrbPermissionStatusStateTransitionTests {

    @Test("Preserves current state for non-failing statuses")
    func preservesCurrentState() {
        #expect(OrbEngine.stateAfterPermissionStatusUpdate(
            currentState: .listening,
            status: .granted
        ) == .listening)

        #expect(OrbEngine.stateAfterPermissionStatusUpdate(
            currentState: .generating,
            status: .notDetermined
        ) == .generating)
    }

    @Test("Transitions to failure for failing statuses")
    func transitionsToFailure() {
        #expect(OrbEngine.stateAfterPermissionStatusUpdate(
            currentState: .listening,
            status: .speechDenied
        ) == .failure("Speech recognition permission denied."))

        #expect(OrbEngine.stateAfterPermissionStatusUpdate(
            currentState: .idle,
            status: .error("boom")
        ) == .failure("boom"))
    }
}

@Suite("Orb Recording State Transition")
struct OrbRecordingStateTransitionTests {

    @Test("Transitions to listening when recording becomes true")
    func transitionsToListening() {
        #expect(OrbEngine.stateAfterRecordingUpdate(
            currentState: .idle,
            isRecording: true
        ) == .listening)
    }

    @Test("Preserves current state when recording is false")
    func preservesStateWhenNotRecording() {
        #expect(OrbEngine.stateAfterRecordingUpdate(
            currentState: .generating,
            isRecording: false
        ) == .generating)
    }
}

@Suite("Orb Permission Settings Action Mapping")
struct OrbPermissionSettingsActionMappingTests {

    @Test("Denied/restricted statuses require Settings action")
    func deniedStatusesRequireSettings() {
        #expect(OrbEngine.needsPermissionSettingsAction(for: .speechDenied))
        #expect(OrbEngine.needsPermissionSettingsAction(for: .microphoneDenied))
        #expect(OrbEngine.needsPermissionSettingsAction(for: .restricted))
    }

    @Test("Other statuses do not require Settings action")
    func otherStatusesDoNotRequireSettings() {
        #expect(!OrbEngine.needsPermissionSettingsAction(for: .notDetermined))
        #expect(!OrbEngine.needsPermissionSettingsAction(for: .granted))
        #expect(!OrbEngine.needsPermissionSettingsAction(for: .unavailable))
        #expect(!OrbEngine.needsPermissionSettingsAction(for: .error("x")))
    }
}

@Suite("Orb Final Transcript Finalize Gate")
struct OrbFinalTranscriptFinalizeGateTests {

    @Test("Allows finalize only for listening/transcribing with non-empty transcript")
    func allowsOnlyEligibleStates() {
        #expect(OrbEngine.shouldFinalizeOnFinalTranscriptUpdate(
            trimmedFinalTranscript: "text",
            state: .listening
        ))
        #expect(OrbEngine.shouldFinalizeOnFinalTranscriptUpdate(
            trimmedFinalTranscript: "text",
            state: .transcribing
        ))

        #expect(!OrbEngine.shouldFinalizeOnFinalTranscriptUpdate(
            trimmedFinalTranscript: "text",
            state: .idle
        ))
        #expect(!OrbEngine.shouldFinalizeOnFinalTranscriptUpdate(
            trimmedFinalTranscript: "text",
            state: .generating
        ))
        #expect(!OrbEngine.shouldFinalizeOnFinalTranscriptUpdate(
            trimmedFinalTranscript: "text",
            state: .success
        ))
    }

    @Test("Rejects empty transcript for all states")
    func rejectsEmptyTranscript() {
        #expect(!OrbEngine.shouldFinalizeOnFinalTranscriptUpdate(
            trimmedFinalTranscript: "",
            state: .listening
        ))
        #expect(!OrbEngine.shouldFinalizeOnFinalTranscriptUpdate(
            trimmedFinalTranscript: "",
            state: .transcribing
        ))
    }
}

@Suite("Orb Final Transcript Eligible States")
struct OrbFinalTranscriptEligibleStatesTests {

    @Test("Listening/transcribing are eligible")
    func eligibleStates() {
        #expect(OrbEngine.isStateEligibleForFinalTranscriptFinalize(.listening))
        #expect(OrbEngine.isStateEligibleForFinalTranscriptFinalize(.transcribing))
    }

    @Test("Other states are not eligible")
    func ineligibleStates() {
        #expect(!OrbEngine.isStateEligibleForFinalTranscriptFinalize(.idle))
        #expect(!OrbEngine.isStateEligibleForFinalTranscriptFinalize(.generating))
        #expect(!OrbEngine.isStateEligibleForFinalTranscriptFinalize(.success))
        #expect(!OrbEngine.isStateEligibleForFinalTranscriptFinalize(.failure("x")))
    }
}
