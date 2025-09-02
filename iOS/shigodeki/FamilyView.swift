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
    
    // DEBUG: Simple test alert to verify alert display functionality
    @State private var showSimpleTestAlert = false

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
                    // DEBUG: Manual test button for alert testing
                    Button(action: {
                        print("🧪 [DEBUG] Manual test button tapped")
                        showSimpleTestAlert = true
                    }) {
                        Text("TEST")
                            .font(.caption)
                    }
                    Button {
                        print("🔄 [DEBUG] Join family button tapped")
                        // Only show the sheet, not the test alert
                        showingJoinFamily = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    Button(action: {
                        print("🔄 [DEBUG] Create family button tapped")
                        // Only show the sheet, not the test alert
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
            // MARK: - DEBUG: Simple test alert for manual testing
            .alert("テストアラート", isPresented: $showSimpleTestAlert) {
                Button("OK") {
                    print("✅ [DEBUG] Simple test alert dismissed successfully")
                }
                Button("処理中アラートテスト") {
                    print("🧪 [DEBUG] Triggering test processing alert from simple alert")
                    if let viewModel = viewModel {
                        viewModel.triggerTestCreateProcessingAlert()
                    }
                }
                Button("参加アラートテスト") {
                    print("🧪 [DEBUG] Triggering test join alert from simple alert")
                    if let viewModel = viewModel {
                        viewModel.triggerTestJoinProcessingAlert()
                    }
                }
            } message: {
                Text("アラート表示テスト\n各ボタンで処理フローをテストできます")
            }
            
            // MARK: - Original complex alerts (temporarily commented out for debugging)
            /*
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
            .alert(
                viewModel?.showCreateSuccess == true ? "成功" : "処理中",
                isPresented: Binding(
                    get: { viewModel?.showCreateProcessing == true },
                    set: { _ in }
                )
            ) {
                if viewModel?.showCreateSuccess == true {
                    Button("OK") {
                        viewModel?.dismissCreateSheetWithReload()
                        viewModel?.resetSuccessStates()
                    }
                }
            } message: {
                if let message = viewModel?.processingMessage, !message.isEmpty {
                    Text(message)
                } else if viewModel?.showCreateSuccess == true {
                    Text("家族グループが作成されました！")
                } else {
                    Text("家族グループを作成中...")
                }
            }
            .alert(
                viewModel?.showJoinSuccess == true ? "成功" : "処理中",
                isPresented: Binding(
                    get: { viewModel?.showJoinProcessing == true },
                    set: { _ in }
                )
            ) {
                if viewModel?.showJoinSuccess == true {
                    Button("OK") {
                        viewModel?.dismissJoinViewWithReload()  
                        viewModel?.resetSuccessStates()
                    }
                }
            } message: {
                if let message = viewModel?.joinSuccessMessage, !message.isEmpty {
                    Text(message)
                } else if viewModel?.showJoinSuccess == true {
                    Text("家族グループに参加しました！")
                } else {
                    Text("家族グループに参加中...")
                }
            }
            */
            
            // MARK: - Simplified Working Alerts
            
            // Simple Error Alert
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
            
            // Create Processing Alert
            .alert(
                viewModel?.showCreateSuccess == true ? "作成成功" : "作成処理中",
                isPresented: Binding(
                    get: { 
                        let show = viewModel?.showCreateProcessing == true
                        print("🔍 [DEBUG] Create alert isPresented getter called: \(show)")
                        return show
                    },
                    set: { newValue in 
                        print("🔍 [DEBUG] Create alert isPresented setter called with: \(newValue)")
                        if !newValue {
                            viewModel?.resetSuccessStates()
                        }
                    }
                )
            ) {
                if viewModel?.showCreateSuccess == true {
                    Button("OK") {
                        print("✅ [DEBUG] Create success OK pressed")
                        viewModel?.dismissCreateSheetWithReload()
                        viewModel?.resetSuccessStates()
                    }
                }
            } message: {
                if let message = viewModel?.processingMessage, !message.isEmpty {
                    Text(message)
                } else if viewModel?.showCreateSuccess == true {
                    Text("家族グループが作成されました！")
                } else {
                    Text("家族グループを作成中...")
                }
            }
            
            // Join Processing Alert
            .alert(
                viewModel?.showJoinSuccess == true ? "参加成功" : "参加処理中",
                isPresented: Binding(
                    get: { 
                        let show = viewModel?.showJoinProcessing == true
                        print("🔍 [DEBUG] Join alert isPresented getter called: \(show)")
                        return show
                    },
                    set: { newValue in 
                        print("🔍 [DEBUG] Join alert isPresented setter called with: \(newValue)")
                        if !newValue {
                            viewModel?.resetSuccessStates()
                        }
                    }
                )
            ) {
                if viewModel?.showJoinSuccess == true {
                    Button("OK") {
                        print("✅ [DEBUG] Join success OK pressed")
                        viewModel?.dismissJoinViewWithReload()
                        viewModel?.resetSuccessStates()
                    }
                }
            } message: {
                if let message = viewModel?.joinSuccessMessage, !message.isEmpty {
                    Text(message)
                } else if viewModel?.showJoinSuccess == true {
                    Text("家族グループに参加しました！")
                } else {
                    Text("家族グループに参加中...")
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
                    print("🔄 [DEBUG] Create family from empty button tapped")
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
                    print("🔄 [DEBUG] Join family from empty button tapped")
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
    @State private var showProcessingAlert = false
    
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
                        // Hide keyboard before creating
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        print("🧪 [DEBUG] CreateFamilyView: Create button tapped, starting family creation")
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
            .onChange(of: viewModel?.showCreateProcessing) { isProcessing in
                print("🔍 [DEBUG] CreateFamilyView: onChange showCreateProcessing = \(isProcessing ?? false)")
                showProcessingAlert = isProcessing == true || viewModel?.showCreateSuccess == true
            }
            .onChange(of: viewModel?.showCreateSuccess) { isSuccess in
                print("🔍 [DEBUG] CreateFamilyView: onChange showCreateSuccess = \(isSuccess ?? false)")
                showProcessingAlert = viewModel?.showCreateProcessing == true || isSuccess == true
            }
            // MARK: - Processing/Success Alert for CreateFamilyView
            .alert(
                viewModel?.showCreateSuccess == true ? "作成成功" : "作成処理中",
                isPresented: $showProcessingAlert
            ) {
                if viewModel?.showCreateSuccess == true {
                    Button("OK") {
                        print("✅ [DEBUG] CreateFamilyView success OK pressed")
                        showProcessingAlert = false
                        viewModel?.dismissCreateSheetWithReload()
                        viewModel?.resetSuccessStates()
                        dismiss()
                    }
                } else {
                    // Processing state - no button, auto-disappears when success state is reached
                }
            } message: {
                if let message = viewModel?.processingMessage, !message.isEmpty {
                    Text(message)
                } else if viewModel?.showCreateSuccess == true {
                    Text("家族グループが作成されました！")
                } else {
                    Text("家族グループを作成中...")
                }
            }
        }
    }
    
    private func createFamily() {
        let trimmedName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        Task {
            let success = await viewModel?.createFamily(name: trimmedName) ?? false
            if success {
                print("✅ [DEBUG] CreateFamilyView: Family created successfully - alert will handle dismiss")
                // Let the success alert handle dismissal to prevent view hierarchy issues
            }
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
                        // Hide keyboard before joining
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        print("🧪 [DEBUG] JoinFamilyView: Join button tapped, starting family join")
                        joinFamily()
                    }
                    .disabled(invitationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                             (viewModel?.isJoiningFamily ?? false))
                    .accessibilityIdentifier("join_family_confirm")
                }
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
            .onChange(of: viewModel?.showJoinSuccess) { showSuccess in
                if showSuccess == true {
                    dismiss()
                }
            }
            // MARK: - Processing/Success Alert for JoinFamilyView
            .alert(
                viewModel?.showJoinSuccess == true ? "参加成功" : "参加処理中",
                isPresented: Binding(
                    get: { 
                        let show = viewModel?.showJoinProcessing == true
                        print("🔍 [DEBUG] JoinFamilyView alert isPresented getter called: \(show)")
                        return show
                    },
                    set: { newValue in 
                        print("🔍 [DEBUG] JoinFamilyView alert isPresented setter called with: \(newValue)")
                        if !newValue {
                            viewModel?.resetSuccessStates()
                        }
                    }
                )
            ) {
                if viewModel?.showJoinSuccess == true {
                    Button("OK") {
                        print("✅ [DEBUG] JoinFamilyView success OK pressed")
                        viewModel?.dismissJoinViewWithReload()
                        viewModel?.resetSuccessStates()
                        dismiss()
                    }
                }
            } message: {
                if let message = viewModel?.joinSuccessMessage, !message.isEmpty {
                    Text(message)
                } else if viewModel?.showJoinSuccess == true {
                    Text("家族グループに参加しました！")
                } else {
                    Text("家族グループに参加中...")
                }
            }
        }
    }
    
    private func joinFamily() {
        let trimmedCode = invitationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else { return }
        
        Task {
            let success = await viewModel?.joinFamily(invitationCode: trimmedCode) ?? false
            if success {
                print("✅ [DEBUG] JoinFamilyView: Family joined successfully - alert will handle dismiss")
                // Let the success alert handle dismissal to prevent view hierarchy issues
            }
        }
    }
}