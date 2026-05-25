import Foundation

enum AIModelTier: String, Codable, Sendable {
    case standard
    case pro
}

actor AIClient {
    static let shared = AIClient()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 240
        config.waitsForConnectivity = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        session = URLSession(configuration: config)
    }

    func invokeLLM(
        prompt: String,
        fileURLs: [String]? = nil,
        responseJSONSchema: [String: AnyCodable]? = nil,
        modelTier: AIModelTier = .standard
    ) async throws -> String {
        let tiers: [AIModelTier] = modelTier == .pro ? [.pro, .standard] : [.standard]
        var lastError: Error?

        for tier in tiers {
            do {
                let body = requestBody(
                    prompt: prompt,
                    fileURLs: fileURLs,
                    responseJSONSchema: responseJSONSchema,
                    modelTier: tier
                )
                let request = try buildRequest(APIConstants.aiProxyURL, body: body, timeout: timeout(for: tier))
                return try await perform(request, retryCount: tier == .standard ? 1 : 0)
            } catch {
                lastError = error
                guard tier == .pro, isRetryable(error) else {
                    throw mappedError(error)
                }
            }
        }

        throw mappedError(lastError ?? ClientError.requestTimedOut)
    }

    private func requestBody(
        prompt: String,
        fileURLs: [String]?,
        responseJSONSchema: [String: AnyCodable]?,
        modelTier: AIModelTier
    ) -> [String: AnyCodable] {
        var body: [String: AnyCodable] = [
            "prompt": .string(prompt),
            "model_tier": .string(modelTier.rawValue),
        ]
        if let fileURLs {
            body["file_urls"] = .array(fileURLs.map { .string($0) })
        }
        if let responseJSONSchema {
            body["response_json_schema"] = .object(responseJSONSchema)
        }
        return body
    }

    private func perform(_ request: URLRequest, retryCount: Int) async throws -> String {
        var lastError: Error?
        let attempts = retryCount + 1

        for attempt in 0..<attempts {
            do {
                let (data, response) = try await session.data(for: request)
                try validateResponse(response, data: data)
                return String(data: data, encoding: .utf8) ?? ""
            } catch {
                lastError = error
                guard attempt == 0, isRetryable(error) else {
                    throw mappedError(error)
                }
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
        }

        throw mappedError(lastError ?? ClientError.requestTimedOut)
    }

    private func timeout(for tier: AIModelTier) -> TimeInterval {
        tier == .pro ? 55 : 120
    }

    private func buildRequest(_ urlString: String, body: some Encodable, timeout: TimeInterval) throws -> URLRequest {
        guard let url = URL(string: urlString) else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(APIConstants.aiProxyClientID, forHTTPHeaderField: "X-ClearSpend-Client")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-Id")
        request.httpBody = try encoder.encode(AnyEncodable(body))
        return request
    }

    private func isRetryable(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost,
                    .dnsLookupFailed, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }

        if let clientError = error as? ClientError {
            switch clientError {
            case .requestTimedOut:
                return true
            case .serverError(let code, _):
                return code == 502 || code == 503 || code == 504
            default:
                return false
            }
        }

        return false
    }

    private func mappedError(_ error: Error) -> Error {
        guard let urlError = error as? URLError else {
            return error
        }

        switch urlError.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost,
                .dnsLookupFailed, .notConnectedToInternet:
            return ClientError.requestTimedOut
        default:
            return error
        }
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
        case .serverError: "AI service is unavailable. Please try again."
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
