//
//  EntitlementResolverLive.swift
//  shigodeki
//
//  Resolves template unlock state using EntitlementStore snapshots.
//

import Foundation

struct EntitlementResolverLive: TemplateEntitlementResolving {
    private let entitlementsProvider: @MainActor () -> Entitlements

    init(entitlementStore: EntitlementStore) {
        entitlementsProvider = {
            entitlementStore.entitlements
        }
    }

    @MainActor
    func isUnlocked(templateID: TemplateID) -> Bool {
        let entitlements = entitlementsProvider()
        if entitlements.isPro { return true }
        return entitlements.ownedTemplates.contains(templateID)
    }
}
