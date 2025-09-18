//
//  TemplatePaywallView.swift
//  shigodeki
//
//  Minimal paywall stub for template purchases.
//

import SwiftUI
#if canImport(StoreKit)
import StoreKit

@available(iOS 15.0, *)
struct TemplatePaywallView: View {
    enum PurchaseState {
        case idle
        case loading
        case pending
        case success
        case failed(String)
    }

    let template: ProjectTemplate
    let coordinator: TemplatePurchaseCoordinating
    let catalog: PurchaseProductCataloging
    let onUnlocked: () -> Void
    let onCancel: () -> Void

    @Environment(\.proSubscriptionCoordinator) private var proCoordinator
    @Environment(\.purchaseProductCatalog) private var envCatalog
    @Environment(\.entitlementStore) private var entitlementStore

    @State private var priceDisplay: String?
    @State private var purchaseState: PurchaseState = .idle
    @State private var showProPaywall = false
    @State private var proPaywallContext: ProPaywallView.ProPaywallContext?

    private var unlockButtonDisabled: Bool {
        switch purchaseState {
        case .loading, .success: return true
        default: return priceDisplay?.isEmpty != false
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text(template.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    if let description = template.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("全タスクへアクセス", systemImage: "checkmark.seal")
                    Label("ファミリーと共有", systemImage: "person.3")
                    Label("進捗サマリ付き", systemImage: "chart.bar")
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let priceDisplay {
                    Text(priceDisplay)
                        .font(.title2)
                        .fontWeight(.bold)
                } else {
                    ProgressView()
                }

                if case .failed(let message) = purchaseState {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                } else if case .pending = purchaseState {
                    Text("購入処理を確認中です。しばらくお待ちください。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await unlockTemplate() }
                } label: {
                    if case .loading = purchaseState {
                        ProgressView()
                    } else {
                        Text("このテンプレートを解錠する")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(unlockButtonDisabled || priceDisplay == nil)

                Button("キャンセル", role: .cancel) {
                    onCancel()
                }
                .controlSize(.large)

                if shouldShowProUpsell {
                    Divider()
                    VStack(spacing: 12) {
                        Text("Shigodeki PRO でさらに便利に")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Button {
                            if entitlementStore?.entitlements.isPro == true {
                                onUnlocked()
                            } else {
                                proPaywallContext = ProPaywallView.ProPaywallContext(
                                    entryPoint: "template_paywall",
                                    identifier: template.id
                                )
                                showProPaywall = true
                            }
                        } label: {
                            Text("PROですべて解錠")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("テンプレートを解錠")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadPrice()
        }
        .sheet(isPresented: $showProPaywall) {
            if #available(iOS 15.0, *),
               let proCoordinator {
                ProPaywallView(
                    coordinator: proCoordinator,
                    catalog: envCatalog ?? catalog,
                    context: proPaywallContext ?? ProPaywallView.ProPaywallContext(entryPoint: "template_paywall", identifier: template.id),
                    onUnlocked: { _ in
                        showProPaywall = false
                        proPaywallContext = nil
                        onUnlocked()
                    },
                    onCancel: {
                        showProPaywall = false
                        proPaywallContext = nil
                    }
                )
            } else {
                VStack(spacing: 16) {
                    Text("PRO購読は現在利用できません。")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Button("閉じる") {
                        showProPaywall = false
                    }
                }
                .padding()
            }
        }
        .onChange(of: showProPaywall) { _, newValue in
            if newValue == false {
                proPaywallContext = nil
            }
        }
    }

    private func loadPrice() async {
        guard priceDisplay == nil else { return }
        guard let productID = TemplatePriceCatalog.productID(for: template.id) else {
            priceDisplay = ""
            return
        }

        do {
            if let product = try await catalog.product(for: productID) {
                await MainActor.run {
                    priceDisplay = product.displayPrice
                }
            } else {
                await MainActor.run { priceDisplay = "" }
            }
        } catch {
            print("⚠️ TemplatePaywallView: Failed to load price for \(template.id) - \(error)")
            await MainActor.run { priceDisplay = "" }
        }
    }

    private func unlockTemplate() async {
        guard let productID = TemplatePriceCatalog.productID(for: template.id) else {
            await MainActor.run {
                purchaseState = .failed("商品情報を取得できませんでした。")
            }
            return
        }

        await MainActor.run {
            purchaseState = .loading
        }

        let outcome = await coordinator.buyTemplate(templateID: template.id, productID: productID)

        await MainActor.run {
            switch outcome {
            case .success:
                purchaseState = .success
                onUnlocked()
            case .cancelled:
                purchaseState = .failed("購入がキャンセルされました。")
            case .pending:
                purchaseState = .pending
            case .failed(let error):
                purchaseState = .failed(error.userMessage)
                print("⚠️ TemplatePaywallView: Purchase failed for \(template.id) - \(error)")
            }
        }
    }

    private var shouldShowProUpsell: Bool {
        FeatureFlags.proSubscriptionEnabled && FeatureFlags.purchasesEnabled && proCoordinator != nil && entitlementStore?.entitlements.isPro != true
    }
}

#endif
