//
//  TaskListMainView.swift
//  shigodeki
//
//  [Operation: Unification] Pure Presentation Layer - Business Logic delegated to TaskListViewModel
//  Created by Claude on 2025-09-01.
//

import SwiftUI

struct TaskListMainView: View {
    // [Operation: Unification] Pure Presentation Layer
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @State private var viewModel: TaskListViewModel?
    
    // UI State - Only presentation concerns
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
            .navigationTitle("タスク")
            .toolbar {
                if viewModel?.selectedFamily != nil {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button(action: {
                            viewModel?.showCreateTaskList()
                        }) {
                            Image(systemName: "plus")
                        }
                        
                        Button(action: {
                            viewModel?.deselectFamily()
                        }) {
                            Image(systemName: "house")
                        }
                    }
                }
            }
            .task {
                await initializeViewModel()
            }
            .onDisappear {
                viewModel?.onDisappear()
            }
            // Task list creation sheets will be re-enabled when TaskManager integration is completed
            // .sheet(isPresented: Binding(
            //     get: { viewModel?.showingCreateTaskList ?? false },
            //     set: { _ in viewModel?.hideCreateTaskList() }
            // )) {
            //     if let vm = viewModel,
            //        let family = vm.selectedFamily,
            //        let userId = vm.authManagerForViews.currentUser?.id {
            //         CreateTaskListView(family: family, taskManager: taskManager, creatorUserId: userId)
            //     }
            // }
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
        .onReceive(NotificationCenter.default.publisher(for: .taskTabSelected)) { _ in
            // Reset navigation stack to show the root list when task tab is selected
            navigationResetId = UUID()
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func contentView(viewModel: TaskListViewModel) -> some View {
        if (!viewModel.bootstrapped) || viewModel.authManagerForViews.isLoading {
            ProgressView("読み込み中...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.shouldShowNoFamiliesState {
            noFamiliesStateView()
        } else if viewModel.shouldShowFamilySelection {
            familySelectionView(viewModel: viewModel)
        } else if viewModel.shouldShowTaskLists {
            taskListsView(viewModel: viewModel)
        }
        
        if viewModel.isLoading {
            ProgressView("読み込み中...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private func noFamiliesStateView() -> some View {
        VStack(spacing: 24) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("家族グループが必要です")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("タスクタブは『家族グループのタスク』を表示します。\nプロジェクト配下のタスクは『プロジェクト』タブで管理できます。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            NavigationLink(destination: FamilyView()) {
                HStack {
                    Image(systemName: "person.3.fill")
                    Text("家族グループを作成")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func familySelectionView(viewModel: TaskListViewModel) -> some View {
        VStack(spacing: 16) {
            Text("家族を選択")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top)
            
            Text("タスクを管理する家族グループを選んでください")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.families) { family in
                    Button(action: {
                        viewModel.selectFamily(family)
                    }) {
                        FamilySelectionRowView(family: family)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func taskListsView(viewModel: TaskListViewModel) -> some View {
        if let selectedFamily = viewModel.selectedFamily {
            TaskListsView(
                family: selectedFamily,
                viewModel: viewModel
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeViewModel() async {
        // Issue #50 Fix: Wait for centralized preload before initializing ViewModel
        #if DEBUG
        print("📱 TaskListMainView: Waiting for SharedManagerStore preload completion...")
        #endif
        
        // 🚨 CTO修正: ポーリングループを非同期待機に変更
        // 10ms間隔のポーリングを撤廃し、Combineの@Publishedプロパティを活用
        await withCheckedContinuation { continuation in
            if sharedManagers.isPreloaded {
                print("⚡ TaskListMainView: SharedManagerStore already preloaded")
                continuation.resume()
            } else {
                // @Publishedプロパティの変更を監視
                var cancellable: AnyCancellable?
                cancellable = sharedManagers.$isPreloaded
                    .filter { $0 } // isPreloaded == true になるまで待機
                    .first()
                    .sink { _ in
                        print("⚡ TaskListMainView: SharedManagerStore preload completed")
                        cancellable?.cancel()
                        continuation.resume()
                    }
            }
        }
        
        let familyManager = await sharedManagers.getFamilyManager()
        let authManager = await sharedManagers.getAuthManager()
        
        #if DEBUG
        print("📱 TaskListMainView: task triggered")
        print("🔧 TaskListMainView: Creating ViewModel with pre-loaded FamilyManager and AuthManager")
        print("🎯 Issue #50: ViewModel initialization after centralized preload completed")
        #endif
        
        // ViewModelを初期化
        viewModel = TaskListViewModel(
            familyManager: familyManager,
            authManager: authManager
        )
        
        // ViewModelのonAppearメソッドを呼び出し
        await viewModel?.onAppear()
    }
}

// MARK: - Supporting Views

struct FamilySelectionRowView: View {
    let family: Family
    
    var body: some View {
        HStack {
            Image(systemName: "house.fill")
                .font(.title3)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(family.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(family.members.count)人のメンバー")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TaskListsView: View {
    let family: Family
    let viewModel: TaskListViewModel
    @StateObject private var aiGenerator = AITaskGenerator()
    
    var body: some View {
        VStack {
            if viewModel.shouldShowEmptyState {
                // Empty state
                VStack(spacing: 24) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 8) {
                        Text("タスクリストがありません")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("新しいタスクリストを作成して\nタスク管理を始めましょう。\n（注）プロジェクトのタスクは『プロジェクト』タブで表示されます")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 12) {
                        Button(action: {
                            viewModel.showCreateTaskList()
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("タスクリストを作成")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            // AI action will be implemented when TaskManager is available
                        }) {
                            HStack {
                                Image(systemName: "brain")
                                Text("AI でタスクを生成")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
                
            } else {
                List {
                    // Info banner clarifying scope
                    Section {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("このタブでは家族グループ配下のタスクを表示します。プロジェクト配下のタスクは『プロジェクト』タブを開いてください。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    // Quick AI Generation Section
                    Section {
                        Button(action: {
                            // AI action will be implemented when TaskManager is available
                        }) {
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "brain")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("AI クイック生成")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text("自然言語からタスクを瞬時に生成")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Note: Task lists functionality will be implemented when TaskManager API is available
                    // Currently focused on family selection workflow only
                }
                // Refresh functionality will be added when task list management is implemented
            }
            
            // Task list loading state will be added when functionality is implemented
        }
        // AI generation sheets will be re-enabled when TaskManager integration is completed
        // .sheet(isPresented: Binding(
        //     get: { viewModel.showingQuickAIGeneration },
        //     set: { _ in viewModel.hideQuickAIGeneration() }
        // )) {
        //     QuickAIGenerationView(
        //         family: family,
        //         taskManager: taskManager,
        //         aiGenerator: aiGenerator
        //     )
        // }
        // .sheet(isPresented: Binding(
        //     get: { viewModel.showingAISettings },
        //     set: { _ in viewModel.hideAISettings() }
        // )) {
        //     APISettingsView()
        //         .onDisappear {
        //             aiGenerator.updateAvailableProviders()
        //         }
        // }
    }
}

struct TaskListRowView: View {
    let taskList: TaskList
    let taskCount: Int
    
    var body: some View {
        HStack {
            Circle()
                .fill(taskList.color.swiftUIColor)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(taskList.name)
                    .font(.headline)
                
                Text("\(taskCount)個のタスク")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TaskListMainView()
}
