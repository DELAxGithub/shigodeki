import Foundation

final class ClaudeClient: AIClient {
    private let baseURL = "https://api.anthropic.com/v1"
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func generateTaskSuggestions(for prompt: String) async throws -> AITaskSuggestion {
        guard let apiKey = try? KeychainManager.shared.retrieveAPIKey(for: .claude) else {
            throw AIClientError.apiKeyNotConfigured
        }
        
        let requestBody = ClaudeRequest(
            model: "claude-3-haiku-20240307",
            maxTokens: 2000,
            messages: [
                ClaudeMessage(role: "user", content: "\(AIPromptTemplate.systemPrompt)\n\nUser request: \(prompt)")
            ]
        )
        
        var request = URLRequest(url: URL(string: "\(baseURL)/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    break
                case 401:
                    throw AIClientError.apiKeyNotConfigured
                case 429:
                    throw AIClientError.rateLimitExceeded
                case 402:
                    throw AIClientError.quotaExceeded
                case 503:
                    throw AIClientError.serviceUnavailable
                default:
                    throw AIClientError.invalidResponse
                }
            }
            
            let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            
            guard let content = claudeResponse.content.first?.text else {
                throw AIClientError.invalidResponse
            }
            
            return try AITaskSuggestionParser.parse(from: content)
            
        } catch let error as AIClientError {
            throw error
        } catch {
            throw AIClientError.networkError(error)
        }
    }
}

// MARK: - Data Models

struct ClaudeRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]
    
    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxTokens = "max_tokens"
    }
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeResponse: Codable {
    let content: [ClaudeContent]
}

struct ClaudeContent: Codable {
    let text: String
}