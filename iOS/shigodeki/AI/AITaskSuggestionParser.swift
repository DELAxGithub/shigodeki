import Foundation

/// A helper struct for parsing AI-generated task suggestions from a JSON string.
struct AITaskSuggestionParser {
    
    /// Parses a JSON string to create an `AITaskSuggestion`.
    static func parse(from jsonString: String) throws -> AITaskParseResult {
        let cleanJSON = extractJSON(from: jsonString)

        guard let data = cleanJSON.data(using: .utf8) else {
            throw AITaskSuggestionParserError.invalidJSON
        }

        let decoder = JSONDecoder()

        if let modern = try? decoder.decode(ModernResponse.self, from: data) {
            guard let rawTasks = modern.tasks, rawTasks.isEmpty == false else {
                throw AITaskSuggestionParserError.missingTasks
            }

            let tasks = rawTasks.compactMap { taskData -> AITaskSuggestion.TaskSuggestion? in
                let title = taskData.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard title.isEmpty == false else { return nil }
                return AITaskSuggestion.TaskSuggestion(
                    title: title,
                    description: nil,
                    estimatedDuration: nil,
                    priority: AITaskPriority.from(taskData.priority),
                    tags: [],
                    subtasks: nil,
                    due: taskData.due?.trimmingCharacters(in: .whitespacesAndNewlines),
                    rationale: taskData.rationale?.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            guard tasks.isEmpty == false else {
                throw AITaskSuggestionParserError.missingTasks
            }

            let status: AITaskParseStatus = {
                if let project = modern.project,
                   let title = project.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                   title.isEmpty == false {
                    return .ok
                }
                return .missingProject
            }()

            let suggestion = AITaskSuggestion(
                projectTitle: modern.project?.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                localeLang: modern.project?.locale?.lang?.trimmingCharacters(in: .whitespacesAndNewlines),
                localeRegion: modern.project?.locale?.region?.trimmingCharacters(in: .whitespacesAndNewlines),
                tasks: tasks,
                phases: nil
            )

            return AITaskParseResult(suggestion: suggestion, status: status)
        }

        // Fallback: legacy response format
        if let legacy = try? decoder.decode(LegacyResponse.self, from: data) {
            guard legacy.tasks.isEmpty == false else {
                throw AITaskSuggestionParserError.missingTasks
            }

            let tasks = legacy.tasks.compactMap { taskData -> AITaskSuggestion.TaskSuggestion? in
                let title = taskData.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard title.isEmpty == false else { return nil }
                return AITaskSuggestion.TaskSuggestion(
                    title: title,
                    description: taskData.description.trimmingCharacters(in: .whitespacesAndNewlines),
                    estimatedDuration: taskData.estimatedDuration,
                    priority: AITaskPriority.from(taskData.priority) ?? .medium,
                    tags: taskData.tags,
                    subtasks: taskData.subtasks,
                    due: nil,
                    rationale: taskData.description.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            guard tasks.isEmpty == false else {
                throw AITaskSuggestionParserError.missingTasks
            }

            let phases = legacy.phases?.compactMap { phaseData -> AITaskSuggestion.PhaseSuggestion? in
                let phaseTasks = phaseData.tasks.compactMap { taskData -> AITaskSuggestion.TaskSuggestion? in
                    let title = taskData.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard title.isEmpty == false else { return nil }
                    return AITaskSuggestion.TaskSuggestion(
                        title: title,
                        description: taskData.description.trimmingCharacters(in: .whitespacesAndNewlines),
                        estimatedDuration: taskData.estimatedDuration,
                        priority: AITaskPriority.from(taskData.priority) ?? .medium,
                        tags: taskData.tags,
                        subtasks: taskData.subtasks,
                        due: nil,
                        rationale: taskData.description.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }

                guard phaseTasks.isEmpty == false else { return nil }

                return AITaskSuggestion.PhaseSuggestion(
                    name: phaseData.name,
                    description: phaseData.description,
                    tasks: phaseTasks
                )
            }

            let suggestion = AITaskSuggestion(
                projectTitle: nil,
                localeLang: nil,
                localeRegion: nil,
                tasks: tasks,
                phases: phases
            )

            return AITaskParseResult(suggestion: suggestion, status: .legacy)
        }

        throw AITaskSuggestionParserError.invalidJSON
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

private struct ModernResponse: Codable {
    struct Project: Codable {
        struct Locale: Codable { let lang: String?; let region: String? }
        let title: String?
        let locale: Locale?
    }

    struct Task: Codable {
        let title: String
        let due: String?
        let priority: String?
        let rationale: String?
    }

    let project: Project?
    let tasks: [Task]?
}

private struct LegacyResponse: Codable {
    struct Task: Codable {
        let title: String
        let description: String
        let estimatedDuration: String
        let priority: String
        let tags: [String]
        let subtasks: [String]?
    }

    struct Phase: Codable {
        let name: String
        let description: String
        let tasks: [Task]
    }

    let tasks: [Task]
    let phases: [Phase]?
}

enum AITaskSuggestionParserError: Error {
    case invalidJSON
    case missingTasks
}
