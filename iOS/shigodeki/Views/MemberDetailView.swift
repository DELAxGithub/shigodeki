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
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Member Profile
                MemberInfoSection(member: member)
                
                // Contact Information  
                ContactInfoSection(member: member)
                
                // Projects Section
                // TODO: MemberDataService doesn't have userProjects property
                // MemberProjectsSection(
                //     userProjects: dataService.userProjects,
                //     isLoadingProjects: dataService.isLoadingProjects
                // )
                
                // Tasks Section
                // TODO: MemberDataService doesn't have assignedTasks property  
                // MemberAssignedTasksSection(
                //     assignedTasks: dataService.assignedTasks,
                //     isLoadingTasks: dataService.isLoadingTasks
                // )
                
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
        }
        .task {
            await initializeView()
        }
        .alert("エラー", isPresented: .constant(dataService.errorMessage != nil)) {
            Button("OK") {
                dataService.errorMessage = nil
            }
        } message: {
            if let errorMessage = dataService.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private func initializeView() async {
        if projectManager == nil {
            projectManager = await sharedManagers.getProjectManager()
        }
        
        guard let userId = member.id else { return }
        let (projects, tasks) = await dataService.loadMemberData(userId: userId)
        
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