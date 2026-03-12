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


