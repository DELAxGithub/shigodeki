//
//  TemplateContentEncoder.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import Foundation

struct TemplateContentEncoder {
    
    static func encodeTemplate(_ template: ProjectTemplate, format: TemplateExportFormat) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            switch format {
            case .projectTemplate:
                return try encoder.encode(template)
                
            case .legacySteps:
                let legacyTemplate = convertToLegacyFormat(template)
                return try encoder.encode(legacyTemplate)
                
            case .minimal:
                let minimalTemplate = createMinimalTemplate(template)
                return try JSONSerialization.data(withJSONObject: minimalTemplate, options: [.prettyPrinted, .sortedKeys])
            }
        } catch {
            throw TemplateExportError.encodingFailed
        }
    }
    
    static func convertToLegacyFormat(_ template: ProjectTemplate) -> LegacyJSONTemplate {
        let steps = template.phases.map { phase in
            let tasks = phase.taskLists.flatMap { $0.tasks }.map { task in
                LegacyJSONTemplate.LegacyTask(
                    title: task.title,
                    description: task.description,
                    priority: task.priority.rawValue,
                    estimatedDuration: task.estimatedDuration,
                    deadline: task.deadline,
                    tags: task.tags.isEmpty ? nil : task.tags,
                    templateLinks: task.templateLinks,
                    isOptional: task.isOptional ? true : nil
                )
            }
            
            return LegacyJSONTemplate.LegacyStep(
                title: phase.title,
                description: phase.description,
                order: phase.order,
                prerequisites: phase.prerequisites.isEmpty ? nil : phase.prerequisites,
                templateReference: phase.templateReference,
                estimatedDuration: phase.estimatedDuration,
                tasks: tasks
            )
        }
        
        let metadata = LegacyJSONTemplate.LegacyMetadata(
            author: template.metadata.author,
            createdAt: template.metadata.createdAt,
            estimatedDuration: template.metadata.estimatedDuration,
            difficulty: template.metadata.difficulty.rawValue,
            tags: template.metadata.tags.isEmpty ? nil : template.metadata.tags
        )
        
        return LegacyJSONTemplate(
            name: template.name,
            description: template.description,
            goal: template.goal,
            category: template.category.displayName,
            version: template.version,
            steps: steps,
            metadata: metadata
        )
    }
    
    static func createMinimalTemplate(_ template: ProjectTemplate) -> [String: Any] {
        return [
            "name": template.name,
            "description": template.description ?? "",
            "category": template.category.rawValue,
            "phases": template.phases.map { phase in
                [
                    "title": phase.title,
                    "order": phase.order,
                    "tasks": phase.taskLists.flatMap { $0.tasks }.map { task in
                        [
                            "title": task.title,
                            "priority": task.priority.rawValue
                        ]
                    }
                ]
            }
        ]
    }
}