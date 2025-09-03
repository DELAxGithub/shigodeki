import Foundation

/// A helper struct for parsing AI-generated task suggestions from a JSON string.
struct AITaskSuggestionParser {
    
    /// Parses a JSON string to create an `AITaskSuggestion`.
    static func parse(from jsonString: String) throws -> AITaskSuggestion {
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
            
        } catch is DecodingError {
            throw AIClientError.invalidJSON
        }
    }
    
    /// Extracts a JSON object from a string that might contain surrounding text.
    private static func extractJSON(from text: String) -> String {
        guard let startIndex = text.firstIndex(of: "{"),
              let endIndex = text.lastIndex(of: "}") else {
            return text
        }
        return String(text[startIndex...endIndex])
    }
}

// MARK: - Private Helper Models for Decoding

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