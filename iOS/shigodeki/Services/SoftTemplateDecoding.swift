//
//  SoftTemplateDecoding.swift
//  shigodeki
//
//  Purpose: Tolerant importer for modern-like JSON that omits
//  strict fields (tags, isOptional, dependsOn, subtasks, metadata, etc.).
//  Converts into ProjectTemplate with safe defaults.
//

import Foundation

struct SoftTemplateDecoder {
    static func importSoftModernTemplate(from data: Data) throws -> ProjectTemplate {
        let decoder = ModelJSONUtility.shared.sharedDecoder
        let soft = try decoder.decode(SoftProject.self, from: data)
        return convert(soft)
    }
    
    private static func convert(_ soft: SoftProject) -> ProjectTemplate {
        let category = TemplateCategory(rawValue: soft.category ?? "other") ?? .other
        
        let phases: [PhaseTemplate] = soft.phases.enumerated().map { (_, p) in
            let taskLists: [TaskListTemplate] = p.taskLists.enumerated().map { (_, tl) in
                let tasks: [TaskTemplate] = tl.tasks.map { t in
                    TaskTemplate(
                        title: t.title,
                        description: t.description,
                        priority: SoftTemplateDecoder.normalizePriority(t.priority),
                        estimatedDuration: nil,
                        deadline: nil,
                        tags: [],
                        templateLinks: nil,
                        isOptional: false,
                        estimatedHours: nil,
                        dependsOn: [],
                        subtasks: []
                    )
                }
                return TaskListTemplate(
                    name: tl.name,
                    description: tl.description,
                    color: TaskListColor(rawValue: tl.color ?? "blue") ?? .blue,
                    order: tl.order ?? 0,
                    tasks: tasks
                )
            }
            return PhaseTemplate(
                title: p.title,
                description: p.description,
                order: p.order,
                prerequisites: [],
                templateReference: nil,
                estimatedDuration: nil,
                taskLists: taskLists
            )
        }
        
        let metadata = TemplateMetadata(
            author: "Imported",
            estimatedDuration: nil,
            difficulty: .intermediate,
            tags: [],
            language: "ja",
            requiredSkills: nil,
            targetAudience: nil
        )
        
        return ProjectTemplate(
            name: soft.name,
            description: soft.description,
            goal: soft.goal,
            category: category,
            version: soft.version ?? "1.0",
            phases: phases,
            metadata: metadata
        )
    }
    
    private static func normalizePriority(_ p: String?) -> TaskPriority {
        guard let p = p?.lowercased() else { return .medium }
        switch p {
        case "high", "高": return .high
        case "low", "低": return .low
        default: return .medium
        }
    }
}

// MARK: - Soft (Tolerant) Decodable Models

private struct SoftProject: Decodable {
    let name: String
    let description: String?
    let goal: String?
    let category: String?
    let version: String?
    let phases: [SoftPhase]
}

private struct SoftPhase: Decodable {
    let title: String
    let description: String?
    let order: Int
    let taskLists: [SoftTaskList]
}

private struct SoftTaskList: Decodable {
    let name: String
    let description: String?
    let color: String?
    let order: Int?
    let tasks: [SoftTask]
}

private struct SoftTask: Decodable {
    let title: String
    let description: String?
    let priority: String?
}

