//
//  ProjectDetailView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI
import FirebaseFirestore

struct ProjectDetailView: View {
    let project: Project
    @ObservedObject var projectManager: ProjectManager
    @StateObject private var phaseManager = PhaseManager()
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var aiGenerator = AITaskGenerator()
    @StateObject private var familyManager = FamilyManager()
    @State private var showingCreatePhase = false
    @State private var showingProjectSettings = false
    @State private var showingAIAnalysis = false
    @State private var showingAISettings = false
    @State private var selectedPhase: Phase?
    @State private var ownerFamily: Family?
    @State private var showOwnerFamily = false
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: {
                if let fam = ownerFamily { FamilyDetailView(family: fam) }
            }, isActive: $showOwnerFamily) { EmptyView() }
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
                if project.ownerType == .family {
                    Button {
                        loadOwnerFamilyAndOpen()
                    } label: {
                        Label("家族詳細", systemImage: "person.3.fill")
                    }
                }
                Menu {
                    Button(action: {
                        showingCreatePhase = true
                    }) {
                        Label("フェーズを追加", systemImage: "plus")
                    }
                    
                    Button(action: {
                        if aiGenerator.availableProviders.isEmpty {
                            showingAISettings = true
                        } else {
                            showingAIAnalysis = true
                        }
                    }) {
                        Label("AI分析", systemImage: "brain")
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
            if project.ownerType == .family { Task { await loadOwnerFamily() } }
        }
        .sheet(isPresented: $showingCreatePhase) {
            CreatePhaseView(project: project, phaseManager: phaseManager)
        }
        .sheet(isPresented: $showingProjectSettings) {
            ProjectSettingsView(project: project, projectManager: projectManager)
        }
        .sheet(isPresented: $showingAIAnalysis) {
            ProjectAIAnalysisView(
                project: project,
                phaseManager: phaseManager,
                aiGenerator: aiGenerator
            )
        }
        .sheet(isPresented: $showingAISettings) {
            APISettingsView()
                .onDisappear {
                    aiGenerator.updateAvailableProviders()
                }
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

private extension ProjectDetailView {
    func loadOwnerFamilyAndOpen() {
        Task {
            await loadOwnerFamily()
            await MainActor.run { showOwnerFamily = ownerFamily != nil }
        }
    }
    
    func loadOwnerFamily() async {
        guard project.ownerType == .family else { return }
        let fid = project.ownerId
        do {
            let doc = try await Firestore.firestore().collection("families").document(fid).getDocument()
            if let data = doc.data() {
                var fam = Family(name: data["name"] as? String ?? "")
                fam.id = fid
                fam.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                // members for count only; FamilyDetailView will refetch
                fam = Family(name: data["name"] as? String ?? "", members: data["members"] as? [String] ?? [])
                fam.id = fid
                await MainActor.run {
                    ownerFamily = fam
                }
            }
        } catch {
            print("Error loading owner family: \(error)")
        }
    }
}



#Preview {
    let sampleProject = Project(name: "Sample Project", description: "A sample project for preview", ownerId: "user1")
    ProjectDetailView(project: sampleProject, projectManager: ProjectManager())
}
