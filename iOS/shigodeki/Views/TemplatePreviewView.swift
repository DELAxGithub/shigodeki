//
//  TemplatePreviewView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import SwiftUI
import Combine

struct TemplatePreviewView: View {
    let template: ProjectTemplate
    @Binding var isPresented: Bool
    let onSelect: (ProjectTemplate) -> Void
    private let entitlementResolver: TemplateEntitlementResolving
    @Environment(\.entitlementStore) private var entitlementStore
    @Environment(\.templatePurchaseCoordinator) private var templatePurchaseCoordinator
    @Environment(\.purchaseProductCatalog) private var purchaseProductCatalog
    @State private var entitlementsSnapshot = Entitlements.empty
    @State private var showPaywall = false
    @State private var pendingUnlockAction: TemplateUnlockAction?
    
    @State private var selectedPhaseIndex = 0
    @State private var showCustomizationSheet = false
    @State private var customizations = ProjectCustomizations()
    @State private var projectName = ""

    private var stats: TemplateStats {
        TemplateStats(template: template)
    }

    init(
        template: ProjectTemplate,
        isPresented: Binding<Bool>,
        entitlementResolver: TemplateEntitlementResolving,
        onSelect: @escaping (ProjectTemplate) -> Void
    ) {
        self.template = template
        self._isPresented = isPresented
        self.entitlementResolver = entitlementResolver
        self.onSelect = onSelect
    }

    private var shouldApplyMonetization: Bool {
        FeatureFlags.templateIAPEnabled && TemplateMonetizationCatalog.isPaid(template)
    }

    private var isTemplateLocked: Bool {
        guard shouldApplyMonetization else { return false }
        guard FeatureFlags.purchasesEnabled else { return true }
        let _ = entitlementsSnapshot.updatedAt
        return !entitlementResolver.isUnlocked(templateID: template.id)
    }

    private var teaserConfig: TemplateTeaserConfig? {
        isTemplateLocked ? TemplateMonetizationCatalog.teaserConfiguration(for: template) : nil
    }

    var body: some View {
        NavigationView {
            ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            TemplateHeaderSection(template: template)
            TemplateStatisticsSection(stats: stats)
            PhasesPreviewSection(
                template: template,
                        selectedPhaseIndex: $selectedPhaseIndex,
                        teaserConfig: teaserConfig,
                        isLocked: isTemplateLocked
                    )
                    TemplateDetailsSection(template: template)
                    TemplateMetadataSection(template: template)
                }
                .padding()
            }
            .navigationTitle("テンプレートプレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    isPresented = false
                },
                trailing: Menu {
                    TemplatePreviewMenu(
                        template: template,
                        onShare: shareTemplate,
                        onExport: exportTemplate,
                        onSelect: { handleTemplateSelection(customize: false) },
                        onCustomize: { handleTemplateSelection(customize: true) }
                    )
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            )
        }
        .onAppear {
            projectName = template.name
            if let store = entitlementStore {
                entitlementsSnapshot = store.entitlements
            }
        }
        .onReceive(entitlementStore?.$entitlements.eraseToAnyPublisher() ?? Just(Entitlements.empty).eraseToAnyPublisher()) { value in
            entitlementsSnapshot = value
        }
        .sheet(isPresented: $showCustomizationSheet) {
            TemplateEditorView(
                template: template,
                onSave: { customizedTemplate in
                    onSelect(customizedTemplate)
                    isPresented = false
                }
            )
        }
        .sheet(isPresented: $showPaywall) {
            if #available(iOS 15.0, *),
               let coordinator = templatePurchaseCoordinator,
               let catalog = purchaseProductCatalog,
               let action = pendingUnlockAction {
                TemplatePaywallView(
                    template: template,
                    coordinator: coordinator,
                    catalog: catalog,
                    onUnlocked: {
                        dismissPaywall()
                        applySelection(customize: action == .customize)
                    },
                    onCancel: {
                        dismissPaywall()
                    }
                )
            } else {
                VStack(spacing: 16) {
                    Text("テンプレートを解錠するには最新環境が必要です。")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Button("閉じる") {
                        dismissPaywall()
                    }
                }
                .padding()
            }
        }
        .onChange(of: showPaywall) { _, newValue in
            if !newValue {
                pendingUnlockAction = nil
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleTemplateSelection(customize: Bool) {
        guard isTemplateLocked else {
            applySelection(customize: customize)
            return
        }

        guard FeatureFlags.templateIAPEnabled else {
            print("ℹ️ TemplatePreviewView: templateIAPEnabled is false; skipping paywall")
            applySelection(customize: customize)
            return
        }

        guard FeatureFlags.purchasesEnabled else {
            print("ℹ️ TemplatePreviewView: purchases disabled; cannot unlock template")
            return
        }

        guard templatePurchaseCoordinator != nil, purchaseProductCatalog != nil else {
            print("⚠️ TemplatePreviewView: Purchase dependencies unavailable")
            return
        }

        pendingUnlockAction = customize ? .customize : .use
        showPaywall = true
    }

    private func applySelection(customize: Bool) {
        if customize {
            showCustomizationSheet = true
        } else {
            onSelect(template)
            isPresented = false
        }
    }

    private func dismissPaywall() {
        showPaywall = false
        pendingUnlockAction = nil
    }

    private func shareTemplate() {
        // テンプレート共有機能（将来実装）
    }
    
    private func exportTemplate() {
        // テンプレートエクスポート機能（将来実装）
    }
}

enum TemplateUnlockAction {
    case use
    case customize
}

#Preview {
    @Previewable @State var isPresented = true
    TemplatePreviewView(
        template: ProjectTemplate.sampleTemplate,
        isPresented: $isPresented,
        entitlementResolver: DefaultTemplateEntitlementResolver.shared
    ) { _ in
        // Sample action
    }
}
