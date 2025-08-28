//
//  TaskList.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore

struct TaskList: Identifiable, Codable, Hashable {
    var id: String?
    let name: String
    let phaseId: String
    let projectId: String
    var createdAt: Date?
    let createdBy: String
    var color: TaskListColor
    var isArchived: Bool
    var order: Int
    var settings: TaskListSettings?
    
    // Legacy support
    let familyId: String?
    
    init(name: String, phaseId: String, projectId: String, createdBy: String, color: TaskListColor = .blue, order: Int) {
        self.name = name
        self.phaseId = phaseId
        self.projectId = projectId
        self.createdBy = createdBy
        self.color = color
        self.isArchived = false
        self.order = order
        self.familyId = nil
    }
    
    // Legacy constructor for backward compatibility
    init(name: String, familyId: String, createdBy: String, color: TaskListColor = .blue) {
        self.name = name
        self.phaseId = ""
        self.projectId = ""
        self.familyId = familyId
        self.createdBy = createdBy
        self.color = color
        self.isArchived = false
        self.order = 0
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TaskList, rhs: TaskList) -> Bool {
        lhs.id == rhs.id
    }
}

struct TaskListSettings: Codable, Hashable {
    let autoArchiveCompletedTasks: Bool
    let defaultTaskPriority: TaskPriority
    
    init(autoArchiveCompletedTasks: Bool = false, defaultTaskPriority: TaskPriority = .medium) {
        self.autoArchiveCompletedTasks = autoArchiveCompletedTasks
        self.defaultTaskPriority = defaultTaskPriority
    }
}

enum TaskListColor: String, CaseIterable, Codable, Hashable {
    case blue = "blue"
    case green = "green"
    case orange = "orange"
    case red = "red"
    case purple = "purple"
    case pink = "pink"
    case yellow = "yellow"
    case gray = "gray"
    
    var displayName: String {
        switch self {
        case .blue: return "青"
        case .green: return "緑"
        case .orange: return "オレンジ"
        case .red: return "赤"
        case .purple: return "紫"
        case .pink: return "ピンク"
        case .yellow: return "黄"
        case .gray: return "グレー"
        }
    }
}