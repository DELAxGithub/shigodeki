//
//  User.swift
//  shigodeki
//
//  Created by Claude on 2025-08-27.
//

import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    var id: String?
    let name: String
    let email: String
    let familyIds: [String]
    var createdAt: Date?
    
    init(name: String, email: String, familyIds: [String] = []) {
        self.name = name
        self.email = email
        self.familyIds = familyIds
    }
}