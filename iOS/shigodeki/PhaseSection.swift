//
//  PhaseSection.swift
//  shigodeki
//
//  Lightweight section metadata per phase (name/order/color)
//

import Foundation
import FirebaseFirestore

struct PhaseSection: Identifiable, Codable, Hashable {
    var id: String?
    var name: String
    var order: Int
    var colorHex: String?
    var createdAt: Date?
    
    init(name: String, order: Int = 0, colorHex: String? = nil) {
        self.name = name
        self.order = order
        self.colorHex = colorHex
    }
}

