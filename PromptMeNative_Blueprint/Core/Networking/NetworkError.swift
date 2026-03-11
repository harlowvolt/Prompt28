import Foundation

enum NetworkError: LocalizedError {
    case malformedURL
    case missingAuthToken
    case missingAdminKey
    case unauthorized(message: String, sessionExpired: Bool)
    case forbidden(message: String)
    case notFound(message: String)
    case rateLimited(message: String)
    case server(message: String)
    case decoding
    case transport(message: String)

    var errorDescription: String? {
        switch self {
        case .malformedURL:
            return "Invalid server URL."
        case .missingAuthToken:
            return "Authentication token is missing."
        case .missingAdminKey:
            return "Admin key is missing."
        case .unauthorized(let message, _):
            return message
        case .forbidden(let message):
            return message
        case .notFound(let message):
            return message
        case .rateLimited(let message):
            return message
        case .server(let message):
            return message
        case .decoding:
            return "Failed to decode server response."
        case .transport(let message):
            return message
        }
    }

    var isSessionExpired: Bool {
        switch self {
        case .unauthorized(_, let sessionExpired):
            return sessionExpired
        default:
            return false
        }
    }
}
