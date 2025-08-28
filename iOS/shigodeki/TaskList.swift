//
//  TaskList.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore

struct TaskList: Identifiable, Codable {
    var id: String?
    let name: String
    let familyId: String
    var createdAt: Date?
    let createdBy: String // user ID of creator
    var color: TaskListColor
    var isArchived: Bool
    
    init(name: String, familyId: String, createdBy: String, color: TaskListColor = .blue) {
        self.name = name
        self.familyId = familyId
        self.createdBy = createdBy
        self.color = color
        self.isArchived = false
    }
}

enum TaskListColor: String, CaseIterable, Codable {
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