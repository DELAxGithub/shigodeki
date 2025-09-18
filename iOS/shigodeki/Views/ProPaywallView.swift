//
//  ProPaywallView.swift
//  shigodeki
//
//  Minimal paywall stub for PRO subscription.
//

import SwiftUI
#if canImport(StoreKit)
import StoreKit
import Combine

@available(iOS 15.0, *)
struct ProPaywallView: View {
    struct ProPaywallContext: Equatable {
        let entryPoint: String
        let identifier: String?

        var telemetryOption: String { entryPoint }
        var telemetryContext: String? { identifier }
    }

    enum Plan: String, CaseIterable, Identifiable {
        case monthly
        case yearly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .monthly: return "月額プラン"
            case .yearly: return "年額プラン"
            }
        }

        var subtitle: String {
            switch self {
            case .monthly: return "毎月更新／いつでも解約可能"
            case .yearly: return "年額一括／実質2ヶ月分お得"
            }
        }

        var productID: String {
            switch self {
            case .monthly: return TemplatePriceCatalog.proMonthlyProductID
            case .yearly: return TemplatePriceCatalog.proYearlyProductID
            }
        }
    }

    enum PriceLoadState {
        case loading
        case loaded
        case failed
    }

    enum PurchaseState: Equatable {
        case idle
        case loading
        case pending
        case success
        case cancelled
        case failed(PurchaseFlowError)
    }

    let coordinator: ProSubscriptionCoordinating
    let catalog: PurchaseProductCataloging
    let context: ProPaywallContext
    let onUnlocked: (ProPaywallContext) -> Void
    let onCancel: () -> Void

    @Environment(\.entitlementStore) private var entitlementStore

    @State private var selectedPlan: Plan = .monthly
    @State private var monthlyPrice: String?
    @State private var yearlyPrice: String?
    @State private var priceState: PriceLoadState = .loading
    @State private var purchaseState: PurchaseState = .idle
    @State private var didLogAppear = false
    @State private var didNotifyUnlock = false

    private var entitlementPublisher: AnyPublisher<Entitlements, Never> {
        if let store = entitlementStore {
            return store.$entitlements.eraseToAnyPublisher()
        }
        return Just(entitlementStore?.entitlements ?? .empty).eraseToAnyPublisher()
    }

    private var currentPrice: String? {
        switch selectedPlan {
        case .monthly: return monthlyPrice
        case .yearly: return yearlyPrice
        }
    }

    private var unlockButtonDisabled: Bool {
        switch purchaseState {
        case .loading, .pending, .success:
            return true
        default:
            return currentPrice == nil || priceState == .loading || !isPaywallAvailable
        }
    }

    private var isPaywallAvailable: Bool {
        FeatureFlags.purchasesEnabled && FeatureFlags.proSubscriptionEnabled
    }

    private var statusMessage: (text: String, isError: Bool)? {
        switch purchaseState {
        case .cancelled:
            return (NSLocalizedString("pro.paywall.message.cancelled", tableName: nil, bundle: .main, value: "購入がキャンセルされました。", comment: "Shown when subscription purchase was cancelled"), true)
        case .pending:
            return (NSLocalizedString("pro.paywall.message.pending", tableName: nil, bundle: .main, value: "購入処理を確認中です。しばらくお待ちください。", comment: "Shown while purchase is pending"), false)
        case .failed(let error):
            return (failureMessage(for: error), true)
        default:
            return nil
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text(NSLocalizedString("pro.paywall.title", tableName: nil, bundle: .main, value: "Shigodeki PRO", comment: "Title for PRO paywall"))
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(NSLocalizedString("pro.paywall.subtitle", tableName: nil, bundle: .main, value: "テンプレートとAIを使い放題", comment: "Subtitle describing PRO benefits"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Picker("プラン", selection: $selectedPlan) {
                    ForEach(Plan.allCases) { plan in
                        Text(plan.title).tag(plan)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("ProPaywall.PlanPicker")

                Text(selectedPlan.subtitle)
                    .font(.footnote)
                    .foregroundColor(.secondary)

                if priceState == .loading {
                    ProgressView()
                        .accessibilityIdentifier("ProPaywall.PriceLoading")
                } else if let price = currentPrice {
                    Text(price)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .accessibilityIdentifier("ProPaywall.PriceLabel")
                } else {
                    VStack(spacing: 8) {
                        Text(NSLocalizedString("pro.paywall.price_error", tableName: nil, bundle: .main, value: "価格を取得できませんでした。", comment: "Shown when price load fails"))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button {
                            Task { await loadPrices(force: true) }
                            Telemetry.fire(
                                .onProPriceRetry,
                                TelemetryPayload(screen: "ProPaywall", option: context.telemetryOption, context: context.telemetryContext)
                            )
                        } label: {
                            Text(NSLocalizedString("pro.paywall.price_retry", tableName: nil, bundle: .main, value: "価格を再読み込み", comment: "Retry button when price fetch fails"))
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("ProPaywall.PriceRetry")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label(NSLocalizedString("pro.paywall.benefit.templates", tableName: nil, bundle: .main, value: "全テンプレート解放", comment: "Benefit bullet for templates"), systemImage: "checkmark.circle")
                    Label(NSLocalizedString("pro.paywall.benefit.ai", tableName: nil, bundle: .main, value: "AI分解・改善が使い放題", comment: "Benefit bullet for AI"), systemImage: "sparkles")
                    Label(NSLocalizedString("pro.paywall.benefit.family", tableName: nil, bundle: .main, value: "家族で共有・共同編集", comment: "Benefit bullet for family sharing"), systemImage: "person.3")
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let message = statusMessage {
                    Text(message.text)
                        .font(.footnote)
                        .foregroundColor(message.isError ? .red : .secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await unlockPro() }
                } label: {
                    if purchaseState == .loading {
                        ProgressView()
                            .accessibilityIdentifier("ProPaywall.PurchaseProgress")
                    } else if purchaseState == .pending {
                        Text(NSLocalizedString("pro.paywall.cta.pending", tableName: nil, bundle: .main, value: "確認中...", comment: "CTA label while pending"))
                            .fontWeight(.semibold)
                    } else {
                        Text(NSLocalizedString("pro.paywall.cta", tableName: nil, bundle: .main, value: "PROで解錠する", comment: "CTA to unlock PRO"))
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(unlockButtonDisabled)
                .accessibilityIdentifier("ProPaywall.CTA")
                .accessibilityLabel(NSLocalizedString("pro.paywall.cta.accessibility", tableName: nil, bundle: .main, value: "PRO購読を開始", comment: "Accessibility label for purchase CTA"))

                if !isPaywallAvailable {
                    Text(NSLocalizedString("pro.paywall.flags_disabled", tableName: nil, bundle: .main, value: "現在PRO購読を開始できません。時間を置いてお試しください。", comment: "Shown when feature flags disable paywall"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(NSLocalizedString("pro.paywall.cancel", tableName: nil, bundle: .main, value: "あとで検討", comment: "Cancel button title"), role: .cancel) {
                    onCancel()
                }
                .controlSize(.large)
                .accessibilityIdentifier("ProPaywall.Cancel")

                Spacer()
            }
            .padding()
            .navigationTitle(NSLocalizedString("pro.paywall.nav", tableName: nil, bundle: .main, value: "Shigodeki PRO", comment: "Navigation title for PRO paywall"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadPrices(force: false)
        }
        .task {
            await handleInitialEntitlementState()
        }
        .onReceive(entitlementPublisher) { entitlements in
            guard entitlements.isPro else { return }
            notifyUnlockIfNeeded()
        }
    }

    private func loadPrices(force: Bool) async {
        guard isPaywallAvailable else {
            await MainActor.run {
                priceState = .failed
            }
            return
        }
        if priceState == .loaded && !force { return }

        await MainActor.run {
            priceState = .loading
        }

        do {
            let products = try await catalog.products(for: Plan.allCases.map(\.productID))
            await MainActor.run {
                for product in products {
                    switch product.id {
                    case Plan.monthly.productID:
                        monthlyPrice = product.displayPrice
                    case Plan.yearly.productID:
                        yearlyPrice = product.displayPrice
                    default:
                        break
                    }
                }
                priceState = .loaded
            }
        } catch {
            Telemetry.fire(
                .onProPurchaseResult,
                TelemetryPayload(
                    screen: "ProPaywall",
                    option: context.telemetryOption,
                    reason: "price_load_failed",
                    context: context.telemetryContext
                )
            )
            print("⚠️ ProPaywallView: Failed to load prices - \(error)")
            await MainActor.run {
                priceState = .failed
                monthlyPrice = nil
                yearlyPrice = nil
            }
        }
    }

    private func unlockPro() async {
        guard isPaywallAvailable else { return }
        await MainActor.run {
            purchaseState = .loading
        }

        let outcome = await coordinator.buyPro(productID: selectedPlan.productID)
        logPurchaseOutcome(outcome)

        await MainActor.run {
            switch outcome {
            case .success:
                purchaseState = .success
                notifyUnlockIfNeeded()
            case .cancelled:
                purchaseState = .cancelled
            case .pending:
                purchaseState = .pending
            case .failed(let error):
                purchaseState = .failed(error)
                print("⚠️ ProPaywallView: Purchase failed (plan: \(selectedPlan.rawValue)) - \(error)")
            }
        }
    }

    private func handleInitialEntitlementState() async {
        if !didLogAppear {
            didLogAppear = true
            Telemetry.fire(
                .onProPaywallShown,
                TelemetryPayload(screen: "ProPaywall", option: context.telemetryOption, context: context.telemetryContext)
            )
        }

        if entitlementStore?.entitlements.isPro == true {
            await MainActor.run {
                notifyUnlockIfNeeded()
            }
        }
    }

    private func notifyUnlockIfNeeded() {
        guard didNotifyUnlock == false else { return }
        didNotifyUnlock = true
        onUnlocked(context)
    }

    private func logPurchaseOutcome(_ outcome: PurchaseOutcome) {
        let reason: String
        switch outcome {
        case .success:
            reason = "success"
        case .cancelled:
            reason = "cancelled"
        case .pending:
            reason = "pending"
        case .failed(let error):
            switch error {
            case .purchasesDisabled:
                reason = "failed_purchases_disabled"
            case .storeKitError:
                reason = "failed_storekit"
            case .unknown:
                reason = "failed_unknown"
            }
        }

        Telemetry.fire(
            .onProPurchaseResult,
            TelemetryPayload(
                screen: "ProPaywall",
                option: selectedPlan.rawValue,
                reason: reason,
                context: context.telemetryContext
            )
        )
    }

    private func failureMessage(for error: PurchaseFlowError) -> String {
        switch error {
        case .purchasesDisabled:
            return NSLocalizedString("pro.paywall.error.disabled", tableName: nil, bundle: .main, value: "現在購入は利用できません。", comment: "Shown when purchases are disabled")
        case .storeKitError:
            return NSLocalizedString("pro.paywall.error.storekit", tableName: nil, bundle: .main, value: "購入に失敗しました。時間を置いて再試行してください。", comment: "Generic StoreKit failure message")
        case .unknown:
            return NSLocalizedString("pro.paywall.error.unknown", tableName: nil, bundle: .main, value: "不明なエラーが発生しました。", comment: "Unknown error message")
        }
    }
}

#endif
