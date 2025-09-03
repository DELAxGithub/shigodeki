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

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: Use NavigationSplitView
            NavigationSplitView {
                sidebarContent
            } detail: {
                detailContent
            }
            .navigationDestination(for: Family.self) { family in
                FamilyDetailView(family: family)
            }
            .id(navigationResetId)
            .onReceive(NotificationCenter.default.publisher(for: .familyTabSelected)) { _ in
                navigationResetId = UUID()
            }
        } else {
            // iPhone: Use standard NavigationView
            NavigationView {
                phoneContent
            }
            .navigationDestination(for: Family.self) { family in
                FamilyDetailView(family: family)
            }
            .id(navigationResetId)
            .onReceive(NotificationCenter.default.publisher(for: .familyTabSelected)) { _ in
                navigationResetId = UUID()
            }
        }
    }
    
    // MARK: - iPhone Content
    
    @ViewBuilder
    private var phoneContent: some View {
        VStack {
            contentView(viewModel: viewModel)
        }
        .navigationTitle("家族")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            phoneToolbarContent
        }
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
        .modifier(AlertModifiers(viewModel: viewModel))
    }
    
    // MARK: - Sidebar Content
    
    @ViewBuilder
    private var sidebarContent: some View {
        let familiesCount = viewModel.families.count
        let isLoading = viewModel.isLoading
        let shouldShowEmptyState = viewModel.shouldShowEmptyState
        let currentUserId = viewModel.authManagerForViews.currentUser?.id
        let isAuthenticated = viewModel.authManagerForViews.isAuthenticated
        
        if currentUserId == nil && isAuthenticated {
            ProgressView("ユーザー情報を取得中...")
                .navigationTitle("家族")
        } else if shouldShowEmptyState || isLoading {
            VStack {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                Text(isLoading ? "読み込み中..." : "家族グループがありません")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("家族")
        } else if familiesCount > 0 {
            List(viewModel.families) { family in
                NavigationLink(value: family) {
                    FamilyRowView(family: family)
                }
                .accessibilityIdentifier("family_\(family.name)")
            }
            .listStyle(.sidebar)
            .navigationTitle("家族")
            .onAppear {
                print("🔍 [DEBUG] Sidebar showing family list with \(familiesCount) families")
                print("📋 [DEBUG] Sidebar families: \(viewModel.families.map { $0.name })")
            }
        } else {
            VStack {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                Text("家族グループがありません")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("家族")
        }
    }
    
    // MARK: - Detail Content
    
    @ViewBuilder
    private var detailContent: some View {
        VStack {
            contentView(viewModel: viewModel)
        }
        .navigationTitle("家族グループ")
        .toolbar {
            toolbarContent
        }
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
        .modifier(AlertModifiers(viewModel: viewModel))
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private var phoneToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button(action: {
                createFamilyWithCooldown()
            }) {
                Label("家族を作成", systemImage: "plus")
            }
            .disabled(viewModel.isCreatingFamily || isCreateCooldownActive())
            .accessibilityIdentifier("create_family_button")
            
            Button {
                joinFamilyWithCooldown()
            } label: {
                Label("家族に参加", systemImage: "person.badge.plus")
            }
            .disabled(viewModel.isJoiningFamily || isJoinCooldownActive())
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: {
                createFamilyWithCooldown()
            }) {
                Label("家族を作成", systemImage: "plus")
            }
            .disabled(viewModel.isCreatingFamily || isCreateCooldownActive())
            .accessibilityIdentifier("create_family_button")
            
            Button {
                joinFamilyWithCooldown()
            } label: {
                Label("家族に参加", systemImage: "person.badge.plus")
            }
            .disabled(viewModel.isJoiningFamily || isJoinCooldownActive())
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func contentView(viewModel: FamilyViewModel) -> some View {
        let familiesCount = viewModel.families.count
        let isLoading = viewModel.isLoading
        let shouldShowEmptyState = viewModel.shouldShowEmptyState
        let currentUserId = viewModel.authManagerForViews.currentUser?.id
        let isAuthenticated = viewModel.authManagerForViews.isAuthenticated
        
        // Debug logging moved to onAppear outside ViewBuilder
        let debugState = "families=\(familiesCount), loading=\(isLoading), empty=\(shouldShowEmptyState), userId=\(currentUserId ?? "nil"), auth=\(isAuthenticated)"
        
        // Wait for auth userId to be available before deciding empty state
        if currentUserId == nil && isAuthenticated {
            ProgressView("ユーザー情報を取得中...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    print("🔍 [DEBUG] ContentView state: \(debugState)")
                    print("🔍 [DEBUG] Showing user info loading view")
                }
        } else if shouldShowEmptyState {
            familyEmptyStateView()
                .onAppear {
                    print("🔍 [DEBUG] ContentView state: \(debugState)")
                    print("🔍 [DEBUG] Showing empty state view")
                }
        } else if isLoading {
            ProgressView("家族グループを読み込み中...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    print("🔍 [DEBUG] ContentView state: \(debugState)")
                    print("🔍 [DEBUG] Showing loading view")
                }
        } else {
            familyListView(viewModel: viewModel)
                .onAppear {
                    print("🔍 [DEBUG] ContentView state: \(debugState)")
                    print("🔍 [DEBUG] Showing family list view with \(familiesCount) families")
                }
        }
    }
    
    @ViewBuilder
    private func familyEmptyStateView() -> some View {
        VStack(spacing: 24) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("家族グループがありません")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("新しい家族グループを作成するか\n招待コードで参加しましょう")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    createFamilyWithCooldown()
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("家族グループを作成")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isCreatingFamily || isCreateCooldownActive())
                .accessibilityIdentifier("create_family_from_empty")
                
                Button(action: {
                    joinFamilyWithCooldown()
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("招待コードで参加")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isJoiningFamily || isJoinCooldownActive())
                .accessibilityIdentifier("join_family_from_empty")
            }
            .padding(.horizontal, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    @ViewBuilder
    private func familyListView(viewModel: FamilyViewModel) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: Detail view shows actual family list
            VStack(spacing: 0) {
                // Header section
                VStack(spacing: 16) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Text("家族グループ一覧")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("\(viewModel.families.count)個の家族グループに参加中")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                // Actual family list
                List(viewModel.families) { family in
                    NavigationLink(value: family) {
                        FamilyRowView(family: family)
                    }
                    .accessibilityIdentifier("family_detail_\(family.name)")
                }
                .listStyle(.insetGrouped)
                .onAppear {
                    print("🔍 [DEBUG] Detail view showing family list with \(viewModel.families.count) families")
                    print("📋 [DEBUG] Detail families: \(viewModel.families.map { $0.name })")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemGroupedBackground))
        } else {
            // iPhone: Simple list view
            List(viewModel.families) { family in
                NavigationLink(value: family) {
                    FamilyRowView(family: family)
                }
                .accessibilityIdentifier("family_detail_\(family.name)")
            }
            .listStyle(.insetGrouped)
            .onAppear {
                print("🔍 [DEBUG] iPhone view showing family list with \(viewModel.families.count) families")
                print("📋 [DEBUG] iPhone families: \(viewModel.families.map { $0.name })")
            }
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
    
    func body(content: Content) -> some View {
        content
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
