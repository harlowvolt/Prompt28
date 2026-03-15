import Foundation
import UIKit

// MARK: - Telemetry Error Types

enum TelemetryErrorDomain: String, Codable {
    case speechRecognition = "speech_recognition"
    case network = "network"
    case api = "api"
    case orb = "orb"
    case auth = "auth"
    case store = "store"
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
    }
}
