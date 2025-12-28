//
//  Task.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore
import SwiftUI

enum TaskSyncStatus: String, Codable, CaseIterable {
    case pending
    case confirmed
    case conflicted
}

struct ShigodekiTask: Identifiable, Codable, Hashable {
    var id: String?
    var title: String
    var description: String?
    var isCompleted: Bool
    var assignedTo: String?
    var createdAt: Date?
    var completedAt: Date?
    var dueDate: Date?
    var priority: TaskPriority
    let createdBy: String
    var linkURL: String?
    var attachments: [String]? // base64 data URLs or remote URLs
    
    // Hierarchy fields
    var listId: String
    let phaseId: String
    let projectId: String
    var order: Int
    var orderIndex: Int?
    var hasSubtasks: Bool
    var subtaskCount: Int
    var completedSubtaskCount: Int

    // Enhanced metadata
    var tags: [String]
    var estimatedHours: Double?
    var actualHours: Double?
    var dependsOn: [String]
    
    // Phase-level sections (new model)
    var sectionId: String? // Optional grouping within a phase
    var sectionName: String? // Denormalized for fast rendering
    
    // Sync metadata
    var syncStatus: TaskSyncStatus

    init(title: String, description: String? = nil, assignedTo: String? = nil, 
         createdBy: String, dueDate: Date? = nil, priority: TaskPriority = .medium,
         listId: String, phaseId: String, projectId: String, order: Int,
         orderIndex: Int? = nil, syncStatus: TaskSyncStatus = .confirmed) {
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
        self.orderIndex = orderIndex ?? order
        self.hasSubtasks = false
        self.subtaskCount = 0
        self.completedSubtaskCount = 0
        self.tags = []
        self.dependsOn = []
        self.syncStatus = syncStatus
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
        self.orderIndex = 0
        self.hasSubtasks = false
        self.subtaskCount = 0
        self.completedSubtaskCount = 0
        self.tags = []
        self.dependsOn = []
        self.syncStatus = .confirmed
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case isCompleted
        case assignedTo
        case createdAt
        case completedAt
        case dueDate
        case priority
        case createdBy
        case linkURL
        case attachments
        case listId
        case phaseId
        case projectId
        case order
        case orderIndex
        case hasSubtasks
        case subtaskCount
        case completedSubtaskCount
        case tags
        case estimatedHours
        case actualHours
        case dependsOn
        case sectionId
        case sectionName
        case syncStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        assignedTo = try container.decodeIfPresent(String.self, forKey: .assignedTo)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        priority = try container.decodeIfPresent(TaskPriority.self, forKey: .priority) ?? .medium
        createdBy = try container.decode(String.self, forKey: .createdBy)
        linkURL = try container.decodeIfPresent(String.self, forKey: .linkURL)
        attachments = try container.decodeIfPresent([String].self, forKey: .attachments)
        listId = try container.decode(String.self, forKey: .listId)
        phaseId = try container.decode(String.self, forKey: .phaseId)
        projectId = try container.decode(String.self, forKey: .projectId)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        orderIndex = try container.decodeIfPresent(Int.self, forKey: .orderIndex) ?? order
        hasSubtasks = try container.decodeIfPresent(Bool.self, forKey: .hasSubtasks) ?? false
        subtaskCount = try container.decodeIfPresent(Int.self, forKey: .subtaskCount) ?? 0
        completedSubtaskCount = try container.decodeIfPresent(Int.self, forKey: .completedSubtaskCount) ?? 0
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        estimatedHours = try container.decodeIfPresent(Double.self, forKey: .estimatedHours)
        actualHours = try container.decodeIfPresent(Double.self, forKey: .actualHours)
        dependsOn = try container.decodeIfPresent([String].self, forKey: .dependsOn) ?? []
        sectionId = try container.decodeIfPresent(String.self, forKey: .sectionId)
        sectionName = try container.decodeIfPresent(String.self, forKey: .sectionName)
        syncStatus = try container.decodeIfPresent(TaskSyncStatus.self, forKey: .syncStatus) ?? .confirmed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(assignedTo, forKey: .assignedTo)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(priority, forKey: .priority)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encodeIfPresent(linkURL, forKey: .linkURL)
        try container.encodeIfPresent(attachments, forKey: .attachments)
        try container.encode(listId, forKey: .listId)
        try container.encode(phaseId, forKey: .phaseId)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(order, forKey: .order)
        if let orderIndex {
            try container.encode(orderIndex, forKey: .orderIndex)
        }
        try container.encode(hasSubtasks, forKey: .hasSubtasks)
        try container.encode(subtaskCount, forKey: .subtaskCount)
        try container.encode(completedSubtaskCount, forKey: .completedSubtaskCount)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(estimatedHours, forKey: .estimatedHours)
        try container.encodeIfPresent(actualHours, forKey: .actualHours)
        try container.encode(dependsOn, forKey: .dependsOn)
        try container.encodeIfPresent(sectionId, forKey: .sectionId)
        try container.encodeIfPresent(sectionName, forKey: .sectionName)
        if syncStatus != .confirmed {
            try container.encode(syncStatus, forKey: .syncStatus)
        }
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
    
    var swiftUIColor: Color {
        switch self {
        case .low: return Color.primaryBlue
        case .medium: return Color.warning
        case .high: return Color.error
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
