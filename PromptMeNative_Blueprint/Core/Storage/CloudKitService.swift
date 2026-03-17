import Foundation
import CloudKit

/// CloudKit sync service for cross-device prompt history synchronization.
///
/// Phase 2: Implements two-way sync with conflict resolution (last modified wins).
/// Handles offline scenarios gracefully with silent failures and retry logic.
@Observable
@MainActor
final class CloudKitService {
    
    // MARK: - Properties
    
    private let container: CKContainer
    private let database: CKDatabase
    
    /// iCloud account status
    private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    
    /// Sync operation status
    private(set) var isSyncing: Bool = false
    
    /// Last sync error (if any)
    private(set) var lastError: Error?
    
    /// Record ID for the zone
    private let zoneID = CKRecordZone.ID(zoneName: "PromptHistoryZone", ownerName: CKCurrentUserDefaultName)
    
    // MARK: - Init
    
    init(containerIdentifier: String? = nil) {
        if let identifier = containerIdentifier {
            self.container = CKContainer(identifier: identifier)
        } else {
            self.container = CKContainer.default()
        }
        self.database = container.privateCloudDatabase
        
        // Check account status on init
        Task {
            await checkAccountStatus()
        }
    }
    
    // MARK: - Account Status
    
    /// Check iCloud account availability
    func checkAccountStatus() async -> CKAccountStatus {
        do {
            let status = try await container.accountStatus()
            accountStatus = status
            
            #if DEBUG
            switch status {
            case .available:
                print("☁️ [CloudKit] Account available")
            case .noAccount:
                print("⚠️ [CloudKit] No iCloud account")
            case .restricted:
                print("⚠️ [CloudKit] iCloud restricted")
            case .couldNotDetermine:
                print("⚠️ [CloudKit] Could not determine account status")
            @unknown default:
                print("⚠️ [CloudKit] Unknown account status")
            }
            #endif
            
            return status
        } catch {
            lastError = error
            accountStatus = .couldNotDetermine
            
            #if DEBUG
            print("❌ [CloudKit] Account status check failed: \(error.localizedDescription)")
            #endif
            
            TelemetryService.shared.logCloudKitError(
                code: "ACCOUNT_STATUS_FAILED",
                message: error.localizedDescription
            )
            
            return .couldNotDetermine
        }
    }
    
    /// Returns true if iCloud is available for sync
    var isCloudKitAvailable: Bool {
        accountStatus == .available
    }
    
    // MARK: - Two-Way Sync
    
