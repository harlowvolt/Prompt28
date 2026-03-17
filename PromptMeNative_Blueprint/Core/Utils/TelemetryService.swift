import Foundation
import UIKit

<<<<<<< HEAD
// MARK: - TelemetryRecord

/// Structured error payload stored locally and eventually flushed to the
/// `telemetry_errors` Supabase table (Phase 2).
struct TelemetryRecord: Codable {
    let id: UUID
    let errorDomain: String
    let errorCode: Int
    let errorMessage: String
    let deviceModel: String
    let iosVersion: String
    let appState: String
    let timestamp: Date
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case errorDomain   = "error_domain"
        case errorCode     = "error_code"
        case errorMessage  = "error_message"
        case deviceModel   = "device_model"
        case iosVersion    = "ios_version"
        case appState      = "app_state"
        case timestamp
        case userId        = "user_id"
    }
}

// MARK: - TelemetryService

/// Phase 1 error telemetry service.
///
/// Structured errors are written to a UserDefaults FIFO queue (max 50) so
/// that nothing is lost before the Supabase `telemetry_errors` table is
/// available. The queue is flushed automatically when the app moves to
/// background.
///
/// Call `uploadToSupabase()` once SupabaseClient is configured (Phase 2).
@MainActor
final class TelemetryService {
    static let shared = TelemetryService()

    private let cacheKey = "telemetry_error_cache"
    private let maxCacheSize = 50
    private var userId: String?

