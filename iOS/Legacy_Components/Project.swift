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
    var ownerId: String
    var ownerType: ProjectOwnerType = .individual
    var memberIds: [String]
    var createdAt: Date?
    var lastModifiedAt: Date?
    var isArchived: Bool
    var isCompleted: Bool
    var completedAt: Date?
    var settings: ProjectSettings?
    var statistics: ProjectStats?
    
    init(name: String, description: String? = nil, ownerId: String, ownerType: ProjectOwnerType = .individual) {
        self.name = name
        self.description = description
        self.ownerId = ownerId
        self.ownerType = ownerType
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

enum ProjectOwnerType: String, CaseIterable, Codable, Hashable {
    case individual
    case family
    
    var displayName: String {
        switch self {
        case .individual: return "個人"
        case .family: return "家族"
        }
    }
}

// MARK: - Codable (default handling for backward compatibility)
extension Project {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case ownerId
        case ownerType
        case memberIds
        case createdAt
        case lastModifiedAt
        case isArchived
        case isCompleted
        case completedAt
        case settings
        case statistics
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try? container.decode(String.self, forKey: .description)
        self.ownerId = (try? container.decode(String.self, forKey: .ownerId)) ?? ""
        self.ownerType = (try? container.decode(ProjectOwnerType.self, forKey: .ownerType)) ?? .individual
        // Default memberIds to [ownerId] for backward compatibility
        self.memberIds = (try? container.decode([String].self, forKey: .memberIds)) ?? (self.ownerId.isEmpty ? [] : [self.ownerId])
        self.createdAt = try? container.decode(Date.self, forKey: .createdAt)
        self.lastModifiedAt = try? container.decode(Date.self, forKey: .lastModifiedAt)
        self.isArchived = (try? container.decode(Bool.self, forKey: .isArchived)) ?? false
        self.isCompleted = (try? container.decode(Bool.self, forKey: .isCompleted)) ?? false
        self.completedAt = try? container.decode(Date.self, forKey: .completedAt)
        self.settings = try? container.decode(ProjectSettings.self, forKey: .settings)
        self.statistics = try? container.decode(ProjectStats.self, forKey: .statistics)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(ownerType, forKey: .ownerType)
        try container.encode(memberIds, forKey: .memberIds)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(lastModifiedAt, forKey: .lastModifiedAt)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(settings, forKey: .settings)
        try container.encodeIfPresent(statistics, forKey: .statistics)
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
    var displayName: String?
    
    init(userId: String, projectId: String, role: Role, invitedBy: String? = nil, displayName: String? = nil) {
        self.id = userId
        self.userId = userId
        self.projectId = projectId
        self.role = role
        self.invitedBy = invitedBy
        self.displayName = displayName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ProjectMember, rhs: ProjectMember) -> Bool {
        lhs.id == rhs.id
    }
}
