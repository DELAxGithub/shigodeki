//
//  PhotoDraftBuilder.swift
//  shigodeki
//
//  Placeholder builder for photo-derived TaskDraft generation.
//

import Foundation

enum PhotoDraftBuilder {
    struct Suggestion: Identifiable {
        let id = UUID()
        let title: String
        let details: String?
        let labels: [String]
        let dueDate: Date?
        let priority: TaskPriority
    }

    static func build(from suggestions: [Suggestion]) -> [TaskDraft] {
        suggestions.map { suggestion in
            TaskDraft(
                title: suggestion.title,
                assignee: nil,
                due: suggestion.dueDate,
                rationale: suggestion.details,
                priority: suggestion.priority
            )
        }
    }
}
