//
//  ProjectDetailView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @ObservedObject var projectManager: ProjectManager
    @StateObject private var phaseManager = PhaseManager()
    @ObservedObject private var authManager = SimpleAuthenticationManager.shared
    @State private var showingCreatePhase = false
    @State private var showingProjectSettings = false
    @State private var selectedPhase: Phase?
    
    var body: some View {
        VStack(spacing: 0) {
            // Project Header
            ProjectHeaderView(project: project, projectManager: projectManager)
                .padding()
                .background(Color(.systemGray6))
            
            // Phases List
            PhaseListView(project: project, phaseManager: phaseManager)
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showingCreatePhase = true
                    }) {
                        Label("フェーズを追加", systemImage: "plus")
                    }
                    
                    Button(action: {
                        showingProjectSettings = true
                    }) {
                        Label("プロジェクト設定", systemImage: "gear")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            // PhaseListView will handle its own lifecycle
        }
        .sheet(isPresented: $showingCreatePhase) {
            CreatePhaseView(project: project, phaseManager: phaseManager)
        }
        .sheet(isPresented: $showingProjectSettings) {
            ProjectSettingsView(project: project, projectManager: projectManager)
        }
        .alert("エラー", isPresented: .constant(phaseManager.error != nil)) {
            Button("OK") {
                phaseManager.error = nil
            }
        } message: {
            Text(phaseManager.error?.localizedDescription ?? "")
        }
    }
    
}



#Preview {
    let sampleProject = Project(name: "Sample Project", description: "A sample project for preview", ownerId: "user1")
    ProjectDetailView(project: sampleProject, projectManager: ProjectManager())
}