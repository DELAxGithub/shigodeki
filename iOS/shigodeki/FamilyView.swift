//
//  FamilyView.swift
//  shigodeki
//
//  [Pattern Propagation] Pure Presentation Layer - Business Logic delegated to FamilyViewModel
//  Created by Claude on 2025-09-01.
//

import SwiftUI

struct FamilyView: View {
    // [Pattern Propagation] Pure Presentation Layer
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @State private var viewModel: FamilyViewModel?
    
    // UI State - Only presentation concerns
    @State private var showingCreateFamily = false
    @State private var showingJoinFamily = false
    @State private var navigationResetId = UUID()

    var body: some View {
        NavigationView {
            VStack {
                if let vm = viewModel {
                    contentView(viewModel: vm)
                } else {
                    ProgressView("初期化中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("家族")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingJoinFamily = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    Button(action: {
                        showingCreateFamily = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("create_family_button")
                    .accessibilityLabel("新しい家族グループを作成")
                }
            }
            .task {
                await initializeViewModel()
            }
            .onDisappear {
                viewModel?.onDisappear()
            }
            .sheet(isPresented: $showingCreateFamily) {
                CreateFamilyView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingJoinFamily) {
                JoinFamilyView(viewModel: viewModel)
            }
            .alert("エラー", isPresented: Binding(
                get: { viewModel?.error != nil },
                set: { _ in viewModel?.clearError() }
            )) {
                Button("OK") {
                    viewModel?.clearError()
                }
            } message: {
                if let error = viewModel?.error {
                    Text(error.localizedDescription)
                } else {
                    Text("不明なエラーが発生しました")
                }
            }
        }
        .id(navigationResetId)
        .onReceive(NotificationCenter.default.publisher(for: .familyTabSelected)) { _ in
            // Reset navigation stack to show the root list when family tab is selected
            navigationResetId = UUID()
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func contentView(viewModel: FamilyViewModel) -> some View {
        // Wait for auth userId to be available before deciding empty state
        if viewModel.authManagerForViews.currentUser?.id == nil && viewModel.authManagerForViews.isAuthenticated {
            ProgressView("ユーザー情報を取得中...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.shouldShowEmptyState {
            familyEmptyStateView()
        } else if viewModel.isLoading {
            ProgressView("家族グループを読み込み中...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            familyListView(viewModel: viewModel)
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
                    showingCreateFamily = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("家族グループを作成")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("create_family_from_empty")
                
                Button(action: {
                    showingJoinFamily = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("招待コードで参加")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("join_family_from_empty")
            }
            .padding(.horizontal, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    @ViewBuilder
    private func familyListView(viewModel: FamilyViewModel) -> some View {
        List(viewModel.families) { family in
            NavigationLink(destination: FamilyDetailView(family: family)) {
                FamilyRowView(family: family)
            }
            .accessibilityIdentifier("family_\(family.name)")
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Private Methods
    
    private func initializeViewModel() async {
        // Issue #50 Fix: Wait for centralized preload before initializing ViewModel
        #if DEBUG
        print("📱 FamilyView: Waiting for SharedManagerStore preload completion...")
        #endif
        
        // Wait for SharedManagerStore preload to complete to prevent initialization conflicts
        while !sharedManagers.isPreloaded {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms intervals
        }
        
        let familyManager = await sharedManagers.getFamilyManager()
        let authManager = await sharedManagers.getAuthManager()
        
        #if DEBUG
        print("📱 FamilyView: task triggered")
        print("🔧 FamilyView: Creating ViewModel with pre-loaded FamilyManager and AuthManager")
        print("🎯 Issue #50: ViewModel initialization after centralized preload completed")
        #endif
        
        // ViewModelを初期化
        viewModel = FamilyViewModel(familyManager: familyManager, authManager: authManager)
        
        // ViewModelのonAppearメソッドを呼び出し
        await viewModel?.onAppear()
    }
}

// MARK: - Supporting Views (Temporary - Should be moved to separate files)

struct FamilyRowView: View {
    let family: Family
    
    var body: some View {
        HStack {
            Image(systemName: "house.fill")
                .font(.title3)
                .foregroundColor(.blue)
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
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct CreateFamilyView: View {
    let viewModel: FamilyViewModel?
    @Environment(\.dismiss) private var dismiss
    
    @State private var familyName: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("家族グループ名")
                        .font(.headline)
                    
                    TextField("例：田中家", text: $familyName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .accessibilityIdentifier("family_name_input")
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("家族グループ作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        createFamily()
                    }
                    .disabled(familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                             (viewModel?.isCreatingFamily ?? false))
                    .accessibilityIdentifier("create_family_confirm")
                }
            }
            .onChange(of: viewModel?.shouldDismissCreateSheet) { shouldDismiss in
                if shouldDismiss == true {
                    dismiss()
                    viewModel?.resetSuccessStates()
                }
            }
        }
    }
    
    private func createFamily() {
        let trimmedName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        Task {
            await viewModel?.createFamily(name: trimmedName)
        }
    }
}

struct JoinFamilyView: View {
    let viewModel: FamilyViewModel?
    @Environment(\.dismiss) private var dismiss
    
    @State private var invitationCode: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("招待コード")
                        .font(.headline)
                    
                    TextField("招待コードを入力", text: $invitationCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .accessibilityIdentifier("invitation_code_input")
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("家族グループに参加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("参加") {
                        joinFamily()
                    }
                    .disabled(invitationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                             (viewModel?.isJoiningFamily ?? false))
                    .accessibilityIdentifier("join_family_confirm")
                }
            }
            .alert("参加完了", isPresented: Binding(
                get: { viewModel?.showJoinSuccess ?? false },
                set: { _ in viewModel?.resetSuccessStates() }
            )) {
                Button("OK") {
                    viewModel?.resetSuccessStates()
                    dismiss()
                }
            } message: {
                Text(viewModel?.joinSuccessMessage ?? "家族グループに参加しました！")
            }
            .alert("エラー", isPresented: Binding(
                get: { viewModel?.error != nil },
                set: { _ in viewModel?.clearError() }
            )) {
                Button("OK") {
                    viewModel?.clearError()
                }
            } message: {
                if let error = viewModel?.error {
                    Text(error.localizedDescription)
                } else {
                    Text("不明なエラーが発生しました")
                }
            }
        }
    }
    
    private func joinFamily() {
        let trimmedCode = invitationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else { return }
        
        Task {
            await viewModel?.joinFamily(invitationCode: trimmedCode)
        }
    }
}