//
//  TemplatePurchaseCoordinator.swift
//  shigodeki
//
//  Orchestrates single template purchases.
//

import Foundation
#if canImport(StoreKit)

@available(iOS 15.0, *)
final class TemplatePurchaseCoordinator {
    private let purchaseService: PurchaseServicing
    private let entitlementRefresher: EntitlementRefreshing

    init(purchaseService: PurchaseServicing, entitlementRefresher: EntitlementRefreshing) {
        self.purchaseService = purchaseService
        self.entitlementRefresher = entitlementRefresher
    }

    func buyTemplate(templateID: TemplateID, productID: String) async -> PurchaseOutcome {
        guard FeatureFlags.purchasesEnabled else {
            return .failed(.purchasesDisabled)
        }

        let result = await purchaseService.purchase(productID: productID)
        let outcome = PurchaseOutcomeMapper.map(result)

        if case .success = outcome {
            await entitlementRefresher.refresh()
        }

        return outcome
    }
}

#if canImport(StoreKit)
@available(iOS 15.0, *)
extension TemplatePurchaseCoordinator: TemplatePurchaseCoordinating {}
#endif

#endif
