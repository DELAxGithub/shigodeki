import Foundation

final class ClaudeClient: UniversalAIClient, AIClient {
    private let baseURL = "https://api.anthropic.com/v1"
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - UniversalAIClient Implementation
    
    func complete(_ request: AIRequest) async throws -> AIResponse {
        guard let apiKey = try? KeychainManager.shared.retrieveAPIKey(for: .claude) else {
            throw AIClientError.apiKeyNotConfigured
        }
        
        var messageContent = request.user
        
        // Claude API doesn't have separate system role in messages
        // Instead, we prepend system prompt to user message
        if let system = request.system {
            messageContent = "\(system)\n\nUser request: \(request.user)"
        }
        
        let requestBody = ClaudeRequest(
            model: request.model == "gpt-3.5-turbo" ? "claude-3-haiku-20240307" : request.model,
            maxTokens: request.maxTokens ?? 2000,
            messages: [
                ClaudeMessage(role: "user", content: messageContent)
            ]
        )
        
        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/messages")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
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
            
            // Move JSON decoding to background thread to avoid blocking MainActor
            let claudeResponse = try await Task.detached {
                try JSONDecoder().decode(ClaudeResponse.self, from: data)
            }.value
            
            guard let content = claudeResponse.content.first?.text else {
                throw AIClientError.invalidResponse
            }
            
            // Claude API doesn't provide usage statistics in the same format
            // We'll leave usage as nil for now
            return AIResponse(text: content, usage: nil)
            
        } catch let error as AIClientError {
            throw error
        } catch {
            throw AIClientError.networkError(error)
        }
    }
    
    // MARK: - Legacy AIClient Implementation (using UniversalAIClient)
    
    func generateTaskSuggestions(for prompt: String) async throws -> AITaskParseResult {
        // Use the new UniversalAIClient implementation
        let request = AIRequest(
            model: "claude-3-haiku-20240307",
            system: AIPromptTemplate.systemPrompt,
            user: prompt,
            temperature: 0.7,
            maxTokens: 2000
        )
        
        do {
            let response = try await complete(request)
            return try AITaskSuggestionParser.parse(from: response.text)
        } catch let parserError as AITaskSuggestionParserError {
            switch parserError {
            case .invalidJSON, .missingTasks:
                throw AIClientError.invalidJSON
            }
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
