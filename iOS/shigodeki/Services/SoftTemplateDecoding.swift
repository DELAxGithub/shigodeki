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

    enum CodingKeys: String, CodingKey { case title, name, description, order, taskLists, tasks }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Accept either `title` or `name`
        if let t = try c.decodeIfPresent(String.self, forKey: .title) {
            self.title = t
        } else if let n = try c.decodeIfPresent(String.self, forKey: .name) {
            self.title = n
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.title,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing 'title' or 'name' in phase")
            )
        }
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.order = (try c.decodeIfPresent(Int.self, forKey: .order)) ?? 0

        // Accept either nested taskLists or direct tasks under phase
        if let lists = try c.decodeIfPresent([SoftTaskList].self, forKey: .taskLists) {
            self.taskLists = lists
        } else if let tasks = try c.decodeIfPresent([SoftTask].self, forKey: .tasks) {
            self.taskLists = [SoftTaskList(name: "基本", description: self.description, color: nil, order: 0, tasks: tasks)]
        } else {
            self.taskLists = []
        }
    }
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

    enum CodingKeys: String, CodingKey { case title, name, description, priority }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let t = try c.decodeIfPresent(String.self, forKey: .title) {
            self.title = t
        } else if let n = try c.decodeIfPresent(String.self, forKey: .name) {
            self.title = n
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.title,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing 'title' or 'name' in task")
            )
        }
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.priority = try c.decodeIfPresent(String.self, forKey: .priority)
    }
}
