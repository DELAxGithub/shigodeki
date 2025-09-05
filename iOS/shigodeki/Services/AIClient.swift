import Foundation

protocol AIClient {
    func generateTaskSuggestions(for prompt: String) async throws -> AITaskSuggestion
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