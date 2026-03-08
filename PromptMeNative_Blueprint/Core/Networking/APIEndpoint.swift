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
    case register(RegisterRequest)
    case login(LoginRequest)
    case googleAuth(GoogleAuthRequest)
    case appleAuth(AppleAuthRequest)

    case me
    case updatePlan(UpdatePlanRequest)
    case deleteUser
    case resetUsage
    case generate(GenerateRequest)

    case config
    case settings
    case promptsTrending

    case adminVerify(adminKey: String)
    case adminSettings
    case adminUpdateSettings(payload: [String: Any])
    case adminPrompts
    case adminUpdatePrompts(PromptCatalog)

    var method: HTTPMethod {
        switch self {
        case .me, .config, .settings, .promptsTrending, .adminSettings, .adminPrompts:
            return .get
        case .deleteUser:
            return .delete
        default:
            return .post
        }
    }

    var path: String {
        switch self {
        case .register:
            return "/api/auth/register"
        case .login:
            return "/api/auth/login"
        case .googleAuth:
            return "/api/auth/google"
        case .appleAuth:
            return "/api/auth/apple"
        case .me:
            return "/api/me"
        case .updatePlan:
            return "/api/update-plan"
        case .deleteUser:
            return "/api/user"
        case .resetUsage:
            return "/api/reset-usage"
        case .generate:
            return "/api/generate"
        case .config:
            return "/api/config"
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
        case .me, .updatePlan, .deleteUser, .resetUsage, .generate:
            return .bearer
        case .adminVerify, .adminSettings, .adminUpdateSettings, .adminPrompts, .adminUpdatePrompts:
            return .admin
        default:
            return .none
        }
    }

    func bodyData() throws -> Data? {
        switch self {
        case .register(let request):
            return try JSONEncoder().encode(request)
        case .login(let request):
            return try JSONEncoder().encode(request)
        case .googleAuth(let request):
            return try JSONEncoder().encode(request)
        case .appleAuth(let request):
            return try JSONEncoder().encode(request)
        case .updatePlan(let request):
            return try JSONEncoder().encode(request)
        case .generate(let request):
            return try JSONEncoder().encode(request)
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
