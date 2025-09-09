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
        // Seed managers synchronously if already cached to prevent loading flicker on remount
        _phaseManager = State(initialValue: SharedManagerStore.shared.phaseManagerIfLoaded)
    }
    
    var body: some View {
        let liveProject = viewModel.presentProject
        VStack(spacing: 0) {
            // Project Header - Always show immediately
            ProjectHeaderView(project: liveProject, projectManager: projectManager)
                .padding()
                .background(Color(.systemGray6))
            
            // Phases List with improved loading UX
            if let pm = phaseManager {
                PhaseListView(project: liveProject, phaseManager: pm)
            } else {
                // Show project basic info while loading phases
                VStack(spacing: 16) {
                    // Quick project overview while loading
                    VStack(spacing: 8) {
                        if let description = liveProject.description, !description.isEmpty {
                            Text("プロジェクト概要")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        HStack(spacing: 20) {
                            Label("\(liveProject.memberIds.count) メンバー", systemImage: "person.2.fill")
                                .foregroundColor(.secondary)
                            
                            Label(liveProject.isCompleted ? "完了" : "進行中", systemImage: liveProject.isCompleted ? "checkmark.circle.fill" : "clock.fill")
                                .foregroundColor(liveProject.isCompleted ? .green : .orange)
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Minimal loading indicator
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("フェーズを読み込み中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // Use live project name so title updates immediately on selection and live changes
        .navigationTitle(liveProject.name)
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
            // Parallel initialization for better performance
            await withTaskGroup(of: Void.self) { group in
                // Bootstrap ViewModel first (this is usually fast)
                group.addTask {
                    await viewModel.bootstrap(store: sharedManagers)
                }
                
                // Load managers in parallel (prioritize PhaseManager for fastest UI update)
                group.addTask {
                    if phaseManager == nil {
                        let pm = await sharedManagers.getPhaseManager()
                        await MainActor.run {
                            phaseManager = pm
                            print("🎯 ProjectDetailView: PhaseManager loaded for project: \(project.name)")
                        }
                    }
                }
                
                group.addTask {
                    if authManager == nil {
                        let am = await sharedManagers.getAuthManager()
                        await MainActor.run {
                            authManager = am
                        }
                    }
                }
                
                group.addTask {
                    if aiGenerator == nil {
                        let ai = await sharedManagers.getAiGenerator()
                        await MainActor.run {
                            aiGenerator = ai
                        }
                    }
                }
                
                group.addTask {
                    if familyManager == nil {
                        let fm = await sharedManagers.getFamilyManager()
                        await MainActor.run {
                            familyManager = fm
                        }
                    }
                }
                
                // Load family data if needed
                if project.ownerType == .family {
                    group.addTask {
                        await loadOwnerFamily()
                    }
                }
            }
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

 
