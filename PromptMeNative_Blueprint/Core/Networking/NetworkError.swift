import Foundation

enum NetworkError: LocalizedError {
    case malformedURL
    case missingAuthToken
    case missingAdminKey
    case unauthorized
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
        case .unauthorized:
            return "Session expired. Please log in again."
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
}
