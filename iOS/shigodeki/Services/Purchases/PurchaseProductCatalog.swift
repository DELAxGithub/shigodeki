//
//  PurchaseProductCatalog.swift
//  shigodeki
//
//  Caches StoreKit product metadata for reuse.
//

import Foundation
#if canImport(StoreKit)
import StoreKit

@available(iOS 15.0, *)
final class PurchaseProductCatalog {
    private let purchaseService: PurchaseServicing
    private var cache: [String: Product] = [:]

    init(purchaseService: PurchaseServicing) {
        self.purchaseService = purchaseService
    }

    func products(for ids: [String]) async throws -> [Product] {
        guard !ids.isEmpty else { return [] }

        let missingIDs = ids.filter { cache[$0] == nil }
        if !missingIDs.isEmpty {
            let fetched = try await purchaseService.products(for: missingIDs)
            for product in fetched {
                cache[product.id] = product
            }
        }

        return ids.compactMap { cache[$0] }
    }

    func product(for id: String) async throws -> Product? {
        if let cached = cache[id] {
            return cached
        }
        let products = try await products(for: [id])
        return products.first
    }
}

@available(iOS 15.0, *)
extension PurchaseProductCatalog: PurchaseProductCataloging {}
#endif
