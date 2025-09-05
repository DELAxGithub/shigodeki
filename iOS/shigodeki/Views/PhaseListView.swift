//
//  PhaseListView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct PhaseListView: View {
    let project: Project
    @ObservedObject var phaseManager: PhaseManager
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @ObservedObject private var authManager = AuthenticationManager.shared
    @State private var showingCreatePhase = false
    @State private var selectedPhase: Phase?
    @State private var selectedPhaseId: String? = nil
    @Environment(\.dismiss) private var dismiss
    var onSelectPhase: ((Phase) -> Void)? = nil
    @State private var listCounts: [String: Int] = [:] // now represents section counts
    var onSelectTaskList: ((TaskList, Phase) -> Void)? = nil
    
    var body: some View {
        VStack {
            BreadcrumbBar(items: [project.name, "フェーズ"]) { idx in
                print("UI: Breadcrumb tapped idx=\(idx) at PhaseListView")
                if idx == 0 { dismiss() }
            }
                .padding(.horizontal)
            if phaseManager.phases.isEmpty && !phaseManager.isLoading {
                // Empty phases state
                VStack(spacing: 24) {
                    Image(systemName: "list.number")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 8) {
                        Text("フェーズがありません")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("プロジェクトを段階的に進めるため\nフェーズを作成しましょう")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        showingCreatePhase = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("フェーズを作成")
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
                // Hidden navigator driven by selectedPhaseId for robust push
                NavigationLink(
                    isActive: Binding(
                        get: { selectedPhaseId != nil },
                        set: { if !$0 { selectedPhaseId = nil } }
                    )
                ) {
                    if let pid = selectedPhaseId, let p = phaseManager.phases.first(where: { $0.id == pid }) {
                        PhaseTaskView(phase: p, project: project)
                    } else {
                        EmptyView()
                    }
                } label: { EmptyView() }
                .hidden()
                List {
                    ForEach(phaseManager.phases) { phase in
                        if let onSelectPhase {
                            Button { onSelectPhase(phase) } label: {
                                PhaseRowView(phase: phase, phaseManager: phaseManager, taskListCount: listCounts[phase.id ?? ""])
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                HapticFeedbackManager.shared.light()
                                if let pid = phase.id { selectedPhaseId = pid }
                                print("UI: Phase tapped -> \(phase.name) [id=\(phase.id ?? "")] ")
                            } label: {
                                PhaseRowView(phase: phase, phaseManager: phaseManager, taskListCount: listCounts[phase.id ?? ""])
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onMove(perform: movePhases)
                    .onDelete(perform: deletePhases)
                }
                .refreshable {
                    await loadPhases()
                }
            }
        }
        .loadingOverlay(phaseManager.isLoading, message: "フェーズを更新中...")
        .navigationTitle("フェーズ")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    showingCreatePhase = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            loadPhases()
            startListeningToPhases()
            Task { await loadListCounts() }
        }
        .onChange(of: phaseManager.phases.count) { _, _ in
            Task { await loadListCounts() }
        }
        .sheet(isPresented: $showingCreatePhase) {
            CreatePhaseView(project: project, phaseManager: phaseManager)
        }
        .alert("エラー", isPresented: .constant(phaseManager.error != nil)) {
            Button("OK") {
                phaseManager.error = nil
            }
        } message: {
            Text(phaseManager.error?.localizedDescription ?? "")
        }
    }
    
    private func loadPhases() {
        guard let projectId = project.id else { return }
        
        Task {
            do {
                let phases = try await phaseManager.getPhases(projectId: projectId)
                await MainActor.run {
                    phaseManager.phases = phases
                }
                print("📥 PhaseListView: Loaded \(phases.count) phases for project \(projectId)")
            } catch {
                print("Error loading phases: \(error)")
            }
        }
    }
    
    private func loadListCounts() async {
        guard let projectId = project.id else { return }
        var result: [String: Int] = [:]
        let sectionManager = PhaseSectionManager()
        for ph in phaseManager.phases {
            guard let pid = ph.id else { continue }
            do {
                let sections = try await sectionManager.getSections(phaseId: pid, projectId: projectId)
                result[pid] = sections.count
            } catch { }
        }
        await MainActor.run { self.listCounts = result }
    }
    
    private func startListeningToPhases() {
        guard let projectId = project.id else { return }
        phaseManager.startListeningForPhases(projectId: projectId)
    }
    
    private func movePhases(from source: IndexSet, to destination: Int) {
        var reorderedPhases = phaseManager.phases
        reorderedPhases.move(fromOffsets: source, toOffset: destination)
        // Optimistic local update to reflect immediately
        phaseManager.phases = reorderedPhases
        print("UI: Phase reorder gesture from=\(Array(source)) to=\(destination); newOrder=\(reorderedPhases.map{ $0.name })")
        
        guard let projectId = project.id else { return }
        
        Task {
            do {
                try await phaseManager.reorderPhases(reorderedPhases, projectId: projectId)
            } catch {
                print("Error reordering phases: \(error)")
            }
        }
    }
    
    private func deletePhases(at offsets: IndexSet) {
        guard let projectId = project.id else { return }
        
        for index in offsets {
            let phase = phaseManager.phases[index]
            guard let phaseId = phase.id else { continue }
            
            Task {
                do {
                    try await phaseManager.deletePhase(id: phaseId, projectId: projectId)
                } catch {
                    print("Error deleting phase: \(error)")
                }
            }
        }
    }
}

#Preview {
    let sampleProject = Project(name: "Sample Project", description: "A sample project for preview", ownerId: "user1")
    PhaseListView(project: sampleProject, phaseManager: PhaseManager())
}