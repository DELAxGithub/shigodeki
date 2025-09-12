//
//  MemberDetailView.swift
//  shigodeki
//
//  Refactored for CLAUDE.md compliance - Lightweight coordinator view
//  Components extracted to MemberDetailSections.swift and MemberDataService.swift
//

import SwiftUI

struct MemberDetailView: View {
    let member: User
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @StateObject private var dataService = MemberDataService()
    @State private var projectManager: ProjectManager?
    @State private var selectedProject: Project? = nil
    @State private var selectedTaskContext: (task: ShigodekiTask, project: Project, phase: Phase)? = nil
    @Environment(\.dismiss) private var dismiss
    
    // Orphan guard: show only tasks that belong to user's visible projects
    private var visibleAssignedTasks: [ShigodekiTask] {
        let projectIds = Set(dataService.userProjects.compactMap { $0.id })
        return dataService.assignedTasks.filter { projectIds.contains($0.projectId) }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Hidden navigator to project detail
                if let pm = projectManager {
                    NavigationLink(isActive: Binding(
                        get: { selectedProject != nil },
                        set: { if !$0 { selectedProject = nil } }
                    )) {
                        if let p = selectedProject {
                            ProjectDetailView(project: p, projectManager: pm)
                        } else { EmptyView() }
                    } label: { EmptyView() }.hidden()
                }
                // Hidden navigator to task detail
                NavigationLink(isActive: Binding(
                    get: { selectedTaskContext != nil },
                    set: { if !$0 { selectedTaskContext = nil } }
                )) {
                    if let ctx = selectedTaskContext {
                        PhaseTaskDetailView(task: ctx.task, project: ctx.project, phase: ctx.phase)
                    } else { EmptyView() }
                } label: { EmptyView() }.hidden()
                // Member Profile
                MemberInfoSection(member: member)
                
                // Contact Information  
                ContactInfoSection(member: member)
                
                // Projects Section
                MemberProjectsSection(
                    userProjects: dataService.userProjects,
                    isLoadingProjects: dataService.isLoadingProjects,
                    onTapProject: { project in
                        selectedProject = project
                    }
                )
                
                // Tasks Section (single source of truth)
                MemberAssignedTasksSection(
                    assignedTasks: visibleAssignedTasks,
                    isLoadingTasks: dataService.isLoadingTasks,
                    projectNamesById: Dictionary(uniqueKeysWithValues: dataService.userProjects.compactMap { p in (p.id ?? "", p.name) }),
                    phasesByProject: dataService.phasesByProject,
                    onTapTask: { task in
                        guard let proj = dataService.userProjects.first(where: { $0.id == task.projectId }) else {
                            print("ℹ️ MemberDetailView: Project not found for task \(task.id ?? ""); projectId=\(task.projectId)")
                            return
                        }
                        guard let phase = dataService.phasesByProject[task.projectId]?.first(where: { $0.id == task.phaseId }) else {
                            print("ℹ️ MemberDetailView: Phase not found for task \(task.id ?? ""); phaseId=\(task.phaseId) projectId=\(task.projectId)")
                            return
                        }
                        selectedTaskContext = (task: task, project: proj, phase: phase)
                    }
                )
                
                // Statistics (only if data exists)
                if !dataService.userProjects.isEmpty || !visibleAssignedTasks.isEmpty {
                    MemberStatisticsSection(
                        userProjects: dataService.userProjects,
                        assignedTasks: visibleAssignedTasks
                    )
                }
            }
            .navigationTitle("メンバー詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .listStyle(.plain)
        }
        .task {
            await initializeView()
        }
        .task(id: visibleAssignedTasks.map { $0.projectId + ":" + $0.phaseId }.joined(separator: ",")) {
            let pids = Set(visibleAssignedTasks.map { $0.projectId }.filter { !$0.isEmpty })
            await dataService.ensurePhasesLoaded(forProjectIds: pids)
        }
        .alert(
            "エラー",
            isPresented: Binding(
                get: { dataService.errorMessage != nil },
                set: { if !$0 { dataService.errorMessage = nil } }
            )
        ) {
            Button("OK") { dataService.errorMessage = nil }
        } message: {
            Text(dataService.errorMessage ?? "")
        }
    }
    
    private func initializeView() async {
        // Clear any stale error from previous screens
        dataService.errorMessage = nil

        if projectManager == nil {
            projectManager = await sharedManagers.getProjectManager()
        }

        // Ensure authentication is ready before hitting Firestore
        let auth = await sharedManagers.getAuthManager()
        var attempts = 0
        while (auth.currentUserId == nil) && attempts < 20 { // ~2s max
            try? await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }

        guard let userId = member.id else { return }
        // Initial load (once)
        _ = await dataService.loadMemberData(userId: userId)
        // Realtime updates for projects to reflect newly created/joined ones
        dataService.startListeningUserProjects(userId: userId)
        
        // TODO: userProjects and assignedTasks properties don't exist in MemberDataService
        // await MainActor.run {
        //     dataService.userProjects = projects
        //     dataService.assignedTasks = tasks
        // }
    }
}

#Preview {
    let sampleUser = User(
        name: "田中太郎",
        email: "tanaka@example.com",
        projectIds: ["project1", "project2"],
        roleAssignments: [:]
    )
    
    MemberDetailView(member: sampleUser)
}
