//
//  Entitlements.swift
//  shigodeki
//
//  Monetization data contracts. Introduced for purchase/subscription planning.
//

import Foundation

typealias TemplateID = String

struct Entitlements: Codable, Equatable {
    var isPro: Bool
    var ownedTemplates: Set<TemplateID>
    var updatedAt: Date

    static let empty = Entitlements(isPro: false, ownedTemplates: [], updatedAt: .distantPast)
}

struct TemplateMeta: Codable, Equatable, Identifiable {
    var id: TemplateID
    var title: String
    var isPaid: Bool
    var priceID: String?
}

