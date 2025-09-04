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
    @State private var selectedProject: Project?
    @State private var showingAcceptInvite = false
    @State private var navigationResetId = UUID()

    var body: some View {
        NavigationView {
            VStack {
                Picker("所有者", selection: $viewModel.ownerFilter) {
                    ForEach(OwnerFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])
                .disabled(viewModel.isLoading)
                
                // 🚨 CTO Requirement: Consolidate loading logic into a single source of truth.
                contentView
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
        }
        .id(navigationResetId)
        .onReceive(NotificationCenter.default.publisher(for: .projectTabSelected)) { _ in
            // Reset navigation stack to show the root list when project tab is selected
            navigationResetId = UUID()
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
    private var contentView: some View {
        // 🚨 CTO Requirement: Single source of truth for loading state display.
        if !viewModel.bootstrapped || viewModel.isWaitingForAuth {
            LoadingStateView(message: (!viewModel.bootstrapped) ? "初期化中..." : "ユーザー情報を取得中...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.shouldShowEmptyState {
            ProjectEmptyStateView {
                showingCreateProject = true
            }
        } else {
            projectListView
        }
    }
    
    @ViewBuilder
    private var projectListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredProjects) { project in
                    NavigationLink(destination: projectDetailDestination(project)) {
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
    
    @ViewBuilder
    private func projectDetailDestination(_ project: Project) -> some View {
        if let pm = viewModel.projectManagerForViews {
            ProjectDetailView(project: project, projectManager: pm)
        } else {
            // Manager準備中は空のビュー
            EmptyView()
        }
    }
}