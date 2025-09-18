//
//  TemplateLibraryView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import SwiftUI
import Combine

struct TemplateLibraryView: View {
    @StateObject private var templateManager = TemplateManager()
    
    @Binding var isPresented: Bool
    @Binding var selectedTemplate: ProjectTemplate?
    private let entitlementResolver: TemplateEntitlementResolving
    @Environment(\.entitlementStore) private var entitlementStore
    @Environment(\.templatePurchaseCoordinator) private var templatePurchaseCoordinator
    @Environment(\.purchaseProductCatalog) private var purchaseProductCatalog
    @State private var entitlementsSnapshot = Entitlements.empty

    @State private var selectedCategory: TemplateCategory? = nil
    @State private var searchText = ""
    @State private var showFilePicker = false
    @State private var showTemplatePreview = false
    @State private var previewTemplate: ProjectTemplate?
    @State private var sortOption: TemplateFilterService.SortOption = .name
    @State private var showTemplatePaywall = false
    @State private var paywallTemplate: ProjectTemplate?

    init(
        isPresented: Binding<Bool>,
        selectedTemplate: Binding<ProjectTemplate?>,
        entitlementResolver: TemplateEntitlementResolving
    ) {
        self._isPresented = isPresented
        self._selectedTemplate = selectedTemplate
        self.entitlementResolver = entitlementResolver
    }
    
    var filteredTemplates: [ProjectTemplate] {
        TemplateFilterService.filterAndSort(
            templates: templateManager.allTemplates,
            selectedCategory: selectedCategory,
            searchText: searchText,
            sortOption: sortOption
        )
    }

    private var activeResolver: TemplateEntitlementResolving {
        FeatureFlags.purchasesEnabled ? entitlementResolver : DefaultTemplateEntitlementResolver.shared
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search & Filter Section
                searchAndFilterSection
                
                // Category Filter
                if selectedCategory == nil {
                    categoryFilterSection
                }
                
                // Template List
                templateListSection
            }
            .navigationTitle("テンプレートライブラリ")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    isPresented = false
                },
                trailing: Menu {
                    menuContent
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            )
        }
        .sheet(isPresented: $showFilePicker) {
            TemplateFilePickerView(
                isPresented: $showFilePicker,
                selectedTemplate: $selectedTemplate
            )
        }
        .sheet(isPresented: $showTemplatePreview) {
            if let template = previewTemplate {
                TemplatePreviewView(
                    template: template,
                    isPresented: $showTemplatePreview,
                    entitlementResolver: activeResolver
                ) { selectedTemplate in
                    self.selectedTemplate = selectedTemplate
                    isPresented = false
                }
                .environment(\.entitlementStore, entitlementStore)
            }
        }
        .sheet(isPresented: $showTemplatePaywall) {
            if #available(iOS 15.0, *),
               let template = paywallTemplate,
               let coordinator = templatePurchaseCoordinator,
               let catalog = purchaseProductCatalog {
                TemplatePaywallView(
                    template: template,
                    coordinator: coordinator,
                    catalog: catalog,
                    onUnlocked: {
                        showTemplatePaywall = false
                        paywallTemplate = nil
                        selectedTemplate = template
                        isPresented = false
                    },
                    onCancel: {
                        showTemplatePaywall = false
                        paywallTemplate = nil
                    }
                )
            } else {
                VStack(spacing: 16) {
                    Text("テンプレートの購入は現在利用できません。")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Button("閉じる") {
                        showTemplatePaywall = false
                        paywallTemplate = nil
                    }
                }
                .padding()
            }
        }
        .onAppear {
            templateManager.loadBuiltInTemplates()
            if let store = entitlementStore {
                entitlementsSnapshot = store.entitlements
            }
        }
        .onReceive(entitlementStore?.$entitlements.eraseToAnyPublisher() ?? Just(Entitlements.empty).eraseToAnyPublisher()) { value in
            entitlementsSnapshot = value
        }
        .onChange(of: showTemplatePaywall) { _, newValue in
            if !newValue {
                paywallTemplate = nil
            }
        }
    }
    
    // MARK: - View Components
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("テンプレートを検索...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
                
                Menu {
                    ForEach(TemplateFilterService.SortOption.allCases, id: \.rawValue) { option in
                        Button {
                            sortOption = option
                        } label: {
                            Label(option.rawValue, systemImage: option.systemImage)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                        )
                }
            }
            
            if selectedCategory != nil {
                HStack {
                    Text("カテゴリ: \(selectedCategory?.displayName ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("すべて表示") {
                        selectedCategory = nil
                    }
                    .font(.caption)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TemplateCategory.allCases, id: \.rawValue) { category in
                    FilterChip(
                        title: category.displayName,
                        systemImage: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var templateListSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if filteredTemplates.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredTemplates, id: \.id) { template in
                        let _ = entitlementsSnapshot.updatedAt
                        let badge = TemplateMonetizationCatalog.badge(for: template, resolver: activeResolver)
                        TemplateCard(
                            template: template,
                            monetizationBadge: badge,
                            onTap: {
                                previewTemplate = template
                                showTemplatePreview = true
                            },
                            onPreview: {
                                previewTemplate = template
                                showTemplatePreview = true
                            },
                            onSelect: {
                                handleDirectSelection(template)
                            }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("テンプレートが見つかりませんでした")
                .font(.headline)
                .fontWeight(.medium)
            
            Text("検索条件を変更するか、カスタムテンプレートをインポートしてください")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("ファイルをインポート") {
                showFilePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 60)
    }
    
    private var menuContent: some View {
        Group {
            Button {
                showFilePicker = true
            } label: {
                Label("ファイルをインポート", systemImage: "square.and.arrow.down")
            }
            
            Button {
                templateManager.refreshTemplates()
            } label: {
                Label("更新", systemImage: "arrow.clockwise")
            }
            
            Button {
                // Export functionality could be added here
            } label: {
                Label("エクスポート", systemImage: "square.and.arrow.up")
            }
        }
    }
}

private extension TemplateLibraryView {
    func handleDirectSelection(_ template: ProjectTemplate) {
        if shouldPresentPaywall(for: template),
           templatePurchaseCoordinator != nil,
           purchaseProductCatalog != nil,
           #available(iOS 15.0, *) {
            paywallTemplate = template
            showTemplatePaywall = true
        } else {
            selectedTemplate = template
            isPresented = false
        }
    }

    func shouldPresentPaywall(for template: ProjectTemplate) -> Bool {
        guard FeatureFlags.templateIAPEnabled,
              FeatureFlags.purchasesEnabled,
              TemplateMonetizationCatalog.isPaid(template) else { return false }
        return !TemplateMonetizationCatalog.hasEntitlement(for: template, resolver: activeResolver)
    }
}

// MARK: - Preview

struct TemplateLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        TemplateLibraryView(
            isPresented: .constant(true),
            selectedTemplate: .constant(nil),
            entitlementResolver: DefaultTemplateEntitlementResolver.shared
        )
    }
}
