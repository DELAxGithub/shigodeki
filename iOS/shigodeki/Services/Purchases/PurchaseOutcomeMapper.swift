//
//  PurchaseOutcomeMapper.swift
//  shigodeki
//
//  Maps PurchaseResult (StoreKit) to high-level PurchaseOutcome.
//

import Foundation

struct PurchaseOutcomeMapper {
    static func map(_ result: PurchaseResult) -> PurchaseOutcome {
        switch result {
        case .success(let verified):
            return verified ? .success : .pending
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        case .failed(let error):
            return .failed(.storeKitError(error))
        }
    }
}

