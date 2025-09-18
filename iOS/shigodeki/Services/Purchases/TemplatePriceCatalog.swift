//
//  TemplatePriceCatalog.swift
//  shigodeki
//
//  Centralized mapping between StoreKit product identifiers and entitlements.
//

import Foundation

enum CatalogEntitlement {
    case pro
    case template(TemplateID)
    case unknown
}

struct TemplatePriceCatalog {
    static let paidTemplateIDs: Set<TemplateID> = [
        "move",
        "shukatsu"
    ]

    static let proMonthlyProductID = "com.shigodeki.pro.month"
    static let proYearlyProductID = "com.shigodeki.pro.year"

    static let proProductIDs: Set<String> = [
        proMonthlyProductID,
        proYearlyProductID
    ]

    static let templateProductToID: [String: TemplateID] = [
        "com.shigodeki.template.move": "move",
        "com.shigodeki.template.shukatsu": "shukatsu"
    ]

    static func productID(for templateID: TemplateID) -> String? {
        templateProductToID.first { $0.value == templateID }?.key
    }

    static func entitlement(for productID: String) -> CatalogEntitlement {
        if proProductIDs.contains(productID) {
            return .pro
        }
        if let templateID = templateProductToID[productID] {
            return .template(templateID)
        }
        return .unknown
    }
}
