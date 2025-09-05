//
//  FamilyView.swift
//  shigodeki
//
//  [Pattern Propagation] Pure Presentation Layer - Business Logic delegated to FamilyViewModel
//  Created by Claude on 2025-09-01.
//

import SwiftUI
import Combine

struct FamilyView: View {
    // [Pattern Propagation] Pure Presentation Layer
    @EnvironmentObject var sharedManagers: SharedManagerStore
    // 🚨 CTO修正: ViewModelをEnvironmentObjectとして受け取る
    @EnvironmentObject var viewModel: FamilyViewModel
    
    // UI State - Only presentation concerns
    @State private var showingCreateFamily = false
    @State private var showingJoinFamily = false
    @State private var navigationResetId = UUID()
    
    // Duplicate prevention
    @State private var lastCreateTap: Date?
    @State private var lastJoinTap: Date?
    private let tapCooldownSeconds: TimeInterval = 2.0
    
    // DEBUG: Simple test alert to verify alert display functionality
    @State private var showSimpleTestAlert = false

    var body: some View {
        // 🚨 CTO Requirement: This is the correct, standard implementation for NavigationSplitView.
        NavigationSplitView {
            // MARK: - Sidebar
            // The sidebar is ONLY for selection.
            sidebarView
                .navigationTitle("家族")
                .toolbar {
                    // Global actions like "Create" belong on the sidebar.
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button(action: createFamilyWithCooldown) {
                            Label("家族を作成", systemImage: "plus")
                        }
                        .disabled(viewModel.isCreatingFamily || isCreateCooldownActive())
                        .accessibilityIdentifier("create_family_button")
                        
                        Button(action: joinFamilyWithCooldown) {
                            Label("家族に参加", systemImage: "person.badge.plus")
                        }
                        .disabled(viewModel.isJoiningFamily || isJoinCooldownActive())
                    }
                }
        } detail: {
            // MARK: - Detail
            // The detail pane shows the content of the selection, or a placeholder.
            NavigationStack {
                if let selectedFamily = viewModel.selectedFamily {
                    FamilyDetailView(family: selectedFamily)
                } else {
                    placeholderView
                }
            }
        }
        .navigationSplitViewStyle(.balanced) // Ensures sidebar is visible on iPad launch
        .onAppear { Task { await viewModel.onAppear() } }
        .onDisappear {
            viewModel.onDisappear()
        }
        .sheet(isPresented: $showingCreateFamily) {
            CreateFamilyView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingJoinFamily) {
            JoinFamilyView(viewModel: viewModel)
        }
        .modifier(AlertModifiers(viewModel: viewModel, showSimpleTestAlert: $showSimpleTestAlert))
    }

    // MARK: - View Components
    
    @ViewBuilder
    private var sidebarView: some View {
        // The sidebar's state is derived directly from the ViewModel.
        if viewModel.isLoading {
            ProgressView("ユーザー情報を取得中...")
        } else if viewModel.families.isEmpty {
            Text("家族グループがありません")
                .foregroundColor(.secondary)
        } else {
            // The List's selection is bound to the ViewModel's selectedFamily property.
            // This is the core of the master-detail interface.
            List(selection: $viewModel.selectedFamily) {
                ForEach(viewModel.families) { family in
                    FamilyRowView(family: family)
                        .tag(family) // The tag MUST match the selection type.
                }
            }
        }
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("家族を選択してください")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Private Methods
    
    private func createFamilyWithCooldown() {
        print("🔄 [DEBUG] Create family button tapped with cooldown check")
        
        guard !isCreateCooldownActive() else {
            print("⚠️ [DEBUG] Create family button ignored - cooldown active")
            return
        }
        
        lastCreateTap = Date()
        showingCreateFamily = true
    }
    
    private func joinFamilyWithCooldown() {
        print("🔄 [DEBUG] Join family button tapped with cooldown check")
        
        guard !isJoinCooldownActive() else {
            print("⚠️ [DEBUG] Join family button ignored - cooldown active")
            return
        }
        
        lastJoinTap = Date()
        showingJoinFamily = true
    }
    
    private func isCreateCooldownActive() -> Bool {
        guard let lastTap = lastCreateTap else { return false }
        return Date().timeIntervalSince(lastTap) < tapCooldownSeconds
    }
    
    private func isJoinCooldownActive() -> Bool {
        guard let lastTap = lastJoinTap else { return false }
        return Date().timeIntervalSince(lastTap) < tapCooldownSeconds
    }
    
}

