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
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @StateObject private var viewModel: ProjectDetailViewModel
    @State private var phaseManager: PhaseManager?
    @State private var authManager: AuthenticationManager?
    @State private var aiGenerator: AITaskGenerator?
    @State private var familyManager: FamilyManager?
    @State private var showingCreatePhase = false
    @State private var showingProjectSettings = false
    @State private var showingAIAnalysis = false
    @State private var showingAISettings = false
    @State private var selectedPhase: Phase?
    @State private var ownerFamily: Family?
    @State private var showOwnerFamily = false
    
    
    init(project: Project, projectManager: ProjectManager) {
        self.project = project
        self.projectManager = projectManager
        _viewModel = StateObject(wrappedValue: ProjectDetailViewModel(project: project))
    }
    
    var body: some View {
        let liveProject = viewModel.presentProject
        VStack(spacing: 0) {
            // Project Header
            ProjectHeaderView(project: liveProject, projectManager: projectManager)
                .padding()
                .background(Color(.systemGray6))
            
            // Phases List
            if let pm = phaseManager {
                PhaseListView(project: liveProject, phaseManager: pm)
            } else {
                LoadingStateView(message: "フェーズを初期化中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
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
                        if (aiGenerator?.availableProviders.isEmpty ?? true) {
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
        .task {
            await viewModel.bootstrap(store: sharedManagers)
            if phaseManager == nil { phaseManager = await sharedManagers.getPhaseManager() }
            if authManager == nil { authManager = await sharedManagers.getAuthManager() }
            if aiGenerator == nil { aiGenerator = await sharedManagers.getAiGenerator() }
            if familyManager == nil { familyManager = await sharedManagers.getFamilyManager() }
            if project.ownerType == .family { await loadOwnerFamily() }
        }
        .sheet(isPresented: $showingCreatePhase) {
            if let pm = phaseManager {
                CreatePhaseView(project: liveProject, phaseManager: pm)
            }
        }
        .sheet(isPresented: $showingProjectSettings) {
            ProjectSettingsView(project: liveProject, projectManager: projectManager)
        }
        .sheet(isPresented: $showOwnerFamily) {
            if let fam = ownerFamily { FamilyDetailView(family: fam) }
        }
        .sheet(isPresented: $showingAIAnalysis) {
            if let pm = phaseManager, let ai = aiGenerator {
                ProjectAIAnalysisView(
                    project: liveProject,
                    phaseManager: pm,
                    aiGenerator: ai
                )
            }
        }
        .sheet(isPresented: $showingAISettings) {
            APISettingsView()
                .onDisappear {
                    aiGenerator?.updateAvailableProviders()
                }
        }
        .alert("エラー", isPresented: .constant(phaseManager?.error != nil)) {
            Button("OK") {
                phaseManager?.error = nil
            }
        } message: {
            Text(phaseManager?.error?.localizedDescription ?? "")
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

 
