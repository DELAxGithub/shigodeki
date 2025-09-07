import Foundation

// MARK: - Legacy AIClient (preserved for compatibility)

protocol AIClient {
    func generateTaskSuggestions(for prompt: String) async throws -> AITaskSuggestion
}

// MARK: - Universal AI Client (new stable boundary)

/// Universal AI client protocol supporting both structured and unstructured generation
protocol UniversalAIClient {
    func complete(_ request: AIRequest) async throws -> AIResponse
}

/// Request structure for universal AI operations
struct AIRequest {
    let model: String
    let system: String?
    let user: String
    let jsonSchema: Data? // JSON mode for structured output, nil for text
    let temperature: Double?
    let maxTokens: Int?
    let tools: [AITool]?
    
    init(
        model: String = "gpt-3.5-turbo",
        system: String? = nil,
        user: String,
        jsonSchema: Data? = nil,
        temperature: Double? = 0.7,
        maxTokens: Int? = 2000,
        tools: [AITool]? = nil
    ) {
        self.model = model
        self.system = system
        self.user = user
        self.jsonSchema = jsonSchema
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.tools = tools
    }
}

/// Response structure for universal AI operations
struct AIResponse {
    let text: String
    let raw: String
    let usage: AIUsage?
    
    init(text: String, raw: String? = nil, usage: AIUsage? = nil) {
        self.text = text
        self.raw = raw ?? text
        self.usage = usage
    }
}

/// AI tool definition for function calling
struct AITool {
    let name: String
    let description: String
    let parameters: [String: Any]
}

/// Usage statistics for AI requests
struct AIUsage {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

// MARK: - Compatibility Layer (Strangler Pattern)

/// Compatibility adapter that implements legacy AIClient using UniversalAIClient
final class CompatAIClient: AIClient {
    private let universalClient: UniversalAIClient
    
    init(universalClient: UniversalAIClient) {
        self.universalClient = universalClient
    }
    
    func generateTaskSuggestions(for prompt: String) async throws -> AITaskSuggestion {
        // Create request with task-specific system prompt
        let request = AIRequest(
            system: AIPromptTemplate.systemPrompt,
            user: prompt,
            jsonSchema: nil, // Will be handled by system prompt JSON instruction
            temperature: 0.7,
            maxTokens: 2000
        )
        
        do {
            let response = try await universalClient.complete(request)
            
            // Parse the JSON response into AITaskSuggestion
            return try AITaskSuggestionParser.parse(from: response.text)
            
        } catch let error as AIClientError {
            throw error
        } catch {
            throw AIClientError.networkError(error)
        }
    }
}

// MARK: - Universal Text Generation Helper

/// Helper extension for common text generation operations
extension UniversalAIClient {
    
    /// Generate plain text without structured output
    func generateText(
        prompt: String,
        system: String? = nil,
        temperature: Double = 0.7,
        maxTokens: Int = 2000
    ) async throws -> String {
        let request = AIRequest(
            system: system,
            user: prompt,
            jsonSchema: nil,
            temperature: temperature,
            maxTokens: maxTokens
        )
        
        let response = try await complete(request)
        return response.text
    }
    
    /// Generate structured JSON output
    func generateStructuredOutput<T: Codable>(
        prompt: String,
        system: String? = nil,
        outputType: T.Type,
        temperature: Double = 0.3
    ) async throws -> T {
        // TODO: Implement JSON schema generation for better structured output
        let request = AIRequest(
            system: system,
            user: prompt,
            jsonSchema: nil, // Future: generate schema from T.Type
            temperature: temperature,
            maxTokens: 2000
        )
        
        let response = try await complete(request)
        
        guard let data = response.text.data(using: .utf8) else {
            throw AIClientError.invalidJSON
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AIClientError.invalidJSON
        }
    }
}

struct AITaskSuggestion {
    let tasks: [TaskSuggestion]
    let phases: [PhaseSuggestion]?
    
    struct TaskSuggestion {
        let title: String
        let description: String
        let estimatedDuration: String
        let priority: AITaskPriority
        let tags: [String]
        let subtasks: [String]?
    }
    
    struct PhaseSuggestion {
        let name: String
        let description: String
        let tasks: [TaskSuggestion]
    }
}

enum AITaskPriority: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
}

enum AIClientError: Error, LocalizedError {
    case invalidResponse
    case networkError(Error)
    case apiKeyNotConfigured
    case invalidJSON
    case rateLimitExceeded
    case quotaExceeded
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from AI service"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiKeyNotConfigured:
            return "API key not configured"
        case .invalidJSON:
            return "Invalid JSON response"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .quotaExceeded:
            return "API quota exceeded"
        case .serviceUnavailable:
            return "AI service temporarily unavailable"
        }
    }
}