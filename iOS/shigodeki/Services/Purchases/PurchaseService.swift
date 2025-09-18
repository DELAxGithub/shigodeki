//
//  PurchaseService.swift
//  shigodeki
//
//  StoreKit 2 purchasing infrastructure.
//

import Foundation

#if canImport(StoreKit)
import StoreKit
#endif

enum PurchaseResult: Equatable {
    case success(verified: Bool)
    case userCancelled
    case pending
    case failed(Error)

    static func == (lhs: PurchaseResult, rhs: PurchaseResult) -> Bool {
        switch (lhs, rhs) {
        case let (.success(l), .success(r)):
            return l == r
        case (.userCancelled, .userCancelled), (.pending, .pending):
            return true
        case let (.failed(le), .failed(re)):
            return (le as NSError).domain == (re as NSError).domain && (le as NSError).code == (re as NSError).code
        default:
            return false
        }
    }
}

enum PurchaseServiceError: Error {
    case productNotFound
    case unknown
}

#if canImport(StoreKit)
@available(iOS 15.0, *)
protocol PurchaseServicing: AnyObject {
    func products(for ids: [String]) async throws -> [Product]
    func purchase(productID: String) async -> PurchaseResult
    func listenForTransactions(handler: @escaping (VerificationResult<Transaction>) async -> Void) -> Task<Void, Never>
    func currentEntitlements() async -> [VerificationResult<Transaction>]
}

@available(iOS 15.0, *)
final class StoreKitPurchaseService: PurchaseServicing {
    func products(for ids: [String]) async throws -> [Product] {
        guard !ids.isEmpty else { return [] }
        return try await Product.products(for: ids)
    }

    func purchase(productID: String) async -> PurchaseResult {
        do {
            let matchingProducts = try await Product.products(for: [productID])
            guard let product = matchingProducts.first else {
                return .failed(PurchaseServiceError.productNotFound)
            }

            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return .success(verified: true)
                case .unverified(let transaction, let error):
                    await transaction.finish()
                    print("⚠️ StoreKitPurchaseService: Unverified transaction for productID=\(transaction.productID). error=\(String(describing: error))")
                    return .success(verified: false)
                }
            case .userCancelled:
                return .userCancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed(PurchaseServiceError.unknown)
            }
        } catch {
            print("❌ StoreKitPurchaseService: purchase failed for productID=\(productID). error=\(error)")
            return .failed(error)
        }
    }

    func listenForTransactions(handler: @escaping (VerificationResult<Transaction>) async -> Void) -> Task<Void, Never> {
        Task.detached {
            for await update in Transaction.updates {
                await handler(update)
                await self.finishIfNeeded(for: update)
            }
        }
    }

    func currentEntitlements() async -> [VerificationResult<Transaction>] {
        var results: [VerificationResult<Transaction>] = []
        for await entitlement in Transaction.currentEntitlements {
            results.append(entitlement)
        }
        return results
    }

    private func finishIfNeeded(for verification: VerificationResult<Transaction>) async {
        switch verification {
        case .verified(let transaction):
            await transaction.finish()
        case .unverified(let transaction, _):
            await transaction.finish()
        }
    }
}
#endif

