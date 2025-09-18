//
//  AIDraftMapper.swift
//  shigodeki
//
//  Placeholder mapper for converting AI suggestions to TaskDrafts.
//

import Foundation

enum AIDraftMapper {
    static func map(from suggestions: AITaskSuggestion) -> [TaskDraft] {
        var drafts: [TaskDraft] = []

        func makeDraft(from task: AITaskSuggestion.TaskSuggestion) -> TaskDraft {
            TaskDraft(
                title: task.title,
                assignee: nil,
                due: parseDueDate(task.due),
                rationale: preferredRationale(from: task),
                priority: mapPriority(task.priority)
            )
        }

        drafts.append(contentsOf: suggestions.tasks.map(makeDraft(from:)))

        if let phases = suggestions.phases {
            for phase in phases {
                drafts.append(contentsOf: phase.tasks.map(makeDraft(from:)))
            }
        }

        return drafts
    }

    private static func mapPriority(_ priority: AITaskPriority?) -> TaskPriority {
        guard let priority else { return .medium }
        switch priority {
        case .low: return .low
        case .normal, .medium: return .medium
        case .high, .urgent: return .high
        }
    }

    private static func parseDueDate(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        if let date = isoFormatter.date(from: raw) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    private static func preferredRationale(from task: AITaskSuggestion.TaskSuggestion) -> String? {
        if let rationale = task.rationale, rationale.isEmpty == false {
            return rationale
        }
        if let description = task.description, description.isEmpty == false {
            return description
        }
        if let subtasks = task.subtasks, subtasks.isEmpty == false {
            return subtasks.joined(separator: "\n")
        }
        return nil
    }
}