    private init() {
        // Flush on background so queued errors are uploaded opportunistically.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.uploadToSupabase()
            }
        }
    }

    // MARK: - User identity

    func setUserId(_ id: String?) {
        userId = id
    }

    // MARK: - Logging

    /// Log a network or API error from `APIClient`.
    func logNetworkError(
        _ error: Error,
        endpoint: String,
        appState: String = "foreground"
    ) {
        let nsError = error as NSError
        let record = TelemetryRecord(
            id: UUID(),
            errorDomain: nsError.domain,
            errorCode: nsError.code,
            errorMessage: "\(endpoint): \(error.localizedDescription)",
            deviceModel: Self.deviceModel,
            iosVersion: Self.iosVersion,
            appState: appState,
            timestamp: Date(),
            userId: userId
        )
        appendToCache(record)
        #if DEBUG
        print("📡 [Telemetry] network error \(nsError.domain)/\(nsError.code): \(error.localizedDescription)")
        #endif
    }

    /// Log a speech recognition failure from `SpeechRecognizerService`.
    func logSpeechError(
        _ error: Error,
        appState: String = "recording"
    ) {
        let nsError = error as NSError
        let record = TelemetryRecord(
            id: UUID(),
            errorDomain: nsError.domain,
            errorCode: nsError.code,
            errorMessage: "speech: \(error.localizedDescription)",
            deviceModel: Self.deviceModel,
            iosVersion: Self.iosVersion,
            appState: appState,
            timestamp: Date(),
            userId: userId
        )
        appendToCache(record)
        #if DEBUG
        print("🎤 [Telemetry] speech error \(nsError.domain)/\(nsError.code): \(error.localizedDescription)")
        #endif
    }

    /// General-purpose error logger for any subsystem.
    func log(
        domain: String,
        code: Int = 0,
        message: String,
        appState: String = "foreground"
    ) {
        let record = TelemetryRecord(
            id: UUID(),
            errorDomain: domain,
            errorCode: code,
            errorMessage: message,
            deviceModel: Self.deviceModel,
            iosVersion: Self.iosVersion,
            appState: appState,
            timestamp: Date(),
            userId: userId
        )
        appendToCache(record)
        #if DEBUG
        print("⚠️ [Telemetry] \(domain)/\(code): \(message)")
        #endif
    }

    // MARK: - Cache management

    private func appendToCache(_ record: TelemetryRecord) {
        var cached = loadCache()
        cached.append(record)
        // FIFO: drop oldest records when limit is exceeded.
        if cached.count > maxCacheSize {
            cached = Array(cached.suffix(maxCacheSize))
        }
        saveCache(cached)
    }

    func loadCache() -> [TelemetryRecord] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let records = try? JSONDecoder().decode([TelemetryRecord].self, from: data) else {
            return []
        }
        return records
    }

    private func saveCache(_ records: [TelemetryRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    // MARK: - Supabase upload (Phase 2 stub)

    /// Drains the local cache to the Supabase `telemetry_errors` table.
    /// Wire this up in Phase 2 once `SupabaseClient` is configured.
    func uploadToSupabase() async {
        let pending = loadCache()
        guard !pending.isEmpty else { return }

        // TODO (Phase 2): batch-insert `pending` into `telemetry_errors`.
        //
        // Example:
        //   try await supabase.from("telemetry_errors").insert(pending).execute()
        //   clearCache()
    }

    // MARK: - Device info helpers

    private static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 1) { cStr in
                String(validatingUTF8: cStr) ?? "unknown"
            }
        }
    }

    private static var iosVersion: String {
        UIDevice.current.systemVersion
=======
// MARK: - Telemetry Error Types

enum TelemetryErrorDomain: String, Codable {
    case speechRecognition = "speech_recognition"
    case network = "network"
    case api = "api"
    case orb = "orb"
    case auth = "auth"
    case store = "store"
    case cloudKit = "cloudkit"
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
/// Phase 1: Local caching implemented, ready for Supabase integration in Phase 2.
/// Captures AI timeouts, transcription failures, rendering crashes, and network errors.
@MainActor
final class TelemetryService {
    static let shared = TelemetryService()
    
    // Session tracking
    static let currentSessionId = UUID().uuidString
    
    // Device info (cached)
    static let deviceModel: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }()
    
    static let iosVersion: String = {
        return UIDevice.current.systemVersion
    }()
    
    static let appVersion: String = {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }()
    
    // MARK: - Properties
    
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "orion.orb.telemetry.cache"
    private let maxCacheSize = 50  // Limit to prevent storage bloat
    private var cachedRecords: [TelemetryRecord] = []
    private var currentUserId: String?
    private var currentAppState: AppState = .launching
    
    private init() {
        loadCachedRecords()
        setupAppStateMonitoring()
    }
    
    // MARK: - Public API
    
    /// Set the current user ID for error attribution
    func setUserId(_ id: String?) {
        self.currentUserId = id
    }
    
    /// Log an error with full context
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
    
    /// Convenience methods for common error types
    
    func logSpeechError(code: String, message: String) {
        logError(domain: .speechRecognition, code: code, message: message)
    }
    
    func logNetworkError(code: String, message: String, url: String? = nil) {
        let fullMessage = url != nil ? "\(message) - URL: \(url!)" : message
        logError(domain: .network, code: code, message: fullMessage)
    }
    
    func logAPIError(code: String, message: String, endpoint: String? = nil) {
        let fullMessage = endpoint != nil ? "\(message) - Endpoint: \(endpoint!)" : message
        logError(domain: .api, code: code, message: fullMessage)
    }
    
    func logOrbError(code: String, message: String) {
        logError(domain: .orb, code: code, message: message)
    }
    
    func logAuthError(code: String, message: String) {
        logError(domain: .auth, code: code, message: message)
    }
    
    func logStoreError(code: String, message: String) {
        logError(domain: .store, code: code, message: message)
    }
    
    func logStorageError(code: String, message: String) {
        logError(domain: .storage, code: code, message: message)
    }
    
    /// Get all pending records for upload
    func getPendingRecords() -> [TelemetryRecord] {
        return cachedRecords
    }
    
    /// Clear records that have been successfully uploaded
    func clearUploadedRecords(_ recordIds: [UUID]) {
        cachedRecords.removeAll { recordIds.contains($0.id) }
        persistCache()
    }
    
    /// Clear all cached records
    func clearAllRecords() {
        cachedRecords.removeAll()
        userDefaults.removeObject(forKey: cacheKey)
    }
    
    /// Get count of pending records
    var pendingRecordCount: Int {
        return cachedRecords.count
    }
    
    // MARK: - Private
    
    private func cacheRecord(_ record: TelemetryRecord) {
        cachedRecords.append(record)
        
        // Maintain max cache size (FIFO)
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
    
    private func setupAppStateMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        currentAppState = .active
    }
    
    @objc private func appWillResignActive() {
        currentAppState = .inactive
    }
    
    @objc private func appDidEnterBackground() {
        currentAppState = .background
        // Attempt upload when going to background
        Task { await uploadToSupabase() }
    }
    
    @objc private func appWillEnterForeground() {
        currentAppState = .foreground
    }
}

// MARK: - Phase 2: Supabase Upload Extension

extension TelemetryService {
    /// Upload pending records to Supabase (implement in Phase 2)
    /// 
    /// This will be called:
    /// - When app enters background
    /// - When record count reaches threshold
    /// - Periodically during app usage
    func uploadToSupabase() async {
        guard !cachedRecords.isEmpty else { return }
        
        // Phase 2 Implementation:
        // 1. Get pending records
        // 2. Format for Supabase telemetry_errors table
        // 3. POST to Supabase
        // 4. Clear uploaded records on success
        // 5. Retry with exponential backoff on failure
        
        #if DEBUG
        print("🐛 [Telemetry] Would upload \(pendingRecordCount) records to Supabase")
        #endif
>>>>>>> 672afe4ae655afe7762f0394bb152c9d4bbe6247
    }
}
