import Foundation

final class GeminiClient: UniversalAIClient, AIClient {
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - UniversalAIClient Implementation
    
    func complete(_ request: AIRequest) async throws -> AIResponse {
        guard let apiKey = try? KeychainManager.shared.retrieveAPIKey(for: .gemini) else {
            throw AIClientError.apiKeyNotConfigured
        }
        
        // Combine system and user prompts for Gemini
        var fullPrompt = request.user
        if let system = request.system {
            fullPrompt = "\(system)\n\n\(request.user)"
        }
        
        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart(text: fullPrompt)
                    ]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: request.temperature ?? 0.7,
                maxOutputTokens: request.maxTokens ?? 2000
            )
        )
        
        // Construct URL with API key
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw AIClientError.invalidResponse
        }
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            throw AIClientError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw AIClientError.invalidJSON
        }
        
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
            let geminiResponse = try await Task.detached {
                try JSONDecoder().decode(GeminiResponse.self, from: data)
            }.value
            
            guard let candidate = geminiResponse.candidates.first,
                  let part = candidate.content.parts.first else {
                throw AIClientError.invalidResponse
            }
            
            // Gemini API doesn't provide detailed usage statistics
            // We'll leave usage as nil for now
            return AIResponse(text: part.text, usage: nil)
            
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
            model: "gemini-pro",
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

private struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String
}

private struct GeminiGenerationConfig: Codable {
    let temperature: Double
    let maxOutputTokens: Int
}

private struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Codable {
    let content: GeminiContent
}