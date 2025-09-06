import Foundation

/// Service responsible for converting AI suggestions to app task objects
struct AITaskConverter {
    
    /// Convert AI suggestions to Task objects for the app
    static func convertSuggestionsToTasks(_ suggestions: AITaskSuggestion, for project: Project) -> [ShigodekiTask] {
        var tasks: [ShigodekiTask] = []
        
        // If we have phases, create tasks within phases
        if let phases = suggestions.phases {
            for (phaseIndex, phase) in phases.enumerated() {
                for (taskIndex, taskSuggestion) in phase.tasks.enumerated() {
                    let task = createTask(
                        from: taskSuggestion,
                        project: project,
                        phaseIndex: phaseIndex,
                        taskIndex: taskIndex,
                        phaseName: phase.name
                    )
                    tasks.append(task)
                }
            }
        } else {
            // Create tasks directly
            for (index, taskSuggestion) in suggestions.tasks.enumerated() {
                let task = createTask(
                    from: taskSuggestion,
                    project: project,
                    phaseIndex: nil as Int?,
                    taskIndex: index,
                    phaseName: nil as String?
                )
                tasks.append(task)
            }
        }
        
        return tasks
    }
    
    private static func createTask(
        from suggestion: AITaskSuggestion.TaskSuggestion,
        project: Project,
        phaseIndex: Int?,
        taskIndex: Int,
        phaseName: String?
    ) -> ShigodekiTask {
        
        // We need to create a task with the proper ShigodekiTask initializer
        // For now, use placeholder values since we'd need proper IDs
        let task = ShigodekiTask(
            title: suggestion.title,
            description: suggestion.description,
            assignedTo: nil,
            createdBy: project.ownerId,
            dueDate: nil,
            priority: mapPriority(suggestion.priority),
            listId: "temp-list-id", // Would need proper list creation
            phaseId: "temp-phase-id", // Would need proper phase creation
            projectId: project.id ?? "temp-project-id",
            order: taskIndex
        )
        
        // Set phase if available
        if let phaseIndex = phaseIndex, let phaseName = phaseName {
            // This would need to be handled by the calling code
            // as we'd need to create/reference phases
        }
        
        return task
    }
    
    private static func mapPriority(_ aiPriority: AITaskPriority) -> TaskPriority {
        switch aiPriority {
        case .low:
            return .low
        case .medium:
            return .medium
        case .high:
            return .high
        case .urgent:
            return .high // Map urgent to high as our app only has 3 levels
        }
    }
    
    static func parseEstimatedDuration(_ duration: String) -> TimeInterval? {
        let lowercased = duration.lowercased()
        
        // Simple duration parsing - could be enhanced
        if lowercased.contains("minute") {
            let numbers = lowercased.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            if let minutes = numbers.first {
                return TimeInterval(minutes * 60)
            }
        } else if lowercased.contains("hour") {
            let numbers = lowercased.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Double($0) }
            if let hours = numbers.first {
                return TimeInterval(hours * 3600)
            }
        } else if lowercased.contains("day") {
            let numbers = lowercased.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            if let days = numbers.first {
                return TimeInterval(days * 86400) // 24 hours
            }
        }
        
        return nil
    }
}