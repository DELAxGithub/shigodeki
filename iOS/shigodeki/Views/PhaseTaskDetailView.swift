//
//  PhaseTaskDetailView.swift
//  shigodeki
//
//  Refactored for CLAUDE.md compliance - Lightweight coordinator view
//  UI sections extracted to PhaseTaskDetailSections.swift
//  Business logic extracted to PhaseTaskDetailService.swift
//

import SwiftUI
import PhotosUI

struct PhaseTaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sharedManagers: SharedManagerStore
    
    let project: Project
    let phase: Phase
    let task: ShigodekiTask
    
    @StateObject private var viewModel: PhaseTaskDetailViewModel
    @StateObject private var aiStateManager = AIStateManager()
    @StateObject private var sectionManager = PhaseSectionManager()
    @StateObject private var tagManager = TagManager()
    @StateObject private var service = PhaseTaskDetailService()
    
    @State private var subtasks: [Subtask] = []
    @State private var newSubtaskTitle: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var localImages: [UIImage] = []
    @State private var projectMembers: [ProjectMember] = []
    @State private var selectedSectionId: String? = nil
    @State private var showingTagEditor = false
    @State private var showAISettings = false
    
    init(task: ShigodekiTask, project: Project, phase: Phase) {
        self.task = task
        self.project = project
        self.phase = phase
        self._viewModel = StateObject(wrappedValue: PhaseTaskDetailViewModel(task: task, project: project, phase: phase))
    }
    
    var body: some View {
        Form {
            TaskBasicInfoSection(viewModel: viewModel, task: task)
            
            TaskDescriptionSection(viewModel: viewModel)
            
            TaskAssignmentTagsSection(
                viewModel: viewModel,
                tagManager: tagManager,
                sectionManager: sectionManager,
                projectMembers: projectMembers,
                task: task,
                showingTagEditor: $showingTagEditor,
                selectedSectionId: $selectedSectionId
            )
            
            // TODO: Implement AttachmentsSectionView component
            // AttachmentsSectionView(
            //     selectedPhotos: $selectedPhotos,
            //     localImages: $localImages,
            //     onImageData: { _ in }
            // )
            
            TaskSubtasksSection(
                subtasks: subtasks,
                newSubtaskTitle: $newSubtaskTitle,
                onToggleSubtask: { toggleSubtask($0) },
                onDeleteSubtask: { deleteSubtask($0) },
                onAddSubtask: { addSubtask() }
            )
            
            TaskRelatedLinksSection(task: task)
            
            TaskAISupportSection(
                aiStateManager: aiStateManager,
                viewModel: viewModel,
                task: task,
                showAISettings: $showAISettings,
                onGenerateSubtasks: { aiSplit() }
            )
        }
        .navigationTitle("タスク詳細")
        .onAppear {
            initializeView()
        }
        .onDisappear {
            tagManager.stopListening()
        }
        .sheet(isPresented: $showingTagEditor) {
            TaskTagEditorSheet(
                currentTags: viewModel.tags,
                availableTags: tagManager.tags.filter { $0.projectId == viewModel.projectId ?? "" },
                projectId: viewModel.projectId ?? "",
                createdBy: task.createdBy,
                onSave: { updatedTags in
                    viewModel.updateTags(updatedTags)
                }
            )
        }
        .sheet(isPresented: $showAISettings) {
            APISettingsView()
        }
        .toolbar { 
            ToolbarItem(placement: .navigationBarTrailing) { 
                Button("保存") { 
                    Task { 
                        await saveTask()
                    } 
                } 
                .disabled(!viewModel.canSave)
            } 
        }
        .task {
            await loadInitialData()
        }
    }
}


// MARK: - Private Methods

extension PhaseTaskDetailView {
    private func initializeView() {
        aiStateManager.checkConfiguration()
        
        Task {
            if let projectId = viewModel.projectId {
                await tagManager.loadTags(projectId: projectId)
                tagManager.startListening(projectId: projectId)
            }
        }
    }
    
    private func loadInitialData() async {
        async let subtasksTask = service.loadSubtasks(task: task, project: project, phase: phase)
        async let membersTask = service.loadProjectMembers(project: project)
        
        let (loadedSubtasks, loadedMembers) = await (subtasksTask, membersTask)
        
        await MainActor.run {
            subtasks = loadedSubtasks
            projectMembers = loadedMembers
            selectedSectionId = task.sectionId
        }
        
        sectionManager.startListening(phaseId: phase.id ?? "", projectId: project.id ?? "")
    }
    
    private func saveTask() async {
        do {
            try await viewModel.save()
            dismiss()
        } catch {
            print("⚠️ 保存エラー: \(error)")
        }
    }
    
    // MARK: - Subtask Operations
    
    private func addSubtask() {
        Task {
            do {
                _ = try await service.addSubtask(title: newSubtaskTitle, task: task, project: project, phase: phase)
                newSubtaskTitle = ""
                subtasks = await service.loadSubtasks(task: task, project: project, phase: phase)
            } catch {
                print("❌ Failed to add subtask: \(error)")
            }
        }
    }
    
    private func deleteSubtask(_ subtask: Subtask) {
        Task {
            do {
                try await service.deleteSubtask(subtask, task: task, project: project, phase: phase)
                subtasks = await service.loadSubtasks(task: task, project: project, phase: phase)
            } catch {
                print("❌ Failed to delete subtask: \(error)")
            }
        }
    }
    
    private func toggleSubtask(_ subtask: Subtask) {
        Task {
            do {
                _ = try await service.toggleSubtask(subtask)
                subtasks = await service.loadSubtasks(task: task, project: project, phase: phase)
            } catch {
                print("❌ Failed to toggle subtask: \(error)")
            }
        }
    }
    
    // MARK: - AI Operations
    
    private func aiSplit() {
        Task { @MainActor in
            if let suggestions = await service.generateSubtasksWithAI(task: task) {
                for suggestion in suggestions {
                    newSubtaskTitle = suggestion.title
                    addSubtask()
                }
            }
        }
    }
}

