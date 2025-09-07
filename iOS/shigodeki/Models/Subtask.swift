//
//  Subtask.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore

struct Subtask: Identifiable, Codable, Hashable {
    var id: String?
    let title: String
    let description: String?
    var isCompleted: Bool
    let assignedTo: String?
    var createdAt: Date?
    var completedAt: Date?
    var dueDate: Date?
    let createdBy: String
    
    let taskId: String
    let listId: String
    let phaseId: String
    let projectId: String
    var order: Int
    
    init(title: String, description: String? = nil, assignedTo: String? = nil,
         createdBy: String, dueDate: Date? = nil, taskId: String, 
         listId: String, phaseId: String, projectId: String, order: Int) {
        self.title = title
        self.description = description
        self.isCompleted = false
        self.assignedTo = assignedTo
        self.createdBy = createdBy
        self.dueDate = dueDate
        self.taskId = taskId
        self.listId = listId
        self.phaseId = phaseId
        self.projectId = projectId
        self.order = order
    }
    
    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return Date() > dueDate
    }
    
    var dueDateFormatted: String? {
        guard let dueDate = dueDate else { return nil }
        return DateFormatter.taskDueDate.string(from: dueDate)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Subtask, rhs: Subtask) -> Bool {
        // UI更新を確実にするため、IDだけでなく重要なフィールドも比較
        lhs.id == rhs.id && 
        lhs.isCompleted == rhs.isCompleted &&
        lhs.title == rhs.title &&
        lhs.description == rhs.description &&
        lhs.completedAt == rhs.completedAt
    }
}