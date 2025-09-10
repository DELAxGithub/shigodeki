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
    @Environment(\.dismiss) private var dismiss
    
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
                
                // Tasks Section
                MemberAssignedTasksSection(
                    assignedTasks: dataService.assignedTasks,
                    isLoadingTasks: dataService.isLoadingTasks,
                    onTapTask: { task in
                        if let proj = dataService.userProjects.first(where: { $0.id == task.projectId }) {
                            selectedProject = proj
                        } else {
                            print("ℹ️ MemberDetailView: Project not found for task \(task.id ?? ""); projectId=\(task.projectId)")
                        }
                    }
                )

                // Grouped by Project (ideal UX)
                if !dataService.assignedTasks.isEmpty {
                    ForEach(dataService.userProjects) { project in
                        let tasks = dataService.assignedTasks.filter { $0.projectId == (project.id ?? "") }
                        if !tasks.isEmpty {
                            Section(project.name) {
                                ForEach(tasks) { task in
                                    Button {
                                        selectedProject = project
                                    } label: {
                                        TaskRowCompact(task: task)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                
                // Statistics (only if data exists)
                // TODO: userProjects and assignedTasks properties don't exist
                // if !dataService.userProjects.isEmpty || !dataService.assignedTasks.isEmpty {
                //     MemberStatisticsSection(
                //         userProjects: dataService.userProjects,
                //         assignedTasks: dataService.assignedTasks
                //     )
                // }
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
        if projectManager == nil {
            projectManager = await sharedManagers.getProjectManager()
        }
        
        guard let userId = member.id else { return }
        _ = await dataService.loadMemberData(userId: userId)
        
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
