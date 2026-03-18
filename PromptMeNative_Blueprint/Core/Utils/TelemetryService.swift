import Foundation
import UIKit
@preconcurrency import Supabase

// MARK: - Telemetry Error Types

enum TelemetryErrorDomain: String, Codable {
    case speechRecognition = "speech_recognition"
    case network = "network"
    case api = "api"
    case orb = "orb"
    case auth = "auth"
    case store = "store"
    case storage = "storage"
    case unknown = "unknown"
}

enum AppState: String, Codable {
    case active = "active"
    case inactive = "inactive"
    case background = "background"
    case foreground = "foreground"
    case launching = "launching"
}

// MARK: - Telemetry Record

/// Structured error payload stored locally and flushed to the
/// `telemetry_errors` Supabase table.
struct TelemetryRecord: Codable, Identifiable {
    let id: UUID
    let errorDomain: String
    let errorCode: String
    let errorMessage: String
    let stackTrace: String?
    let deviceModel: String
    let iosVersion: String
    let appVersion: String
    let appState: String
    let timestamp: Date
    let userId: String?
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case id
        case errorDomain  = "error_domain"
        case errorCode    = "error_code"
        case errorMessage = "error_message"
        case stackTrace   = "stack_trace"
        case deviceModel  = "device_model"
        case iosVersion   = "ios_version"
        case appVersion   = "app_version"
        case appState     = "app_state"
        case timestamp
        case userId       = "user_id"
        case sessionId    = "session_id"
    }

    init(
        domain: TelemetryErrorDomain,
        code: String,
        message: String,
        stackTrace: String? = nil,
        appState: AppState = .active,
        userId: String? = nil
    ) {
        self.id = UUID()
        self.errorDomain = domain.rawValue
        self.errorCode = code
        self.errorMessage = message
        self.stackTrace = stackTrace
        self.deviceModel = TelemetryService.deviceModel
        self.iosVersion = TelemetryService.iosVersion
        self.appVersion = TelemetryService.appVersion
        self.appState = appState.rawValue
        self.timestamp = Date()
        self.userId = userId
        self.sessionId = TelemetryService.currentSessionId
    }
}

// MARK: - Telemetry Service

/// Production error telemetry system for structured error logging.
///
/// Records are queued locally (UserDefaults, max 50 FIFO) and flushed to the
/// Supabase `telemetry_errors` table when the app enters background or when
/// `uploadToSupabase()` is called explicitly.
///
/// Call `configure(supabase:)` once from `AppEnvironment.init()`.
@MainActor
final class TelemetryService {
    static let shared = TelemetryService()

    // MARK: - Shared identity

    /// Unique per process launch, attached to every record.
    static let currentSessionId = UUID().uuidString

    /// Device model string, cached at launch.
    static let deviceModel: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return result }
            return result + String(UnicodeScalar(UInt8(value)))
        }
    }()

    static let iosVersion: String = UIDevice.current.systemVersion

    static let appVersion: String =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

    // MARK: - Properties

    private let userDefaults = UserDefaults.standard
    private let cacheKey = "orion.orb.telemetry.cache"
    private let maxCacheSize = 50
    private var cachedRecords: [TelemetryRecord] = []
    private var currentUserId: String?
    private var currentAppState: AppState = .launching
    private var supabase: SupabaseClient?

    // MARK: - Init

    private init() {
        loadCachedRecords()
        setupAppStateMonitoring()
    }

    // MARK: - Configuration

    /// Inject the live Supabase client. Call once from `AppEnvironment.init()`.
    func configure(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    // MARK: - User identity

    func setUserId(_ id: String?) {
        currentUserId = id
    }

    // MARK: - Logging API

    func logError(
        domain: TelemetryErrorDomain,
        code: String,
        message: String,
        stackTrace: String? = nil
    ) {
        let record = TelemetryRecord(
            domain: domain,
            code: code,
            message: message,
            stackTrace: stackTrace,
            appState: currentAppState,
            userId: currentUserId
        )
        cacheRecord(record)
        #if DEBUG
        print("🐛 [Telemetry] [\(domain.rawValue)] \(code): \(message)")
        #endif
    }

    func logSpeechError(code: String, message: String) {
        logError(domain: .speechRecognition, code: code, message: message)
    }

    func logNetworkError(code: String, message: String, url: String? = nil) {
        let fullMessage = url.map { "\(message) — URL: \($0)" } ?? message
        logError(domain: .network, code: code, message: fullMessage)
    }

    func logAPIError(code: String, message: String, endpoint: String? = nil) {
        let fullMessage = endpoint.map { "\(message) — Endpoint: \($0)" } ?? message
        logError(domain: .api, code: code, message: fullMessage)
    }

    func logAuthError(code: String, message: String) {
        logError(domain: .auth, code: code, message: message)
    }

    func logOrbError(code: String, message: String) {
        logError(domain: .orb, code: code, message: message)
    }

    func logStoreError(code: String, message: String) {
        logError(domain: .store, code: code, message: message)
    }

    func logStorageError(code: String, message: String) {
        logError(domain: .storage, code: code, message: message)
    }

    // MARK: - Cache inspection

    func getPendingRecords() -> [TelemetryRecord] { cachedRecords }
    var pendingRecordCount: Int { cachedRecords.count }

    func clearUploadedRecords(_ ids: [UUID]) {
        cachedRecords.removeAll { ids.contains($0.id) }
        persistCache()
    }

    func clearAllRecords() {
        cachedRecords.removeAll()
        userDefaults.removeObject(forKey: cacheKey)
    }

    // MARK: - Private cache management

    private func cacheRecord(_ record: TelemetryRecord) {
        cachedRecords.append(record)
        if cachedRecords.count > maxCacheSize {
            cachedRecords.removeFirst(cachedRecords.count - maxCacheSize)
        }
        persistCache()
    }

    private func loadCachedRecords() {
        guard let data = userDefaults.data(forKey: cacheKey),
              let records = try? JSONDecoder().decode([TelemetryRecord].self, from: data) else {
            cachedRecords = []
            return
        }
        cachedRecords = records
    }

    private func persistCache() {
        guard let data = try? JSONEncoder().encode(cachedRecords) else { return }
        userDefaults.set(data, forKey: cacheKey)
    }

    // MARK: - App state monitoring (closure-based, no NSObject required)

    private func setupAppStateMonitoring() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.currentAppState = .active }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.currentAppState = .inactive }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.currentAppState = .foreground }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentAppState = .background
                await self?.uploadToSupabase()
            }
        }
    }
}

// MARK: - Supabase Upload

extension TelemetryService {
    /// Drains the local cache to the Supabase `telemetry_errors` table.
    /// Called automatically on app-background; also callable on demand.
    func uploadToSupabase() async {
        guard let supabase, !cachedRecords.isEmpty else { return }

        let pending = cachedRecords

        do {
            try await supabase
                .from("telemetry_errors")
                .insert(pending)
                .execute()

            let uploadedIDs = pending.map(\.id)
            clearUploadedRecords(uploadedIDs)

            #if DEBUG
            print("🐛 [Telemetry] Uploaded \(pending.count) records to Supabase")
            #endif
        } catch {
            #if DEBUG
            print("🐛 [Telemetry] Upload failed: \(error.localizedDescription)")
            #endif
        }
    }
}
