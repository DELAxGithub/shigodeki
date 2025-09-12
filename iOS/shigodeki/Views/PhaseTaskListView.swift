//
//  PhaseTaskListView.swift
//  shigodeki
//
//  Created by Claude on 2025-09-05.
//

import SwiftUI
import FirebaseFirestore

struct PhaseTaskListView: View {
    let phase: Phase
    let project: Project
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @StateObject private var viewModelHolder = _VMHolder()
    @ObservedObject private var authManager = AuthenticationManager.shared
    @State private var showingCreateTaskList = false
    // Feature toggle: whether to skip list layer automatically
    private let skipListLayer: Bool = false
    @State private var autoNavigate = false
    @State private var didAutoNavigate = false
    @State private var autoList: TaskList? = nil
    @Environment(\.dismiss) private var dismiss
    var onSelectTaskList: ((TaskList, Phase) -> Void)? = nil
    var onTapProject: (() -> Void)? = nil
    
    var body: some View {
        VStack {
            // Auto-navigation stub removed to avoid deprecated NavigationLink initializer warning
            BreadcrumbBar(items: [project.name, phase.name]) { idx in
                print("UI: Breadcrumb tapped idx=\(idx) at PhaseTaskListView")
                if idx == 0 {
                    if let onTapProject { onTapProject() } else { dismiss() }
                }
            }
                .padding(.horizontal)
            let isLoading = viewModelHolder.vm?.isLoading ?? false
            let lists = viewModelHolder.vm?.lists ?? []
            if lists.isEmpty && !isLoading {
                // Empty task lists state
                VStack(spacing: 24) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 8) {
                        Text("タスクリストがありません")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("このフェーズのタスクを管理するため\nタスクリストを作成しましょう")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        showingCreateTaskList = true
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
                }
                .padding()
                
            } else {
                List {
                    ForEach(lists) { taskList in
                        if let onSelectTaskList {
                            Button { onSelectTaskList(taskList, phase) } label: {
                                PhaseTaskListRowView(taskList: taskList)
                            }
                            .buttonStyle(.plain)
                            .interactiveEffect()
                        } else {
                            NavigationLink(destination: TaskListDetailView(taskList: taskList, phase: phase, project: project)) {
                                PhaseTaskListRowView(taskList: taskList)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                print("UI: TaskList tapped -> \(taskList.name) [id=\(taskList.id ?? "")] in phase \(phase.name)")
                            })
                        }
                    }
                }
                .statusBarTapScrollToTop()
                .refreshable {
                    await viewModelHolder.vm?.reload()
                }
            }
        }
        .loadingOverlay(viewModelHolder.vm?.isLoading ?? false, message: "タスクリストを更新中...")
        .navigationTitle(phase.name)
        .navigationBarBackButtonHidden(true)
        .enableSwipeBack()
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    showingCreateTaskList = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            if viewModelHolder.vm == nil, let phaseId = phase.id, let projectId = project.id {
                let vm = PhaseTaskListViewModel(phaseId: phaseId, projectId: projectId)
                viewModelHolder.vm = vm
                await vm.bootstrap(store: sharedManagers)
                // Auto-route when exactly one list exists
                if skipListLayer {
                    let currentLists = vm.lists
                    if currentLists.count == 1 && !didAutoNavigate {
                        autoList = currentLists.first
                        didAutoNavigate = true
                        DispatchQueue.main.async {
                            self.autoNavigate = true
                        }
                    } else if currentLists.isEmpty && !didAutoNavigate {
                        await createDefaultListAndNavigate()
                    }
                }
            }
        }
        .onChange(of: viewModelHolder.vm?.lists.count ?? 0) { _, newCount in
            if skipListLayer {
                if newCount == 1 && !didAutoNavigate {
                    let currentLists = viewModelHolder.vm?.lists ?? []
                    autoList = currentLists.first
                    didAutoNavigate = true
                    DispatchQueue.main.async {
                        self.autoNavigate = true
                    }
                } else if newCount == 0 && !didAutoNavigate {
                    Task { await createDefaultListAndNavigate() }
                }
            }
        }
        .sheet(isPresented: $showingCreateTaskList) {
            CreatePhaseTaskListSheet(phase: phase, project: project)
                .environmentObject(sharedManagers)
        }
    }

    // Create a default task list when none exists, then navigate
    private func createDefaultListAndNavigate() async {
        guard let phaseId = phase.id, let projectId = project.id else { return }
        do {
            let taskListManager = await sharedManagers.getTaskListManager()
            let auth = await sharedManagers.getAuthManager()
            let uid = auth.currentUserId ?? ""
            let created = try await taskListManager.createTaskList(
                name: "ToDo",
                phaseId: phaseId,
                projectId: projectId,
                createdBy: uid,
                color: .blue,
                order: nil
            )
            await MainActor.run {
                autoList = created
                didAutoNavigate = true
                autoNavigate = true
            }
        } catch {
            print("Auto-create default list failed: \(error)")
        }
    }
}

// Wrapper to bridge VM and keep access to underlying manager for sheet
private final class _VMHolder: ObservableObject {
    @Published var vm: PhaseTaskListViewModel?
}

private struct CreatePhaseTaskListSheet: View {
    let phase: Phase
    let project: Project
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @State private var manager: TaskListManager? = nil
    
    var body: some View {
        Group {
            if let m = manager {
                CreatePhaseTaskListView(phase: phase, project: project, taskListManager: m)
            } else {
                LoadingStateView(message: "タスクリスト準備中...")
                    .padding()
            }
        }
        .task {
            if manager == nil { manager = await sharedManagers.getTaskListManager() }
        }
    }
}
