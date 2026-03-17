import Foundation
import UIKit

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
    }
}
