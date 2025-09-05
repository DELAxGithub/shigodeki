//
//  ProjectInvitation.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore

struct ProjectInvitation: Identifiable, Codable, Hashable {
    var id: String?
    let inviteCode: String
    let projectId: String
    let projectName: String
    let invitedBy: String
    let invitedByName: String
    let role: Role
    var isActive: Bool
    var createdAt: Date?
    var expiresAt: Date?
    var usedAt: Date?
    var usedBy: String?
    
    init(inviteCode: String, projectId: String, projectName: String, 
         invitedBy: String, invitedByName: String, role: Role) {
        self.id = inviteCode
        self.inviteCode = inviteCode
        self.projectId = projectId
        self.projectName = projectName
        self.invitedBy = invitedBy
        self.invitedByName = invitedByName
        self.role = role
        self.isActive = true
        self.expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date())
    }
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    var isUsed: Bool {
        return usedAt != nil
    }
    
    var isValid: Bool {
        return isActive && !isExpired && !isUsed
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ProjectInvitation, rhs: ProjectInvitation) -> Bool {
        lhs.id == rhs.id
    }
}