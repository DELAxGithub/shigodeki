import Foundation

// MARK: - Validation Helper Methods

class TemplateValidationHelpers {
    
    static func findCircularDependency(in graph: [String: [String]]) -> [String]? {
        var visiting = Set<String>()
        var visited = Set<String>()
        
        for node in graph.keys {
            if !visited.contains(node) {
                if let cycle = dfsForCycle(node: node, graph: graph, visiting: &visiting, visited: &visited) {
                    return cycle
                }
            }
        }
        return nil
    }
    
    private static func dfsForCycle(node: String, graph: [String: [String]], 
                                   visiting: inout Set<String>, visited: inout Set<String>) -> [String]? {
        if visiting.contains(node) {
            return [node] // Found cycle
        }
        
        if visited.contains(node) {
            return nil
        }
        
        visiting.insert(node)
        
        if let neighbors = graph[node] {
            for neighbor in neighbors {
                if let cycle = dfsForCycle(node: neighbor, graph: graph, visiting: &visiting, visited: &visited) {
                    if cycle.first == node {
                        return cycle // Complete cycle found
                    } else {
                        return [node] + cycle // Continue building cycle path
                    }
                }
            }
        }
        
        visiting.remove(node)
        visited.insert(node)
        return nil
    }
    
    static func convertLegacyForValidation(_ legacy: LegacyJSONTemplate) throws -> ProjectTemplate {
        // Create a basic ProjectTemplate from legacy format
        var phases: [PhaseTemplate] = []
        
        if let legacyPhases = legacy.phases {
            for (index, legacyPhase) in legacyPhases.enumerated() {
                var phase = PhaseTemplate(
                    name: legacyPhase.name ?? "Phase \(index + 1)",
                    description: legacyPhase.description,
                    order: index
                )
                
                // Convert legacy tasks if they exist
                if let legacyTasks = legacyPhase.tasks {
                    var taskLists: [TaskListTemplate] = []
                    let defaultList = TaskListTemplate(name: "Tasks", color: .blue, order: 0)
                    
                    var tasks: [TaskTemplate] = []
                    for (taskIndex, legacyTask) in legacyTasks.enumerated() {
                        let task = TaskTemplate(
                            title: legacyTask.name ?? "Task \(taskIndex + 1)",
                            description: legacyTask.description,
                            estimatedHours: legacyTask.estimatedHours,
                            priority: TaskPriority(rawValue: legacyTask.priority ?? "medium") ?? .medium,
                            dependencies: legacyTask.dependencies ?? [],
                            order: taskIndex
                        )
                        tasks.append(task)
                    }
                    
                    var taskList = defaultList
                    taskList.tasks = tasks
                    taskLists.append(taskList)
                    phase.taskLists = taskLists
                }
                
                phases.append(phase)
            }
        }
        
        return ProjectTemplate(
            name: legacy.name ?? "Untitled Template",
            description: legacy.description,
            category: ProjectTemplate.Category(rawValue: legacy.category ?? "other") ?? .other,
            phases: phases,
            version: legacy.version ?? "1.0",
            tags: legacy.tags ?? [],
            author: legacy.author,
            estimatedDuration: legacy.estimatedDuration,
            difficulty: ProjectTemplate.Difficulty(rawValue: legacy.difficulty ?? "medium") ?? .medium,
            targetAudience: ProjectTemplate.TargetAudience(rawValue: legacy.targetAudience ?? "general") ?? .general,
            requiredSkills: legacy.requiredSkills ?? [],
            tools: legacy.tools ?? []
        )
    }
}

// MARK: - Array Extensions

extension Array where Element: Hashable {
    func duplicates() -> [Element] {
        var seen = Set<Element>()
        var duplicates = Set<Element>()
        
        for element in self {
            if seen.contains(element) {
                duplicates.insert(element)
            } else {
                seen.insert(element)
            }
        }
        
        return Array(duplicates)
    }
}

// MARK: - Legacy JSON Support

struct LegacyJSONTemplate: Codable {
    let name: String?
    let description: String?
    let category: String?
    let version: String?
    let phases: [LegacyPhase]?
    let tags: [String]?
    let author: String?
    let estimatedDuration: String?
    let difficulty: String?
    let targetAudience: String?
    let requiredSkills: [String]?
    let tools: [String]?
}

struct LegacyPhase: Codable {
    let name: String?
    let description: String?
    let tasks: [LegacyTask]?
}

struct LegacyTask: Codable {
    let name: String?
    let description: String?
    let estimatedHours: Int?
    let priority: String?
    let dependencies: [String]?
}