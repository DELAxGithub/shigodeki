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

// MARK: - OpenAI Client

final class OpenAIClient: AIClient {
    private let baseURL = "https://api.openai.com/v1"
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func generateTaskSuggestions(for prompt: String) async throws -> AITaskSuggestion {
        guard let apiKey = try? KeychainManager.shared.retrieveAPIKey(for: .openAI) else {
            throw AIClientError.apiKeyNotConfigured
        }
        
        let requestBody = OpenAIRequest(
            model: "gpt-3.5-turbo",
            messages: [
                OpenAIMessage(role: "system", content: systemPrompt),
                OpenAIMessage(role: "user", content: prompt)
            ],
            temperature: 0.7,
            maxTokens: 2000
        )
        
        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
            
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            
            guard let content = openAIResponse.choices.first?.message.content else {
                throw AIClientError.invalidResponse
            }
            
            return try parseTaskSuggestions(from: content)
            
        } catch let error as DecodingError {
            throw AIClientError.invalidJSON
        } catch let error as AIClientError {
            throw error
        } catch {
            throw AIClientError.networkError(error)
        }
    }
    
    private var systemPrompt: String {
        """
        You are a task management expert. Generate structured task suggestions based on user input.
        
        Return a JSON response with this exact structure:
        {
            "tasks": [
                {
                    "title": "Task title",
                    "description": "Detailed description",
                    "estimatedDuration": "e.g., 2 hours, 1 day, 30 minutes",
                    "priority": "low|medium|high|urgent",
                    "tags": ["tag1", "tag2"],
                    "subtasks": ["subtask1", "subtask2"] (optional)
                }
            ],
            "phases": [ (optional, for complex projects)
                {
                    "name": "Phase name",
                    "description": "Phase description",
                    "tasks": [task objects as above]
                }
            ]
        }
        
        Guidelines:
        - Break down complex projects into manageable tasks
        - Provide realistic time estimates
        - Include relevant tags for categorization
        - Use phases for projects with multiple stages
        - Keep task titles concise but descriptive
        - Ensure descriptions are actionable
        """
    }
}

// MARK: - Claude Client

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
                ClaudeMessage(role: "user", content: "\(systemPrompt)\n\nUser request: \(prompt)")
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
            
            return try parseTaskSuggestions(from: content)
            
        } catch let error as DecodingError {
            throw AIClientError.invalidJSON
        } catch let error as AIClientError {
            throw error
        } catch {
            throw AIClientError.networkError(error)
        }
    }
    
    private var systemPrompt: String {
        """
        You are a task management expert. Generate structured task suggestions based on user input.
        
        Return a JSON response with this exact structure:
        {
            "tasks": [
                {
                    "title": "Task title",
                    "description": "Detailed description",
                    "estimatedDuration": "e.g., 2 hours, 1 day, 30 minutes",
                    "priority": "low|medium|high|urgent",
                    "tags": ["tag1", "tag2"],
                    "subtasks": ["subtask1", "subtask2"] (optional)
                }
            ],
            "phases": [ (optional, for complex projects)
                {
                    "name": "Phase name",
                    "description": "Phase description",
                    "tasks": [task objects as above]
                }
            ]
        }
        
        Guidelines:
        - Break down complex projects into manageable tasks
        - Provide realistic time estimates
        - Include relevant tags for categorization
        - Use phases for projects with multiple stages
        - Keep task titles concise but descriptive
        - Ensure descriptions are actionable
        """
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
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

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

// MARK: - JSON Parsing Helper

private extension AIClient {
    func parseTaskSuggestions(from jsonString: String) throws -> AITaskSuggestion {
        // Extract JSON from response (in case there's additional text)
        let cleanJSON = extractJSON(from: jsonString)
        
        guard let data = cleanJSON.data(using: .utf8) else {
            throw AIClientError.invalidJSON
        }
        
        let decoder = JSONDecoder()
        
        do {
            let response = try decoder.decode(AITaskResponse.self, from: data)
            
            let tasks = response.tasks.map { taskData in
                AITaskSuggestion.TaskSuggestion(
                    title: taskData.title,
                    description: taskData.description,
                    estimatedDuration: taskData.estimatedDuration,
                    priority: AITaskPriority(rawValue: taskData.priority) ?? .medium,
                    tags: taskData.tags,
                    subtasks: taskData.subtasks
                )
            }
            
            let phases = response.phases?.map { phaseData in
                AITaskSuggestion.PhaseSuggestion(
                    name: phaseData.name,
                    description: phaseData.description,
                    tasks: phaseData.tasks.map { taskData in
                        AITaskSuggestion.TaskSuggestion(
                            title: taskData.title,
                            description: taskData.description,
                            estimatedDuration: taskData.estimatedDuration,
                            priority: AITaskPriority(rawValue: taskData.priority) ?? .medium,
                            tags: taskData.tags,
                            subtasks: taskData.subtasks
                        )
                    }
                )
            }
            
            return AITaskSuggestion(tasks: tasks, phases: phases)
            
        } catch {
            throw AIClientError.invalidJSON
        }
    }
    
    func extractJSON(from text: String) -> String {
        // Find JSON content between first { and last }
        guard let startIndex = text.firstIndex(of: "{"),
              let endIndex = text.lastIndex(of: "}") else {
            return text
        }
        
        return String(text[startIndex...endIndex])
    }
}

private struct AITaskResponse: Codable {
    let tasks: [TaskData]
    let phases: [PhaseData]?
}

private struct TaskData: Codable {
    let title: String
    let description: String
    let estimatedDuration: String
    let priority: String
    let tags: [String]
    let subtasks: [String]?
}

private struct PhaseData: Codable {
    let name: String
    let description: String
    let tasks: [TaskData]
}