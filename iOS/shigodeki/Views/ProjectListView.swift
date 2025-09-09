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
    // 🚨 CTO Requirement: ViewModel must be non-optional and autonomous.
    @StateObject private var viewModel = ProjectListViewModel()

    // UI State - Only presentation concerns
    @State private var showingCreateProject = false
    @State private var showingAcceptInvite = false
    
    var body: some View {
        // 🚨 CTO Requirement: This is the correct, standard implementation for NavigationSplitView.
        NavigationSplitView {
            // MARK: - Sidebar
            // The sidebar is ONLY for selection.
            sidebarView
                .navigationTitle("プロジェクト")
                .toolbar {
                    // Global actions like "Create" belong on the sidebar.
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            showingAcceptInvite = true
                        } label: {
                            Label("プロジェクトに参加", systemImage: "person.badge.plus")
                        }
                        
                        Button(action: {
                            showingCreateProject = true
                        }) {
                            Label("プロジェクトを作成", systemImage: "plus")
                        }
                        .accessibilityIdentifier("create_project_button")
                        .accessibilityLabel("新しいプロジェクトを作成")
                    }
                }
        } detail: {
            // MARK: - Detail
            // The detail pane shows the content of the selection, or a placeholder.
            NavigationStack {
                if let selectedProject = viewModel.selectedProject {
                    if let pm = viewModel.projectManagerForViews {
                        // Remount detail view when selection changes to avoid stale StateObject
                        ProjectDetailView(project: selectedProject, projectManager: pm)
                            .id(selectedProject.id ?? selectedProject.name)
                    } else {
                        LoadingStateView(message: "システムを準備中...")
                    }
                } else {
                    placeholderView
                }
            }
        }
        .navigationSplitViewStyle(.balanced) // Ensures sidebar is visible on iPad launch
        .task {
            await viewModel.onAppear()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            print("🔚 ProjectListView: App terminating, cleaning up")
            viewModel.onDisappear()
        }
        .sheet(isPresented: $showingCreateProject) {
            if let pm = viewModel.projectManagerForViews {
                CreateProjectView(projectManager: pm)
            } else {
                // Managerがまだ準備できていない場合はローディング表示
                LoadingStateView(message: "システムを準備中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingAcceptInvite) {
            AcceptProjectInviteView()
        }
        .alert("エラー", isPresented: $viewModel.showError) {
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
        .onChange(of: viewModel.filteredProjects.count) { _, newCount in
            #if DEBUG
            print("📊 ProjectListView: UI Projects count changed: \(newCount)")
            print("📋 ProjectListView: UI Project names: \(viewModel.filteredProjects.map { $0.name })")
            print("🎨 ProjectListView: SwiftUI triggering UI update")
            #endif
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var sidebarView: some View {
        VStack {
            // Owner filter picker
            Picker("所有者", selection: $viewModel.ownerFilter) {
                ForEach(OwnerFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])
            .disabled(viewModel.isLoading)
            
            // The sidebar's state is derived directly from the ViewModel.
            if !viewModel.bootstrapped || viewModel.isWaitingForAuth {
                ProgressView((!viewModel.bootstrapped) ? "初期化中..." : "ユーザー情報を取得中...")
            } else if viewModel.shouldShowEmptyState {
                Text("プロジェクトがありません")
                    .foregroundColor(.secondary)
            } else {
                // Issue #84: Add ScrollViewReader for scroll-to-top functionality
                ScrollViewReader { proxy in
                    // The List's selection is bound to the ViewModel's selectedProject property.
                    // This is the core of the master-detail interface.
                    List(selection: $viewModel.selectedProject) {
                        // Issue #84: Add top anchor for scroll-to-top functionality
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 1)
                            .id("top")
                            .listRowSeparator(.hidden)
                        
                        ForEach(viewModel.filteredProjects) { project in
                            ProjectRowView(project: project)
                                .tag(project) // The tag MUST match the selection type.
                        }
                    }
                    .refreshable {
                        await viewModel.refreshProjects()
                    }
                    .onMemoryWarning {
                        // 🆕 統合されたキャッシュクリア
                        CacheManager.shared.clearAll()
                        ImageCache.shared.clearCache()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .projectTabSelected)) { _ in
                        // Issue #84: Reset selection and scroll to top when project tab is re-selected
                        viewModel.selectedProject = nil
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("プロジェクトを選択してください")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
    
}
