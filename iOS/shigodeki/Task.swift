//
//  Task.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore

struct ShigodekiTask: Identifiable, Codable, Hashable {
    var id: String?
    let title: String
    let description: String?
    var isCompleted: Bool
    let assignedTo: String?
    var createdAt: Date?
    var completedAt: Date?
    var dueDate: Date?
    var priority: TaskPriority
    let createdBy: String
    
    // Hierarchy fields
    let listId: String
    let phaseId: String
    let projectId: String
    var order: Int
    var hasSubtasks: Bool
    var subtaskCount: Int
    var completedSubtaskCount: Int
    
    // Enhanced metadata
    var tags: [String]
    var estimatedHours: Double?
    var actualHours: Double?
    var dependsOn: [String]
    
    init(title: String, description: String? = nil, assignedTo: String? = nil, 
         createdBy: String, dueDate: Date? = nil, priority: TaskPriority = .medium,
         listId: String, phaseId: String, projectId: String, order: Int) {
        self.title = title
        self.description = description
        self.isCompleted = false
        self.assignedTo = assignedTo
        self.createdBy = createdBy
        self.dueDate = dueDate
        self.priority = priority
        self.listId = listId
        self.phaseId = phaseId
        self.projectId = projectId
        self.order = order
        self.hasSubtasks = false
        self.subtaskCount = 0
        self.completedSubtaskCount = 0
        self.tags = []
        self.dependsOn = []
    }
    
    // Legacy constructor for backward compatibility
    init(title: String, description: String? = nil, assignedTo: String? = nil, createdBy: String, dueDate: Date? = nil, priority: TaskPriority = .medium) {
        self.title = title
        self.description = description
        self.isCompleted = false
        self.assignedTo = assignedTo
        self.createdBy = createdBy
        self.dueDate = dueDate
        self.priority = priority
        self.listId = ""
        self.phaseId = ""
        self.projectId = ""
        self.order = 0
        self.hasSubtasks = false
        self.subtaskCount = 0
        self.completedSubtaskCount = 0
        self.tags = []
        self.dependsOn = []
    }
    
    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return Date() > dueDate
    }
    
    var dueDateFormatted: String? {
        guard let dueDate = dueDate else { return nil }
        return DateFormatter.taskDueDate.string(from: dueDate)
    }
    
    var completionPercentage: Double {
        guard subtaskCount > 0 else { return isCompleted ? 100.0 : 0.0 }
        return Double(completedSubtaskCount) / Double(subtaskCount) * 100
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ShigodekiTask, rhs: ShigodekiTask) -> Bool {
        lhs.id == rhs.id
    }
}

enum TaskPriority: String, CaseIterable, Codable, Hashable {
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