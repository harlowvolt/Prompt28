import Foundation
import SwiftData

/// Persistent model for a single generated-prompt record.
///
/// Changed from `struct` to `@Model class` in Phase 4.2 to enable
/// SwiftData offline-first persistence. `PromptMode` is a `String`-backed
/// `Codable` enum and is stored directly as a SwiftData composite attribute.
@Model
final class PromptHistoryItem {

    @Attribute(.unique) var id: UUID = UUID()
    var createdAt: Date = Date()
    /// Stored as its `rawValue` string via SwiftData's Codable attribute support.
    var mode: PromptMode = PromptMode.ai
    var input: String = ""
    var professional: String = ""
    var template: String = ""
    var favorite: Bool = false
    var customName: String? = nil

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        mode: PromptMode,
        input: String,
        professional: String,
        template: String,
        favorite: Bool = false,
        customName: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.mode = mode
        self.input = input
        self.professional = professional
        self.template = template
        self.favorite = favorite
        self.customName = customName
    }
}
