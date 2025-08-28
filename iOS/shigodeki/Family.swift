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
    let members: [String] // user IDs
    var createdAt: Date?
    
    init(name: String, members: [String] = []) {
        self.name = name
        self.members = members
    }
}