//
//  TemplateMonetizationCatalog.swift
//  shigodeki
//
//  Centralized paid/free metadata for templates. Keeps UI logic consistent.
//

import Foundation

enum MonetizationBadge: String {
    case pro
    case lock

    var displayText: String {
        switch self {
        case .pro:
            return NSLocalizedString("template.badge.pro", tableName: nil, bundle: .main, value: "PRO", comment: "Pro badge label")
        case .lock:
            return NSLocalizedString("template.badge.locked", tableName: nil, bundle: .main, value: "Locked", comment: "Locked badge label")
        }
    }

    var systemImageName: String {
        switch self {
        case .pro:
            return "star.fill"
        case .lock:
            return "lock.fill"
        }
    }
}

struct TemplateTeaserConfig {
    let maxTaskLists: Int
    let maxTasksPerList: Int

    static let `default` = TemplateTeaserConfig(maxTaskLists: 2, maxTasksPerList: 3)
}

@MainActor
protocol TemplateEntitlementResolving {
    func isUnlocked(templateID: TemplateID) -> Bool
}

extension TemplateEntitlementResolving {
    func hasEntitlement(for template: ProjectTemplate) -> Bool {
        isUnlocked(templateID: template.id)
    }
}

struct DefaultTemplateEntitlementResolver: TemplateEntitlementResolving {
    @MainActor
    func isUnlocked(templateID: TemplateID) -> Bool { false }

    @MainActor
    static let shared = DefaultTemplateEntitlementResolver()
}

enum TemplateMonetizationCatalog {
    private static let paidTemplateIDs: Set<TemplateID> = TemplatePriceCatalog.paidTemplateIDs
    private static let teaserConfig = TemplateTeaserConfig.default
    @MainActor
    private static var entitlementResolver: TemplateEntitlementResolving = DefaultTemplateEntitlementResolver.shared

    @MainActor
    static func setResolver(_ resolver: TemplateEntitlementResolving) {
        entitlementResolver = resolver
    }

    @MainActor
    static func configure(resolver: TemplateEntitlementResolving) {
        setResolver(resolver)
    }

    static func isPaid(_ template: ProjectTemplate) -> Bool {
        paidTemplateIDs.contains(template.id)
    }

    @MainActor
    static func badge(for template: ProjectTemplate, resolver: TemplateEntitlementResolving? = nil) -> MonetizationBadge? {
        guard isPaid(template) else { return nil }
        let resolver = resolver ?? entitlementResolver
        guard !resolver.isUnlocked(templateID: template.id) else { return nil }
        return .pro
    }

    static func teaserConfiguration(for template: ProjectTemplate) -> TemplateTeaserConfig {
        teaserConfig
    }

    @MainActor
    static func hasEntitlement(for template: ProjectTemplate, resolver: TemplateEntitlementResolving? = nil) -> Bool {
        let resolver = resolver ?? entitlementResolver
        return resolver.isUnlocked(templateID: template.id)
    }

    @MainActor
    static func resolver() -> TemplateEntitlementResolving {
        entitlementResolver
    }
}
