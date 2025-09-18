//
//  PurchaseFlowTypes.swift
//  shigodeki
//
//  Shared types for StoreKit purchase flows.
//

import Foundation

enum PurchaseFlowError: Error {
    case purchasesDisabled
    case storeKitError(Error)
    case unknown
}

extension PurchaseFlowError: CustomStringConvertible {
    var description: String {
        switch self {
        case .purchasesDisabled:
            return "Purchases disabled"
        case .storeKitError(let error):
            return "StoreKit error: \(error.localizedDescription)"
        case .unknown:
            return "Unknown purchase error"
        }
    }

    var userMessage: String {
        switch self {
        case .purchasesDisabled:
            return "現在購入は利用できません。"
        case .storeKitError:
            return "購入に失敗しました。時間を置いて再試行してください。"
        case .unknown:
            return "不明なエラーが発生しました。"
        }
    }
}

enum PurchaseOutcome {
    case success
    case cancelled
    case pending
    case failed(PurchaseFlowError)
}

extension PurchaseFlowError: Equatable {
    static func == (lhs: PurchaseFlowError, rhs: PurchaseFlowError) -> Bool {
        switch (lhs, rhs) {
        case (.purchasesDisabled, .purchasesDisabled):
            return true
        case (.storeKitError, .storeKitError):
            return true
        case (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
}

@MainActor
protocol EntitlementRefreshing {
    func refresh() async
}

protocol TemplatePurchaseCoordinating {
    func buyTemplate(templateID: TemplateID, productID: String) async -> PurchaseOutcome
}

protocol ProSubscriptionCoordinating {
    func buyPro(productID: String) async -> PurchaseOutcome
}

#if canImport(StoreKit)
import StoreKit

@available(iOS 15.0, *)
protocol PurchaseProductCataloging: AnyObject {
    func products(for ids: [String]) async throws -> [Product]
    func product(for id: String) async throws -> Product?
}
#endif
