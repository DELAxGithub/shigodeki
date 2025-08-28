//
//  Project.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore

struct Project: Identifiable, Codable, Hashable {
    var id: String?
    var name: String
    var description: String?
    let ownerId: String
    var memberIds: [String]
    var createdAt: Date?
    var lastModifiedAt: Date?
    var isArchived: Bool
    var isCompleted: Bool
    var completedAt: Date?
    var settings: ProjectSettings?
    var statistics: ProjectStats?
    
    init(name: String, description: String? = nil, ownerId: String) {
        self.name = name
        self.description = description
        self.ownerId = ownerId
        self.memberIds = [ownerId]
        self.isArchived = false
        self.isCompleted = false
        self.completedAt = nil
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
}

struct ProjectSettings: Codable, Hashable {
    let color: TaskListColor
    let isPrivate: Bool
    let defaultPhaseTemplate: String?
    
    init(color: TaskListColor = .blue, isPrivate: Bool = false, defaultPhaseTemplate: String? = nil) {
        self.color = color
        self.isPrivate = isPrivate
        self.defaultPhaseTemplate = defaultPhaseTemplate
    }
}

struct ProjectStats: Codable, Hashable {
    let totalTasks: Int
    let completedTasks: Int
    let totalPhases: Int
    let activeMembers: Int
    
    init(totalTasks: Int = 0, completedTasks: Int = 0, totalPhases: Int = 0, activeMembers: Int = 0) {
        self.totalTasks = totalTasks
        self.completedTasks = completedTasks
        self.totalPhases = totalPhases
        self.activeMembers = activeMembers
    }
    
    var completionPercentage: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks) * 100
    }
}

enum Role: String, CaseIterable, Codable, Hashable {
    case owner = "owner"
    case editor = "editor"
    case viewer = "viewer"
    
    var displayName: String {
        switch self {
        case .owner: return "オーナー"
        case .editor: return "編集者"
        case .viewer: return "閲覧者"
        }
    }
    
    var permissions: Set<Permission> {
        switch self {
        case .owner: return [.read, .write, .delete, .invite, .manageMembers]
        case .editor: return [.read, .write, .invite]
        case .viewer: return [.read]
        }
    }
}

enum Permission: String, CaseIterable, Hashable {
    case read = "read"
    case write = "write"
    case delete = "delete"
    case invite = "invite"
    case manageMembers = "manageMembers"
    
    var displayName: String {
        switch self {
        case .read: return "閲覧"
        case .write: return "編集"
        case .delete: return "削除"
        case .invite: return "招待"
        case .manageMembers: return "メンバー管理"
        }
    }
}

struct ProjectMember: Identifiable, Codable, Hashable {
    var id: String?
    let userId: String
    let projectId: String
    var role: Role
    var joinedAt: Date?
    var invitedBy: String?
    var lastActiveAt: Date?
    
    init(userId: String, projectId: String, role: Role, invitedBy: String? = nil) {
        self.id = userId
        self.userId = userId
        self.projectId = projectId
        self.role = role
        self.invitedBy = invitedBy
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ProjectMember, rhs: ProjectMember) -> Bool {
        lhs.id == rhs.id
    }
}