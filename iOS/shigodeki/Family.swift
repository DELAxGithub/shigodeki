//
//  Family.swift
//  shigodeki
//
//  Created by Claude on 2025-08-27.
//

import Foundation
import FirebaseFirestore

struct Family: Identifiable, Codable {
    var id: String?
    let name: String
    var members: [String] // user IDs - var for optimistic updates
    var createdAt: Date?
    var lastUpdatedAt: Date?
    var devEnvironmentTest: String?
    
    init(name: String, members: [String] = []) {
        self.name = name
        self.members = members
    }
}