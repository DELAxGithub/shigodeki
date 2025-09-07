import Foundation

final class OpenAIClient: UniversalAIClient, AIClient {
    private let baseURL = "https://api.openai.com/v1"
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - UniversalAIClient Implementation
    
    func complete(_ request: AIRequest) async throws -> AIResponse {
        guard let apiKey = try? KeychainManager.shared.retrieveAPIKey(for: .openAI) else {
            throw AIClientError.apiKeyNotConfigured
        }
        
        var messages: [OpenAIMessage] = []
        
        // Add system message if provided
        if let system = request.system {
            messages.append(OpenAIMessage(role: "system", content: system))
        }
        
        // Add user message
        messages.append(OpenAIMessage(role: "user", content: request.user))
        
        let requestBody = OpenAIRequest(
            model: request.model,
            messages: messages,
            temperature: request.temperature ?? 0.7,
            maxTokens: request.maxTokens ?? 2000
        )
        
        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
            let openAIResponse = try await Task.detached {
                try JSONDecoder().decode(OpenAIResponse.self, from: data)
            }.value
            
            guard let content = openAIResponse.choices.first?.message.content else {
                throw AIClientError.invalidResponse
            }
            
            let usage = openAIResponse.usage.map { usage in
                AIUsage(
                    promptTokens: usage.promptTokens,
                    completionTokens: usage.completionTokens,
                    totalTokens: usage.totalTokens
                )
            }
            
            return AIResponse(text: content, usage: usage)
            
        } catch let error as AIClientError {
            throw error
        } catch {
            throw AIClientError.networkError(error)
        }
    }
    
    // MARK: - Legacy AIClient Implementation (using UniversalAIClient)
    
    func generateTaskSuggestions(for prompt: String) async throws -> AITaskSuggestion {
        // Use the new UniversalAIClient implementation
        let request = AIRequest(
            system: AIPromptTemplate.systemPrompt,
            user: prompt,
            temperature: 0.7,
            maxTokens: 2000
        )
        
        let response = try await complete(request)
        return try AITaskSuggestionParser.parse(from: response.text)
    }
}

// MARK: - Data Models

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

struct OpenAIUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}