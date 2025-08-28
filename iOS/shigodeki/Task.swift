//
//  Task.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore

struct ShigodekiTask: Identifiable, Codable {
    var id: String?
    let title: String
    let description: String?
    var isCompleted: Bool
    let assignedTo: String? // user ID
    var createdAt: Date?
    var completedAt: Date?
    var dueDate: Date?
    var priority: TaskPriority
    let createdBy: String // user ID of creator
    
    init(title: String, description: String? = nil, assignedTo: String? = nil, createdBy: String, dueDate: Date? = nil, priority: TaskPriority = .medium) {
        self.title = title
        self.description = description
        self.isCompleted = false
        self.assignedTo = assignedTo
        self.createdBy = createdBy
        self.dueDate = dueDate
        self.priority = priority
    }
    
    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return Date() > dueDate
    }
    
    var dueDateFormatted: String? {
        guard let dueDate = dueDate else { return nil }
        return DateFormatter.taskDueDate.string(from: dueDate)
    }
}

enum TaskPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "blue"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let taskDueDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    static let taskDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}