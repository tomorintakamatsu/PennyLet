import Foundation

actor Base44Client {
    static let shared = Base44Client()

    private let session: URLSession
    private let baseURL: String
    private var token: String?
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
        baseURL = APIConstants.baseURL
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    func setToken(_ token: String?) {
        self.token = token
    }

    // MARK: - Entity CRUD

    func list<T: Codable & Sendable>(entity: String, sort: String? = nil, limit: Int? = nil) async throws -> [T] {
        var url = "\(baseURL)\(APIConstants.dataPath)/\(entity)"
        var queryItems: [String] = []
        if let sort { queryItems.append("sort=\(sort)") }
        if let limit { queryItems.append("limit=\(limit)") }
        if !queryItems.isEmpty {
            url += "?" + queryItems.joined(separator: "&")
        }
        let data: [T] = try await get(url)
        return data
    }

    func create<T: Codable & Sendable>(entity: String, data: some Encodable & Sendable) async throws -> T {
        let url = "\(baseURL)\(APIConstants.dataPath)/\(entity)"
        return try await post(url, body: data)
    }

    func update<T: Codable & Sendable>(entity: String, id: String, data: some Encodable & Sendable) async throws -> T {
        let url = "\(baseURL)\(APIConstants.dataPath)/\(entity)/\(id)"
        return try await put(url, body: data)
    }

    func delete(entity: String, id: String) async throws {
        let url = "\(baseURL)\(APIConstants.dataPath)/\(entity)/\(id)"
        try await deleteRequest(url)
    }

    func getById<T: Codable & Sendable>(entity: String, id: String) async throws -> T {
        let url = "\(baseURL)\(APIConstants.dataPath)/\(entity)/\(id)"
        return try await get(url)
    }

    // MARK: - Auth

    struct AuthResponse: Codable {
        let accessToken: String?
        let user: User?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case user
        }
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let url = "\(baseURL)/auth/login"
        let body = ["email": email, "password": password]
        let response: AuthResponse = try await post(url, body: body)
        token = response.accessToken
        return response
    }

    func register(email: String, password: String) async throws -> AuthResponse {
        let url = "\(baseURL)/auth/register"
        let body = ["email": email, "password": password]
        let response: AuthResponse = try await post(url, body: body)
        token = response.accessToken
        return response
    }

    func verifyOtp(email: String, otpCode: String) async throws -> AuthResponse {
        let url = "\(baseURL)/auth/verify-otp"
        let body = ["email": email, "otp_code": otpCode]
        let response: AuthResponse = try await post(url, body: body)
        token = response.accessToken
        return response
    }

    func resendOtp(email: String) async throws {
        let url = "\(baseURL)/auth/resend-otp"
        let body = ["email": email]
        let request = try buildRequest(url, method: "POST", body: body)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }

    func me() async throws -> User {
        let url = "\(baseURL)\(APIConstants.dataPath)/User/me"
        return try await get(url)
    }

    func updateMe(data: [String: AnyCodable]) async throws -> User {
        let url = "\(baseURL)\(APIConstants.dataPath)/User/me"
        return try await put(url, body: data)
    }

    // MARK: - LLM

    func invokeLLM(prompt: String, fileURLs: [String]? = nil, responseJSONSchema: [String: AnyCodable]? = nil) async throws -> String {
        var body: [String: AnyCodable] = ["prompt": .string(prompt)]
        if let fileURLs { body["file_urls"] = .array(fileURLs.map { .string($0) }) }
        if let schema = responseJSONSchema { body["response_json_schema"] = .object(schema) }
        let url = "\(baseURL)/integration-endpoints/Core/InvokeLLM"
        let data = try await postRaw(url, body: body)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - File Upload

    struct FileUploadResponse: Codable {
        let url: String
        let path: String?
    }

    func uploadFile(file: Data, filename: String, mimeType: String) async throws -> FileUploadResponse {
        let urlString = "\(baseURL)/integration-endpoints/Core/UploadFile"
        guard let url = URL(string: urlString) else { throw ClientError.invalidURL }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(APIConstants.appId, forHTTPHeaderField: "X-App-Id")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(file)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try decoder.decode(FileUploadResponse.self, from: data)
    }

    // MARK: - Functions

    func invokeFunction(name: String, payload: some Encodable & Sendable) async throws -> Data {
        let url = "\(baseURL)\(APIConstants.functionsPath)/\(name)"
        return try await postRaw(url, body: payload)
    }

    // MARK: - HTTP Methods

    private func get<T: Codable>(_ urlString: String) async throws -> T {
        let request = try buildRequest(urlString, method: "GET")
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Codable, B: Encodable>(_ urlString: String, body: B) async throws -> T {
        let request = try buildRequest(urlString, method: "POST", body: body)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func put<T: Codable, B: Encodable>(_ urlString: String, body: B) async throws -> T {
        let request = try buildRequest(urlString, method: "PUT", body: body)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func deleteRequest(_ urlString: String) async throws {
        let request = try buildRequest(urlString, method: "DELETE")
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }

    private func postRaw<B: Encodable>(_ urlString: String, body: B) async throws -> Data {
        let request = try buildRequest(urlString, method: "POST", body: body)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return data
    }

    // MARK: - Helpers

    private func buildRequest(_ urlString: String, method: String, body: (any Encodable)? = nil) throws -> URLRequest {
        guard let url = URL(string: urlString) else {
            throw ClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(APIConstants.appId, forHTTPHeaderField: "X-App-Id")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }
        return request
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        switch http.statusCode {
        case 200...299: return
        case 400:
            let message = (try? decoder.decode(ErrorResponse.self, from: data))?.message ?? "Bad request"
            throw ClientError.validationFailed(message)
        case 401: throw ClientError.unauthorized
        case 404: throw ClientError.notFound
        case 422:
            let message = (try? decoder.decode(ErrorResponse.self, from: data))?.message ?? "Validation failed"
            throw ClientError.validationFailed(message)
        case 500...599:
            throw ClientError.serverError(http.statusCode)
        default:
            throw ClientError.httpError(http.statusCode)
        }
    }
}

// MARK: - Error Types

enum ClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case validationFailed(String)
    case serverError(Int)
    case httpError(Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .invalidResponse: "Invalid response from server"
        case .unauthorized: "Session expired. Please sign in again."
        case .notFound: "Resource not found"
        case .validationFailed(let msg): msg
        case .serverError(let code): "Server error (\(code))"
        case .httpError(let code): "HTTP error (\(code))"
        case .decodingError(let msg): "Data error: \(msg)"
        }
    }
}

private struct ErrorResponse: Codable {
    let message: String?
}

private struct AnyEncodable: Encodable {
    let value: any Encodable
    init(_ value: any Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}