    /// Perform two-way sync: upload local changes, download remote changes
    /// - Parameter items: Current local items
    /// - Returns: Merged items (local + remote with conflict resolution)
    func sync(items: [PromptHistoryItem]) async throws -> [PromptHistoryItem] {
        guard isCloudKitAvailable else {
            #if DEBUG
            print("⚠️ [CloudKit] Sync skipped - account not available")
            #endif
            return items
        }
        
        guard !isSyncing else {
            #if DEBUG
            print("⚠️ [CloudKit] Sync already in progress")
            #endif
            return items
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        #if DEBUG
        print("☁️ [CloudKit] Starting sync...")
        #endif
        
        do {
            // Ensure custom zone exists
            try await createZoneIfNeeded()
            
            // Step 1: Fetch remote records
            let remoteRecords = try await fetchRemoteRecords()
            
            // Step 2: Build lookup maps
            var localItemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
            var remoteItemsByID: [UUID: PromptHistoryItem] = [:]
            
            for record in remoteRecords {
                if let item = try? PromptHistoryItem(from: record) {
                    remoteItemsByID[item.id] = item
                }
            }
            
            // Step 3: Conflict resolution and merge
            var mergedItems: [PromptHistoryItem] = []
            var itemsToUpload: [PromptHistoryItem] = []
            
            let allIDs = Set(localItemsByID.keys).union(remoteItemsByID.keys)
            
            for id in allIDs {
                let localItem = localItemsByID[id]
                let remoteItem = remoteItemsByID[id]
                
                if let local = localItem, let remote = remoteItem {
                    // Conflict: both local and remote exist
                    // Resolution: last modified wins
                    if local.lastModified > remote.lastModified {
                        // Local is newer, upload local
                        mergedItems.append(local)
                        itemsToUpload.append(local)
                    } else if remote.lastModified > local.lastModified {
                        // Remote is newer, use remote
                        mergedItems.append(remote)
                    } else {
                        // Same timestamp, prefer local (user's current device)
                        mergedItems.append(local)
                    }
                } else if let local = localItem {
                    // Only local exists
                    if !local.isSynced {
                        // New local item, upload it
                        itemsToUpload.append(local)
                    }
                    mergedItems.append(local)
                } else if let remote = remoteItem {
                    // Only remote exists, download it
                    mergedItems.append(remote)
                }
            }
            
            // Step 4: Upload pending changes
            for item in itemsToUpload {
                do {
                    try await saveToCloud(item)
                } catch {
                    // Continue with other items if one fails
                    #if DEBUG
                    print("⚠️ [CloudKit] Failed to upload item \(item.id): \(error.localizedDescription)")
                    #endif
                }
            }
            
            // Step 5: Sort by createdAt (newest first)
            mergedItems.sort { $0.createdAt > $1.createdAt }
            
            #if DEBUG
            print("☁️ [CloudKit] Sync complete - \(mergedItems.count) items")
            #endif
            
            return mergedItems
            
        } catch {
            lastError = error
            
            TelemetryService.shared.logCloudKitError(
                code: "SYNC_FAILED",
                message: error.localizedDescription
            )
            
            // Return original items on failure (don't lose data)
            #if DEBUG
            print("❌ [CloudKit] Sync failed: \(error.localizedDescription)")
            #endif
            
            return items
        }
    }
    
    /// Fetch all remote records from CloudKit
    func fetchRemoteRecords() async throws -> [CKRecord] {
        guard isCloudKitAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        let query = CKQuery(recordType: "PromptHistoryItem", predicate: NSPredicate(value: true))
        
        do {
            let (matchResults, _) = try await database.records(matching: query, inZoneWith: zoneID)
            return matchResults.compactMap { (_, result) -> CKRecord? in
                switch result {
                case .success(let record):
                    return record
                case .failure(let error):
                    #if DEBUG
                    print("⚠️ [CloudKit] Failed to fetch record: \(error.localizedDescription)")
                    #endif
                    return nil
                }
            }
        } catch {
            TelemetryService.shared.logCloudKitError(
                code: "FETCH_FAILED",
                message: error.localizedDescription
            )
            throw error
        }
    }
    
    /// Save a single item to CloudKit
    func saveToCloud(_ item: PromptHistoryItem) async throws {
        guard isCloudKitAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        let record = item.toCKRecord()
        
        do {
            let saveResult = try await database.save(record)
            item.recordID = saveResult.recordID
            item.isSynced = true
            
            #if DEBUG
            print("☁️ [CloudKit] Saved item \(item.id)")
            #endif
        } catch {
            TelemetryService.shared.logCloudKitError(
                code: "SAVE_FAILED",
                message: "Item \(item.id): \(error.localizedDescription)"
            )
            throw error
        }
    }
    
    /// Delete an item from CloudKit
    func deleteFromCloud(id: UUID) async throws {
        guard isCloudKitAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        // We need the recordID to delete. Since we don't have it here,
        // we'll fetch by matching the id field
        let predicate = NSPredicate(format: "id == %@", id.uuidString)
        let query = CKQuery(recordType: "PromptHistoryItem", predicate: predicate)
        
        do {
            let (matchResults, _) = try await database.records(matching: query, inZoneWith: zoneID)
            var recordIDsToDelete: [CKRecord.ID] = []
            
            for (_, result) in matchResults {
                if case .success(let record) = result {
                    recordIDsToDelete.append(record.recordID)
                }
            }
            
            for recordID in recordIDsToDelete {
                do {
                    try await database.deleteRecord(withID: recordID)
                    #if DEBUG
                    print("☁️ [CloudKit] Deleted record for item \(id)")
                    #endif
                } catch {
                    #if DEBUG
                    print("⚠️ [CloudKit] Failed to delete record: \(error.localizedDescription)")
                    #endif
                }
            }
        } catch {
            TelemetryService.shared.logCloudKitError(
                code: "DELETE_FAILED",
                message: "Item \(id): \(error.localizedDescription)"
            )
            throw error
        }
    }
    
    // MARK: - Zone Management
    
    /// Create custom zone if it doesn't exist
    private func createZoneIfNeeded() async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        
        do {
            _ = try await database.save(zone)
            #if DEBUG
            print("☁️ [CloudKit] Created zone: \(zoneID.zoneName)")
            #endif
        } catch let error as CKError {
            // Zone already exists is OK (various error codes depending on iOS version)
            if error.code == .serverRejectedRequest || error.code == .invalidArguments {
                return
            }
            // Check if error message indicates zone exists
            if error.localizedDescription.contains("already exists") || 
               error.localizedDescription.contains("duplicate") {
                return
            }
            throw error
        }
    }
}

// MARK: - Telemetry Extension

// MARK: - Telemetry Extension

extension TelemetryService {
    func logCloudKitError(code: String, message: String) {
        logError(
            domain: .cloudKit,
            code: code,
            message: message
        )
    }
}
