import Foundation
import CloudKit

/// Persistent model for a single generated-prompt record.
///
/// Phase 2: Migrated from SwiftData @Model to Codable class with CloudKit support.
/// Uses Codable for JSON local persistence and CloudKit for cross-device sync.
final class PromptHistoryItem: Codable, Identifiable {
    
    // MARK: - Core Properties
    
    var id: UUID
    var createdAt: Date
    /// Stored as its `rawValue` string.
    var mode: PromptMode
    var input: String
    var professional: String
    var template: String
    var favorite: Bool
    var customName: String?
    
    // MARK: - CloudKit Sync Properties
    
    /// CloudKit record ID (nil if not yet synced)
    var recordID: CKRecord.ID?
    
    /// Last modification date (used for conflict resolution)
    var lastModified: Date
    
    /// Sync status flag
    var isSynced: Bool
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case mode
        case input
        case professional
        case template
        case favorite
        case customName
        case recordID
        case lastModified
        case isSynced
    }
    
    // MARK: - Init
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        mode: PromptMode,
        input: String,
        professional: String,
        template: String,
        favorite: Bool = false,
        customName: String? = nil,
        recordID: CKRecord.ID? = nil,
        lastModified: Date = Date(),
        isSynced: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.mode = mode
        self.input = input
        self.professional = professional
        self.template = template
        self.favorite = favorite
        self.customName = customName
        self.recordID = recordID
        self.lastModified = lastModified
        self.isSynced = isSynced
    }
    
    // MARK: - Codable
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(mode, forKey: .mode)
        try container.encode(input, forKey: .input)
        try container.encode(professional, forKey: .professional)
        try container.encode(template, forKey: .template)
        try container.encode(favorite, forKey: .favorite)
        try container.encode(customName, forKey: .customName)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(isSynced, forKey: .isSynced)
        
        // Encode recordID as string if present
        if let recordID = recordID {
            try container.encode(recordID.recordName, forKey: .recordID)
        }
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        mode = try container.decode(PromptMode.self, forKey: .mode)
        input = try container.decode(String.self, forKey: .input)
        professional = try container.decode(String.self, forKey: .professional)
        template = try container.decode(String.self, forKey: .template)
        favorite = try container.decode(Bool.self, forKey: .favorite)
        customName = try container.decodeIfPresent(String.self, forKey: .customName)
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
        isSynced = try container.decodeIfPresent(Bool.self, forKey: .isSynced) ?? false
        
        // Decode recordID if present
        if let recordName = try container.decodeIfPresent(String.self, forKey: .recordID) {
            recordID = CKRecord.ID(recordName: recordName)
        } else {
            recordID = nil
        }
    }
    
    // MARK: - CloudKit Conversion
    
    /// Convert to CloudKit record
    func toCKRecord() -> CKRecord {
        let record: CKRecord
        
        if let existingRecordID = recordID {
            record = CKRecord(recordType: "PromptHistoryItem", recordID: existingRecordID)
        } else {
            record = CKRecord(recordType: "PromptHistoryItem")
        }
        
        record["id"] = id.uuidString as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["mode"] = mode.rawValue as CKRecordValue
        record["input"] = input as CKRecordValue
        record["professional"] = professional as CKRecordValue
        record["template"] = template as CKRecordValue
        record["favorite"] = favorite as CKRecordValue
        record["lastModified"] = lastModified as CKRecordValue
        
        if let customName = customName {
            record["customName"] = customName as CKRecordValue
        }
        
        return record
    }
    
    /// Initialize from CloudKit record
    convenience init(from record: CKRecord) throws {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let createdAt = record["createdAt"] as? Date,
              let modeString = record["mode"] as? String,
              let mode = PromptMode(rawValue: modeString),
              let input = record["input"] as? String,
              let professional = record["professional"] as? String,
              let template = record["template"] as? String,
              let favorite = record["favorite"] as? Bool,
              let lastModified = record["lastModified"] as? Date else {
            throw CloudKitError.invalidRecord
        }
        
        let customName = record["customName"] as? String
        
        self.init(
            id: id,
            createdAt: createdAt,
            mode: mode,
            input: input,
            professional: professional,
            template: template,
            favorite: favorite,
            customName: customName,
            recordID: record.recordID,
            lastModified: lastModified,
            isSynced: true
        )
    }
    
    /// Update from CloudKit record (for conflict resolution)
    func update(from record: CKRecord) throws {
        guard let idString = record["id"] as? String,
              UUID(uuidString: idString) == id else {
            throw CloudKitError.recordMismatch
        }
        
        createdAt = record["createdAt"] as? Date ?? createdAt
        if let modeString = record["mode"] as? String,
           let newMode = PromptMode(rawValue: modeString) {
            mode = newMode
        }
        input = record["input"] as? String ?? input
        professional = record["professional"] as? String ?? professional
        template = record["template"] as? String ?? template
        favorite = record["favorite"] as? Bool ?? favorite
        customName = record["customName"] as? String ?? customName
        recordID = record.recordID
        isSynced = true
        // Don't update lastModified - use the local one for conflict resolution
    }
    
    /// Mark as modified locally
    func markModified() {
        lastModified = Date()
        isSynced = false
    }
}

// MARK: - CloudKit Errors

enum CloudKitError: Error {
    case invalidRecord
    case recordMismatch
    case accountNotAvailable
    case networkError
    case serverError(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidRecord:
            return "Invalid CloudKit record format"
        case .recordMismatch:
            return "Record ID mismatch during update"
        case .accountNotAvailable:
            return "iCloud account not available"
        case .networkError:
            return "Network error during CloudKit operation"
        case .serverError(let message):
            return "CloudKit server error: \(message)"
        }
    }
}
