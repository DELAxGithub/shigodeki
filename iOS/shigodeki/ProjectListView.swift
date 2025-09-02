//
//  ProjectListView.swift
//  shigodeki
//
//  [Foundation Consolidation] Phase 2.2: Pure Presentation Layer
//  Created by Claude on 2025-09-01.
//

import SwiftUI
import Combine

struct ProjectListView: View {
    // [Foundation Consolidation] Phase 2.2: Pure Presentation Layer
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @State private var viewModel: ProjectListViewModel?
    
    // UI State - Only presentation concerns
    @State private var showingCreateProject = false
    @State private var selectedProject: Project?
    @State private var showingAcceptInvite = false
    @State private var navigationResetId = UUID()

    var body: some View {
        NavigationView {
            VStack {
                // PickerはViewModelの@Publishedプロパティを直接バインドする
                if let vm = viewModel {
                    Picker("所有者", selection: Binding(
                        get: { vm.ownerFilter },
                        set: { vm.ownerFilter = $0 }
                    )) {
                        ForEach(OwnerFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding([.horizontal, .top])
                    
                    contentView(viewModel: vm)
                }
            }
            .navigationTitle("プロジェクト")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingAcceptInvite = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    Button(action: {
                        showingCreateProject = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("create_project_button")
                    .accessibilityLabel("新しいプロジェクトを作成")
                }
            }
            .loadingOverlay(
                (viewModel?.isLoading ?? false) || !(viewModel?.bootstrapped ?? true) || (viewModel?.isWaitingForAuth ?? false),
                message: (!(viewModel?.bootstrapped ?? true) || (viewModel?.isWaitingForAuth ?? false)) ? "初期化中..." : "プロジェクトを更新中..."
            )
            .task {
                // [Foundation Consolidation] Phase 2.2: Initialize ViewModel and delegate to it
                await initializeViewModel()
            }
            .onDisappear {
                viewModel?.onDisappear()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                print("🔚 ProjectListView: App terminating, cleaning up")
                viewModel?.onDisappear()
            }
            .sheet(isPresented: $showingCreateProject) {
                if let vm = viewModel {
                    CreateProjectView(projectManager: vm.projectManagerForViews)
                }
            }
            .sheet(isPresented: $showingAcceptInvite) {
                AcceptProjectInviteView()
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
        .onReceive(NotificationCenter.default.publisher(for: .projectTabSelected)) { _ in
            // Reset navigation stack to show the root list when project tab is selected
            navigationResetId = UUID()
            
            // Issue #53 Fix: Validate cache consistency when tab is selected
            viewModel?.onTabSelected()
        }
        .onChange(of: viewModel?.filteredProjects.count ?? 0) { _, newCount in
            #if DEBUG
            print("📊 ProjectListView: UI Projects count changed: \(newCount)")
            print("📋 ProjectListView: UI Project names: \(viewModel?.filteredProjects.map { $0.name } ?? [])")
            print("🎨 ProjectListView: SwiftUI triggering UI update")
            #endif
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func contentView(viewModel: ProjectListViewModel) -> some View {
        VStack {
            mainContentView(viewModel: viewModel)
            loadingStateView(viewModel: viewModel)
        }
    }
    
    @ViewBuilder
    private func mainContentView(viewModel: ProjectListViewModel) -> some View {
        if viewModel.shouldShowEmptyState {
            ProjectEmptyStateView {
                showingCreateProject = true
            }
        } else {
            projectListView(viewModel: viewModel)
        }
    }
    
    @ViewBuilder
    private func loadingStateView(viewModel: ProjectListViewModel) -> some View {
        if !viewModel.bootstrapped {
            LoadingStateView(message: "初期化中...")
                .padding()
        } else if viewModel.isWaitingForAuth {
            LoadingStateView(message: "ユーザー情報を取得中...")
                .padding()
        } else if viewModel.isLoading {
            LoadingStateView(message: "プロジェクトを読み込み中...")
                .padding()
        }
    }
    
    @ViewBuilder
    private func projectListView(viewModel: ProjectListViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredProjects) { project in
                    NavigationLink(destination: ProjectDetailView(project: project, projectManager: viewModel.projectManagerForViews)) {
                        OptimizedProjectRow(project: project)
                            .optimizedForList() // 🆕 描画最適化
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("project_\(project.name)")
                    .id(project.id) // 🔧 明示的なID設定で重複防止
                }
            }
            .padding(.horizontal)
        }
        .refreshable {
            await viewModel.refreshProjects()
        }
        .onMemoryWarning {
            // 🆕 統合されたキャッシュクリア
            CacheManager.shared.clearAll()
            ImageCache.shared.clearCache()
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeViewModel() async {
        let manager = await sharedManagers.getProjectManager()
        let auth = await sharedManagers.getAuthManager()
        
        #if DEBUG
        print("📱 ProjectListView: task triggered")
        print("🔧 ProjectListView: Creating ViewModel with ProjectManager and AuthManager")
        #endif
        
        // ViewModelを初期化
        viewModel = ProjectListViewModel(projectManager: manager, authManager: auth)
        
        // ViewModelのonAppearメソッドを呼び出し
        await viewModel?.onAppear()
    }
}