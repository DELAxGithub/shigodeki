//
//  PhaseTaskView.swift
//  shigodeki
//
//  Refactored for CLAUDE.md compliance - Lightweight coordinator view
//  UI components extracted to PhaseTaskViewComponents.swift
//  Business logic extracted to PhaseTaskViewService.swift
//

import SwiftUI
import UniformTypeIdentifiers

struct PhaseTaskView: View {
    let phase: Phase
    let project: Project
    @EnvironmentObject var sharedManagers: SharedManagerStore
    
    @StateObject private var service = PhaseTaskViewService()
    @StateObject private var sectionManager = PhaseSectionManager()
    @Environment(\.dismiss) private var dismiss
    
    // UI State
    @State private var showingCreateSection = false
    @State private var newSectionName = ""
    @State private var renamingSection: PhaseSection? = nil
    @State private var showingCreateTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskSectionId: String? = nil
    @State private var selectedTaskId: String? = nil
    @State private var inlineNewTitle: String = ""
    
    var body: some View {
        VStack {
            BreadcrumbBar(items: [project.name, phase.name, "タスク"]) { idx in
                if idx == 0 { dismiss() } else if idx == 1 { dismiss() }
            }
            .padding(.horizontal)
            
            content
            // Hidden navigator
            NavigationLink(isActive: Binding(get: { selectedTaskId != nil }, set: { if !$0 { selectedTaskId = nil } })) {
                if let tid = selectedTaskId, let t = service.tasks.first(where: { $0.id == tid }) {
                    PhaseTaskDetailView(task: t, project: project, phase: phase)
                } else {
                    EmptyView()
                }
            } label: { EmptyView() }.hidden()
        }
        .navigationTitle(phase.name)
        .navigationBarBackButtonHidden(true)
        .task {
            // 🚨 クラッシュ対策: IDがnilの場合に処理を中断し、空文字でのFirestoreアクセスを防ぐ
            guard let phaseId = phase.id, !phaseId.isEmpty,
                  let projectId = project.id, !projectId.isEmpty else {
                print("❌ PhaseTaskView: Missing phaseId or projectId. Cannot bootstrap.")
                return
            }
            await service.bootstrap(phaseId: phaseId, projectId: projectId, store: sharedManagers)
            sectionManager.startListening(phaseId: phaseId, projectId: projectId)
        }
        .refreshable { await service.reload() }
        .loadingOverlay(service.isLoading, message: "タスクを更新中...")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    EditButton()
                    Button { showingCreateTask = true } label: { Image(systemName: "plus.circle") }
                    Button { showingCreateSection = true } label: { Image(systemName: "folder.badge.plus") }
                }
            }
        }
        .sheet(isPresented: $showingCreateTask) {
            TaskCreationSheet(
                isPresented: $showingCreateTask,
                newTaskTitle: $newTaskTitle,
                newTaskSectionId: $newTaskSectionId,
                groupedSections: groupedSections
            ) { title, section in
                Task {
                    await service.createTask(title: title, section: section, project: project, phase: phase)
                }
            }
        }
        .sheet(isPresented: $showingCreateSection) {
            SectionCreationSheet(
                isPresented: $showingCreateSection,
                newSectionName: $newSectionName
            ) { name in
                Task {
                    try? await sectionManager.createSection(name: name, phaseId: phase.id ?? "", projectId: project.id ?? "")
                }
            }
        }
        .sheet(item: $renamingSection) { sec in
            RenameSectionSheet(section: sec, initialName: sec.name) { newName in
                var updated = sec; updated.name = newName
                Task { try? await sectionManager.updateSection(updated, phaseId: phase.id ?? "", projectId: project.id ?? "") }
            }
        }
    }
    
    private var content: some View {
        PhaseTaskContentView(
            tasks: service.tasks,
            groupedSections: groupedSections,
            selectedTaskId: $selectedTaskId,
            inlineNewTitle: $inlineNewTitle,
            tasksInSection: service.tasksInSection,
            onTaskTap: { task in selectedTaskId = task.id },
            onTaskMove: { task, target in
                Task {
                    await service.moveTask(task, to: target, project: project, phase: phase)
                }
            },
            onTaskReorder: { section, indices, newOffset in
                Task {
                    await service.reorderTasks(in: section, moveFrom: indices, to: newOffset)
                }
            },
            onSectionRename: { section in
                renamingSection = section
            },
            onSectionDelete: { section in
                if let sid = section.id {
                    Task {
                        try? await sectionManager.deleteSection(id: sid, phaseId: phase.id ?? "", projectId: project.id ?? "")
                    }
                }
            },
            onQuickAdd: quickAdd,
            onDrop: { providers, section in
                service.handleDrop(providers: providers, into: section, project: project, phase: phase)
            }
        )
    }
    
    private var groupedSections: [PhaseSection] {
        service.generateGroupedSections(from: sectionManager)
    }

    private func quickAdd() {
        let title = inlineNewTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        Task {
            await service.createTask(title: title, section: nil, project: project, phase: phase)
            inlineNewTitle = ""
        }
    }
}

