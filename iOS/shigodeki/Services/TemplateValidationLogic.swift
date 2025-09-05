import Foundation

// MARK: - Template Validation Logic

class TemplateValidationLogic {
    
    static func validateBasicStructure(_ template: ProjectTemplate, 
                                      errors: inout [ValidationError], 
                                      warnings: inout [ValidationError]) {
        // Name validation
        if template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }
        
        // Phases validation
        if template.phases.isEmpty {
            errors.append(.emptyPhases)
        }
        
        // Category validation
        if !ProjectTemplate.Category.allCases.contains(template.category) {
            warnings.append(.invalidCategory(template.category.rawValue))
        }
    }
    
    static func validatePhases(_ phases: [PhaseTemplate], 
                              errors: inout [ValidationError], 
                              warnings: inout [ValidationError]) {
        let phaseOrders = phases.map { $0.order }
        let duplicateOrders = phaseOrders.duplicates()
        if !duplicateOrders.isEmpty {
            errors.append(.duplicatePhaseOrders(duplicateOrders))
        }
        
        let phaseTitles = phases.map { $0.name }
        let duplicateTitles = phaseTitles.duplicates()
        if !duplicateTitles.isEmpty {
            errors.append(.duplicatePhaseTitles(duplicateTitles))
        }
        
        // Check for empty phases
        for phase in phases {
            let totalTasks = phase.taskLists.reduce(0) { $0 + $1.tasks.count }
            if totalTasks == 0 {
                warnings.append(.emptyTasksInPhase(phase.name))
            }
        }
    }
    
    static func validateTasks(_ phases: [PhaseTemplate], 
                             errors: inout [ValidationError], 
                             warnings: inout [ValidationError]) {
        for phase in phases {
            for taskList in phase.taskLists {
                for (taskIndex, task) in taskList.tasks.enumerated() {
                    // Task title validation
                    if task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        errors.append(.emptyTaskTitle(phaseTitle: phase.name, taskIndex: taskIndex))
                    }
                    
                    // Estimated hours validation
                    if let hours = task.estimatedHours {
                        if hours < 0 || hours > 1000 {
                            warnings.append(.invalidEstimatedHours(task: task.title, hours: Double(hours)))
                        }
                    }
                    
                    // Priority validation
                    if !TaskPriority.allCases.contains(task.priority) {
                        warnings.append(.invalidPriority(task: task.title, priority: task.priority.rawValue))
                    }
                }
            }
        }
    }
    
    static func validateDependencies(_ phases: [PhaseTemplate], 
                                    errors: inout [ValidationError], 
                                    warnings: inout [ValidationError]) {
        // Build task name set for dependency validation
        var taskNames = Set<String>()
        var dependencyGraph: [String: [String]] = [:]
        
        for phase in phases {
            for taskList in phase.taskLists {
                for task in taskList.tasks {
                    taskNames.insert(task.title)
                    dependencyGraph[task.title] = task.dependencies
                }
            }
        }
        
        // Validate dependencies exist
        for phase in phases {
            for taskList in phase.taskLists {
                for task in taskList.tasks {
                    for dependency in task.dependencies {
                        if !taskNames.contains(dependency) {
                            errors.append(.invalidDependency(task: task.title, dependency: dependency))
                        }
                    }
                }
            }
        }
        
        // Check for circular dependencies
        if let cycle = TemplateValidationHelpers.findCircularDependency(in: dependencyGraph) {
            errors.append(.circularDependency(cycle))
        }
    }
}