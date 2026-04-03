import Testing
import Foundation
@testable import Prompt28
@testable import Supabase
#if canImport(UIKit)
import UIKit
#endif

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

// MARK: - HistoryStore Tests

@Suite("HistoryStore")
struct HistoryStoreTests {

    @MainActor
    private func makeSupabase() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseKey: "test-key"
        )
    }

    private func makeAppDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HistoryStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @MainActor
    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        condition: @escaping () -> Bool
    ) async -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if condition() { return true }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return condition()
    }

    @Test("Cold launch with existing session triggers automatic sync")
    @MainActor
    func coldLaunchExistingSessionTriggersSync() async {
        let appDirectory = makeAppDirectory()
        let userID = UUID()
        var syncCalls: [UUID] = []

        _ = HistoryStore(
            supabase: makeSupabase(),
            appDirectoryURL: appDirectory,
            startAuthListenerOnInit: false,
            observeAppLifecycle: false,
            sessionUserIDProvider: { userID },
            syncExecutor: { id in syncCalls.append(id) }
        )

        let synced = await waitUntil { syncCalls == [userID] }
        #expect(synced)
    }

    @Test("Add, favorite, and rename trigger best-effort sync for signed-in user")
    @MainActor
    func mutationsTriggerImmediateSync() async {
        let appDirectory = makeAppDirectory()
        let userID = UUID()
        var syncCalls: [UUID] = []

        let store = HistoryStore(
            supabase: makeSupabase(),
            appDirectoryURL: appDirectory,
            startAuthListenerOnInit: false,
            observeAppLifecycle: false,
            sessionUserIDProvider: { userID },
            syncExecutor: { id in syncCalls.append(id) }
        )

        _ = await waitUntil { !syncCalls.isEmpty }
        syncCalls.removeAll()

        let item = PromptHistoryItem(mode: .ai, input: "Test input", professional: "Result", template: "Template")
        store.add(item)
        store.toggleFavorite(id: item.id)
        store.rename(id: item.id, customName: "Renamed")

        let completed = await waitUntil { syncCalls.count == 3 }
        #expect(completed)
        #expect(syncCalls == [userID, userID, userID])
    }

    @Test("Rapid consecutive mutations do not overlap syncs")
    @MainActor
    func rapidMutationsDoNotStartOverlappingSyncs() async {
        let appDirectory = makeAppDirectory()
        let userID = UUID()
        let syncStarted = ManagedAtomicCounter()

        let store = HistoryStore(
            supabase: makeSupabase(),
            appDirectoryURL: appDirectory,
            startAuthListenerOnInit: false,
            observeAppLifecycle: false,
            sessionUserIDProvider: { userID },
            syncExecutor: { _ in
                syncStarted.increment()
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        )

        _ = await waitUntil { syncStarted.value > 0 }
        syncStarted.reset()

        let item = PromptHistoryItem(mode: .ai, input: "Rapid", professional: "Result", template: "Template")
        store.add(item)
        store.toggleFavorite(id: item.id)
        store.rename(id: item.id, customName: "New Name")

        let settled = await waitUntil(timeoutNanoseconds: 500_000_000) { syncStarted.value == 1 }
        #expect(settled)
        try? await Task.sleep(nanoseconds: 200_000_000)
        #expect(syncStarted.value == 1)
    }

    @Test("Pending deletes persist across app relaunch")
    @MainActor
    func pendingDeletesPersistAcrossRelaunch() async throws {
        let appDirectory = makeAppDirectory()
        let itemID = UUID()

        do {
            let store = HistoryStore(
                supabase: makeSupabase(),
                appDirectoryURL: appDirectory,
                startAuthListenerOnInit: false,
                observeAppLifecycle: false,
                sessionUserIDProvider: { nil },
                syncExecutor: nil
            )
            store.add(PromptHistoryItem(id: itemID, mode: .ai, input: "Delete me", professional: "Result", template: "Template"))
            store.remove(id: itemID)
        }

        let data = try Data(contentsOf: appDirectory.appendingPathComponent("history_pending_deletes.json"))
        let pendingDeletes = try JSONDecoder().decode([UUID].self, from: data)
        #expect(Set(pendingDeletes) == [itemID])
    }

    @Test("Foreground retry syncs pending local work after reconnect")
    @MainActor
    func foregroundRetrySyncsPendingWork() async {
        #if canImport(UIKit)
        let appDirectory = makeAppDirectory()
        let userID = UUID()
        var currentUserID: UUID? = nil
        var syncCalls: [UUID] = []

        let store = HistoryStore(
            supabase: makeSupabase(),
            appDirectoryURL: appDirectory,
            startAuthListenerOnInit: false,
            observeAppLifecycle: false,
            reconcileInitialSessionOnInit: false,
            sessionUserIDProvider: { currentUserID },
            syncExecutor: { id in syncCalls.append(id) }
        )

        _ = store
        let item = PromptHistoryItem(mode: .ai, input: "Offline", professional: "Result", template: "Template")
        store.add(item)
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(syncCalls.isEmpty)

        currentUserID = userID
        store.handleAppBecameActiveForSyncRetry()

        let retried = await waitUntil { syncCalls == [userID] }
        #expect(retried)
        #else
        Issue.record("UIKit unavailable for foreground retry test on this platform")
        #endif
    }

    @Test("Large history still prunes to max items")
    @MainActor
    func largeHistoryStillPrunes() {
        let appDirectory = makeAppDirectory()
        let store = HistoryStore(
            supabase: makeSupabase(),
            appDirectoryURL: appDirectory,
            startAuthListenerOnInit: false,
            observeAppLifecycle: false,
            sessionUserIDProvider: { nil },
            syncExecutor: nil
        )

        for index in 0..<250 {
            store.add(PromptHistoryItem(mode: .ai, input: "Input \(index)", professional: "Result \(index)", template: "Template"))
        }

        #expect(store.items.count == 200)
    }

    @Test("Signed-out launch clears local history for user isolation")
    @MainActor
    func signedOutLaunchClearsLocalHistory() async {
        let appDirectory = makeAppDirectory()

        do {
            let seededStore = HistoryStore(
                supabase: makeSupabase(),
                appDirectoryURL: appDirectory,
                startAuthListenerOnInit: false,
                observeAppLifecycle: false,
                sessionUserIDProvider: { UUID() },
                syncExecutor: { _ in }
            )
            let item = PromptHistoryItem(mode: .ai, input: "Seed", professional: "Result", template: "Template")
            seededStore.add(item)
            seededStore.remove(id: item.id)
        }

        let store = HistoryStore(
            supabase: makeSupabase(),
            appDirectoryURL: appDirectory,
            startAuthListenerOnInit: false,
            observeAppLifecycle: false,
            sessionUserIDProvider: { nil },
            syncExecutor: nil
        )

        let cleared = await waitUntil { store.items.isEmpty }
        #expect(cleared)

        let pendingDeletesURL = appDirectory.appendingPathComponent("history_pending_deletes.json")
        let data = try? Data(contentsOf: pendingDeletesURL)
        let pendingDeletes = (try? JSONDecoder().decode([UUID].self, from: data ?? Data())) ?? [UUID()]
        #expect(pendingDeletes.isEmpty)
    }
}

private final class ManagedAtomicCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func increment() {
        lock.lock()
        storage += 1
        lock.unlock()
    }

    func reset() {
        lock.lock()
        storage = 0
        lock.unlock()
    }
}
