//
//  Environment+Purchases.swift
//  shigodeki
//
//  Environment helpers for purchase-related dependencies.
//

import SwiftUI

private struct TemplatePurchaseCoordinatorKey: EnvironmentKey {
    static let defaultValue: TemplatePurchaseCoordinating? = nil
}

private struct PurchaseProductCatalogKey: EnvironmentKey {
    static let defaultValue: PurchaseProductCataloging? = nil
}

private struct ProSubscriptionCoordinatorKey: EnvironmentKey {
    static let defaultValue: ProSubscriptionCoordinating? = nil
}

extension EnvironmentValues {
    var templatePurchaseCoordinator: TemplatePurchaseCoordinating? {
        get { self[TemplatePurchaseCoordinatorKey.self] }
        set { self[TemplatePurchaseCoordinatorKey.self] = newValue }
    }

    var purchaseProductCatalog: PurchaseProductCataloging? {
        get { self[PurchaseProductCatalogKey.self] }
        set { self[PurchaseProductCatalogKey.self] = newValue }
    }

    var proSubscriptionCoordinator: ProSubscriptionCoordinating? {
        get { self[ProSubscriptionCoordinatorKey.self] }
        set { self[ProSubscriptionCoordinatorKey.self] = newValue }
    }
}