// MARK: - Alert Modifiers

struct AlertModifiers: ViewModifier {
    @ObservedObject var viewModel: FamilyViewModel
    @Binding var showSimpleTestAlert: Bool
    
    func body(content: Content) -> some View {
        content
            .alert("テストアラート", isPresented: $showSimpleTestAlert) {
                Button("OK") {
                    print("✅ [DEBUG] Simple test alert dismissed successfully")
                }
                Button("処理中アラートテスト") {
                    print("🧪 [DEBUG] Debug test button - create processing alert test")
                }
                Button("参加アラートテスト") {
                    print("🧪 [DEBUG] Debug test button - join processing alert test")
                }
            } message: {
                Text("アラート表示テスト\n各ボタンで処理フローをテストできます")
            }
            .alert("エラー", isPresented: errorBinding) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                } else {
                    Text("不明なエラーが発生しました")
                }
            }
            .alert(
                viewModel.showCreateSuccess == true ? "作成成功" : "作成処理中",
                isPresented: createProcessingBinding
            ) {
                if viewModel.showCreateSuccess == true {
                    Button("OK") {
                        print("✅ [DEBUG] Create success OK pressed")
                        viewModel.dismissCreateSheetWithReload()
                        viewModel.resetSuccessStates()
                    }
                }
            } message: {
                if !viewModel.processingMessage.isEmpty {
                    Text(viewModel.processingMessage)
                } else if viewModel.showCreateSuccess == true {
                    Text("家族グループが作成されました！")
                } else {
                    Text("家族グループを作成中...")
                }
            }
            .alert(
                viewModel.showJoinSuccess == true ? "参加成功" : "参加処理中",
                isPresented: joinProcessingBinding
            ) {
                if viewModel.showJoinSuccess == true {
                    Button("OK") {
                        print("✅ [DEBUG] Join success OK pressed")
                        viewModel.dismissJoinViewWithReload()
                        viewModel.resetSuccessStates()
                    }
                }
            } message: {
                if !viewModel.joinSuccessMessage.isEmpty {
                    Text(viewModel.joinSuccessMessage)
                } else if viewModel.showJoinSuccess == true {
                    Text("家族グループに参加しました！")
                } else {
                    Text("家族グループに参加中...")
                }
            }
    }
    
    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.error != nil },
            set: { _ in viewModel.clearError() }
        )
    }
    
    private var createProcessingBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.showCreateProcessing || viewModel.showCreateSuccess
            },
            set: { _ in }
        )
    }
    
    private var joinProcessingBinding: Binding<Bool> {
        Binding(
            get: { 
                let show = viewModel.showJoinProcessing == true
                print("🔍 [DEBUG] Join alert isPresented getter called: \(show)")
                return show
            },
            set: { newValue in 
                print("🔍 [DEBUG] Join alert isPresented setter called with: \(newValue)")
                if !newValue {
                    viewModel.resetSuccessStates()
                }
            }
        )
    }
}

// MARK: - Supporting Views (Temporary - Should be moved to separate files)

struct FamilyRowView: View {
    let family: Family
    
    var body: some View {
        HStack {
            Text(family.name.prefix(1))
                .font(.title3)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(family.name)
                    .font(.headline)
                
                Text("\(family.members.count)人のメンバー")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                if let createdAt = family.createdAt {
                    Text("作成日: \(DateFormatter.shortDate.string(from: createdAt))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
