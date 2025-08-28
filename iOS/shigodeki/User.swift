//
//  User.swift
//  shigodeki
//
//  Created by Claude on 2025-08-27.
//

import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable, Hashable {
    var id: String?
    let name: String
    let email: String
    let projectIds: [String]
    let roleAssignments: [String: Role]
    var createdAt: Date?
    var lastActiveAt: Date?
    var preferences: UserPreferences?
    
    // Legacy support
    let familyIds: [String]?
    
    init(name: String, email: String, projectIds: [String] = [], roleAssignments: [String: Role] = [:]) {
        self.name = name
        self.email = email
        self.projectIds = projectIds
        self.roleAssignments = roleAssignments
        self.familyIds = nil
    }
    
    // Legacy constructor for backward compatibility
    init(name: String, email: String, familyIds: [String] = []) {
        self.name = name
        self.email = email
        self.projectIds = []
        self.roleAssignments = [:]
        self.familyIds = familyIds
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}

struct UserPreferences: Codable, Hashable {
    let theme: String
    let notificationsEnabled: Bool
    let defaultView: String
    
    init(theme: String = "system", notificationsEnabled: Bool = true, defaultView: String = "list") {
        self.theme = theme
        self.notificationsEnabled = notificationsEnabled
        self.defaultView = defaultView
    }
}