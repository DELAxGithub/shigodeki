//
//  EntitlementStore.swift
//  shigodeki
//
//  In-memory entitlement cache fed by StoreKit transactions.
//

import Foundation

#if canImport(StoreKit)
import StoreKit

@available(iOS 15.0, *)
@MainActor
final class EntitlementStore: ObservableObject {
    @Published private(set) var entitlements: Entitlements = .empty

    private let purchaseService: PurchaseServicing
    private var listenerTask: Task<Void, Never>?
    private var refreshInProgress = false

    init(purchaseService: PurchaseServicing) {
        self.purchaseService = purchaseService
    }

    deinit {
        listenerTask?.cancel()
    }

    func start() {
        guard listenerTask == nil else { return }

        listenerTask = purchaseService.listenForTransactions { [weak self] verification in
            guard let self else { return }
            await self.handle(transactionUpdate: verification)
        }

        Task { [weak self] in
            await self?.refresh()
        }
    }

    func stop() {
        listenerTask?.cancel()
        listenerTask = nil
    }

    func refresh() async {
        if refreshInProgress { return }
        refreshInProgress = true
        defer { refreshInProgress = false }

        let results = await purchaseService.currentEntitlements()

        var isPro = false
        var ownedTemplates: Set<TemplateID> = []

        for result in results {
            switch result {
            case .verified(let transaction):
                map(transaction: transaction, isPro: &isPro, ownedTemplates: &ownedTemplates)
            case .unverified(let transaction, let error):
                print("⚠️ EntitlementStore: Unverified entitlement for productID=\(transaction.productID). error=\(String(describing: error))")
            }
        }

        entitlements = Entitlements(isPro: isPro, ownedTemplates: ownedTemplates, updatedAt: Date())
    }

    private func handle(transactionUpdate verification: VerificationResult<Transaction>) async {
        switch verification {
        case .verified(let transaction):
            print("ℹ️ EntitlementStore: Received verified transaction for productID=\(transaction.productID)")
        case .unverified(let transaction, let error):
            print("⚠️ EntitlementStore: Received unverified transaction for productID=\(transaction.productID). error=\(String(describing: error))")
        }

        await refresh()
    }

    private func map(transaction: Transaction, isPro: inout Bool, ownedTemplates: inout Set<TemplateID>) {
        switch TemplatePriceCatalog.entitlement(for: transaction.productID) {
        case .pro:
            guard transaction.revocationDate == nil else { return }
            isPro = true
        case .template(let templateID):
            guard transaction.revocationDate == nil else { return }
            ownedTemplates.insert(templateID)
        case .unknown:
            break
        }
    }
}
extension EntitlementStore: EntitlementRefreshing {}
#endif
