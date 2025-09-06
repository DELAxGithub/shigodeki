//
//  Phase.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore

struct Phase: Identifiable, Codable, Hashable {
    var id: String?
    let name: String
    let description: String?
    let projectId: String
    var order: Int
    var createdAt: Date?
    var createdBy: String
    var isCompleted: Bool
    var completedAt: Date?
    var settings: PhaseSettings?
    
    init(name: String, description: String? = nil, projectId: String, createdBy: String, order: Int) {
        self.name = name
        self.description = description
        self.projectId = projectId
        self.createdBy = createdBy
        self.order = order
        self.isCompleted = false
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Phase, rhs: Phase) -> Bool {
        lhs.id == rhs.id
    }
}

struct PhaseSettings: Codable, Hashable {
    let color: TaskListColor
    let autoCompleteOnAllTasksDone: Bool
    
    init(color: TaskListColor = .blue, autoCompleteOnAllTasksDone: Bool = false) {
        self.color = color
        self.autoCompleteOnAllTasksDone = autoCompleteOnAllTasksDone
    }
}