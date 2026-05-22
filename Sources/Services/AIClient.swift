import Foundation

actor AIClient {
    static let shared = AIClient()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        session = URLSession(configuration: config)
    }

    func invokeLLM(prompt: String, fileURLs: [String]? = nil, responseJSONSchema: [String: AnyCodable]? = nil) async throws -> String {
        var body: [String: AnyCodable] = ["prompt": .string(prompt)]
        if let fileURLs {
            body["file_urls"] = .array(fileURLs.map { .string($0) })
        }
        if let responseJSONSchema {
            body["response_json_schema"] = .object(responseJSONSchema)
        }

        let request = try buildRequest(APIConstants.aiProxyURL, body: body)
        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)
            return String(data: data, encoding: .utf8) ?? ""
        } catch let error as URLError where error.code == .timedOut {
            throw ClientError.requestTimedOut
        }
    }

    private func buildRequest(_ urlString: String, body: some Encodable) throws -> URLRequest {
        guard let url = URL(string: urlString) else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(APIConstants.aiProxyClientID, forHTTPHeaderField: "X-ClearSpend-Client")
        request.httpBody = try encoder.encode(AnyEncodable(body))
        return request
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return
        case 400:
            let message = (try? decoder.decode(ErrorResponse.self, from: data))?.message
                ?? (try? decoder.decode(ErrorResponse.self, from: data))?.error
                ?? "Bad request"
            throw ClientError.validationFailed(message)
        case 401, 403:
            throw ClientError.unauthorized
        case 404:
            throw ClientError.notFound
        case 422:
            let message = (try? decoder.decode(ErrorResponse.self, from: data))?.message
                ?? (try? decoder.decode(ErrorResponse.self, from: data))?.error
                ?? "Validation failed"
            throw ClientError.validationFailed(message)
        case 408, 504:
            throw ClientError.requestTimedOut
        case 500...599:
            let message = (try? decoder.decode(ErrorResponse.self, from: data))?.message
                ?? (try? decoder.decode(ErrorResponse.self, from: data))?.error
            throw ClientError.serverError(http.statusCode, message)
        default:
            throw ClientError.httpError(http.statusCode)
        }
    }
}

enum ClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case validationFailed(String)
    case requestTimedOut
    case serverError(Int, String?)
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .invalidResponse: "Invalid response from server"
        case .unauthorized: "AI service is unavailable. Please try again."
        case .notFound: "Resource not found"
        case .validationFailed(let message): message
        case .requestTimedOut: "AI request timed out. Please try again."
        case .serverError(let code, let message): message ?? "Server error (\(code))"
        case .httpError(let code): "HTTP error (\(code))"
        }
    }
}

private struct ErrorResponse: Codable {
    let message: String?
    let error: String?
}

private struct AnyEncodable: Encodable {
    let value: any Encodable

    init(_ value: any Encodable) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}
