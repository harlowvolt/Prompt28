import Foundation

struct RequestBuilder {
    let baseURL: URL

    func build(
        endpoint: APIEndpoint,
        bearerToken: String?,
        adminKey: String?
    ) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 30

        if endpoint.method != .get {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        switch endpoint.auth {
        case .bearer:
            guard let bearerToken, !bearerToken.isEmpty else {
                throw NetworkError.missingAuthToken
            }
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        case .admin:
            guard let adminKey, !adminKey.isEmpty else {
                throw NetworkError.missingAdminKey
            }
            request.setValue(adminKey, forHTTPHeaderField: "X-Admin-Key")
        case .none:
            break
        }

        request.httpBody = try endpoint.bodyData()
        return request
    }
}
