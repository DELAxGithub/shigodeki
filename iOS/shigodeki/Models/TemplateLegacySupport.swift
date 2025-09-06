//
//  TemplateLegacySupport.swift
//  shigodeki
//
//  Extracted from ProjectTemplate.swift for CLAUDE.md compliance
//  Legacy JSON template format support ("steps" format like tsurutsu-template.json)
//

import Foundation

struct LegacyJSONTemplate: Codable {
    let name: String
    let description: String?
    let goal: String?
    let category: String?
    let version: String?
    let steps: [LegacyStep]
    let metadata: LegacyMetadata?
    
    struct LegacyStep: Codable {
        let title: String
        let description: String?
        let order: Int
        let prerequisites: [String]?
        let templateReference: String?
        let estimatedDuration: String?
        let tasks: [LegacyTask]
    }
    
    struct LegacyTask: Codable {
        let title: String
        let description: String?
        let priority: String?
        let estimatedDuration: String?
        let deadline: String?
        let tags: [String]?
        let templateLinks: [String]?
        let isOptional: Bool?
    }
    
    struct LegacyMetadata: Codable {
        let author: String?
        let createdAt: String?
        let estimatedDuration: String?
        let difficulty: String?
        let tags: [String]?
    }
}

// MARK: - Legacy to Modern Conversion

extension ProjectTemplate {
    init?(from legacy: LegacyJSONTemplate) {
        guard !legacy.name.isEmpty else { return nil }
        
        let category: TemplateCategory
        if let categoryString = legacy.category {
            category = TemplateCategory(rawValue: categoryString) ?? .other
        } else {
            category = .other
        }
        
        let difficulty: TemplateDifficulty
        if let difficultyString = legacy.metadata?.difficulty {
            difficulty = TemplateDifficulty(rawValue: difficultyString) ?? .intermediate
        } else {
            difficulty = .intermediate
        }
        
        let phases = legacy.steps.map { step in
            let tasks = step.tasks.map { task in
                let priority: TaskPriority
                switch task.priority?.lowercased() {
                case "high": priority = .high
                case "low": priority = .low
                default: priority = .medium
                }
                
                return TaskTemplate(
                    title: task.title,
                    description: task.description,
                    priority: priority,
                    estimatedDuration: task.estimatedDuration,
                    deadline: task.deadline,
                    tags: task.tags ?? [],
                    templateLinks: task.templateLinks,
                    isOptional: task.isOptional ?? false
                )
            }
            
            let taskList = TaskListTemplate(
                name: "タスク",
                description: step.description,
                tasks: tasks
            )
            
            return PhaseTemplate(
                title: step.title,
                description: step.description,
                order: step.order,
                prerequisites: step.prerequisites ?? [],
                templateReference: step.templateReference,
                estimatedDuration: step.estimatedDuration,
                taskLists: [taskList]
            )
        }
        
        let metadata = TemplateMetadata(
            author: legacy.metadata?.author ?? "Unknown",
            createdAt: legacy.metadata?.createdAt ?? ISO8601DateFormatter().string(from: Date()),
            estimatedDuration: legacy.metadata?.estimatedDuration,
            difficulty: difficulty,
            tags: legacy.metadata?.tags ?? [],
            targetAudience: nil
        )
        
        self.init(
            name: legacy.name,
            description: legacy.description,
            goal: legacy.goal,
            category: category,
            version: legacy.version ?? "1.0",
            phases: phases,
            metadata: metadata
        )
    }
}