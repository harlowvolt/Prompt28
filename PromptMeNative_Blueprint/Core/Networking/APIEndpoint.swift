import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
}

enum APIAuthRequirement {
    case none
    case bearer
    case admin
}

enum APIEndpoint {
    // MARK: Config
    case settings
    case promptsTrending

    // MARK: Admin
    case adminVerify(adminKey: String)
    case adminSettings
    case adminUpdateSettings(payload: [String: Any])
    case adminPrompts
    case adminUpdatePrompts(PromptCatalog)

    var method: HTTPMethod {
        switch self {
        case .settings, .promptsTrending, .adminSettings, .adminPrompts:
            return .get
        default:
            return .post
        }
    }

    var path: String {
        switch self {
        case .settings:
            return "/api/settings"
        case .promptsTrending:
            return "/prompts_trending.json"
        case .adminVerify:
            return "/api/admin/verify"
        case .adminSettings, .adminUpdateSettings:
            return "/api/admin/settings"
        case .adminPrompts, .adminUpdatePrompts:
            return "/api/admin/prompts"
        }
    }

    var auth: APIAuthRequirement {
        switch self {
        case .adminVerify, .adminSettings, .adminUpdateSettings, .adminPrompts, .adminUpdatePrompts:
            return .admin
        default:
            return .none
        }
    }

    func bodyData() throws -> Data? {
        switch self {
        case .adminVerify(let key):
            return try JSONSerialization.data(withJSONObject: ["adminKey": key])
        case .adminUpdateSettings(let payload):
            return try JSONSerialization.data(withJSONObject: payload)
        case .adminUpdatePrompts(let catalog):
            return try JSONEncoder().encode(catalog)
        default:
            return nil
        }
    }
}
