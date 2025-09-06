//
//  PhaseTaskViewService.swift
//  shigodeki
//
//  Extracted from PhaseTaskView.swift for CLAUDE.md compliance
//  Phase task view business logic and data management
//

import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class PhaseTaskViewService: ObservableObject {
    @Published var tasks: [ShigodekiTask] = []
    @Published var isLoading = false
    
    private var taskManager: EnhancedTaskManager?
    private var phaseId: String = ""
    private var projectId: String = ""
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    func bootstrap(phaseId: String, projectId: String, store: SharedManagerStore) async {
        self.phaseId = phaseId
        self.projectId = projectId
        let m = await store.getTaskManager()
        self.taskManager = m
        await reload()
        m.startListeningForPhaseTasks(phaseId: phaseId, projectId: projectId)
        m.$tasks.receive(on: RunLoop.main).sink { [weak self] in 
            self?.tasks = $0 
        }.store(in: &cancellables)
        m.$isLoading.receive(on: RunLoop.main).sink { [weak self] in 
            self?.isLoading = $0 
        }.store(in: &cancellables)
    }
    
    func reload() async {
        guard let m = taskManager else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let phaseTasks = try await m.getPhaseTasks(phaseId: phaseId, projectId: projectId)
            tasks = phaseTasks
            if tasks.isEmpty {
                // Fallback for legacy data: flatten list-based tasks into sections
                tasks = try await LegacyDataBridge.flattenLegacyTasks(phaseId: phaseId, projectId: projectId)
            }
        } catch {
            // Keep previous tasks on error
        }
    }
    
    // MARK: - Task Operations
    
    func moveTask(_ task: ShigodekiTask, to targetSection: PhaseSection?, project: Project, phase: Phase) async {
        guard let m = taskManager else { return }
        do {
            try await m.updateTaskSection(task, toSectionId: targetSection?.id, toSectionName: targetSection?.name)
            await reload()
        } catch { }
    }
    
    func createTask(title: String, section: PhaseSection?, project: Project, phase: Phase) async {
        guard let m = taskManager else { return }
        let auth = await SharedManagerStore.shared.getAuthManager()
        let uid = auth.currentUserId ?? ""
        do {
            _ = try await m.createPhaseTask(
                title: title,
                description: nil,
                assignedTo: nil,
                createdBy: uid,
                dueDate: nil,
                priority: .medium,
                sectionId: section?.id,
                sectionName: section?.name,
                phaseId: phase.id ?? "",
                projectId: project.id ?? "",
                order: nil
            )
            await reload()
        } catch { }
    }
    
    func reorderTasks(in section: PhaseSection, moveFrom source: IndexSet, to destination: Int) async {
        guard let m = taskManager else { return }
        var items = tasksIn(sectionId: section.id)
        items.move(fromOffsets: source, toOffset: destination)
        do { 
            try await m.reorderTasksInSection(items, phaseId: phaseId, projectId: projectId, sectionId: section.id) 
        } catch { }
        await MainActor.run { 
            self.tasks = mergeReordered(items, for: section.id) 
        }
    }
    
    // MARK: - Section Management
    
    func generateGroupedSections(from sectionManager: PhaseSectionManager) -> [PhaseSection] {
        var result = sectionManager.sections
        let knownIds = Set(result.compactMap { $0.id })
        
        // Add a pseudo section for tasks without section
        if tasks.contains(where: { ($0.sectionId ?? "").isEmpty }) {
            result.insert(PhaseSection(name: "未分類", order: -1), at: 0)
        }
        
        // Add synthetic sections for orphan sectionIds
        let orphanIds = Set(tasks.compactMap { $0.sectionId }).subtracting(knownIds)
        for oid in orphanIds {
            var name = "その他"
            if let t = tasks.first(where: { $0.sectionId == oid }), 
               let n = t.sectionName, !n.isEmpty { 
                name = n 
            }
            var sec = PhaseSection(name: name, order: 999)
            sec.id = oid
            result.append(sec)
        }
        return result.sorted { $0.order < $1.order }
    }
    
    func tasksInSection(_ sectionId: String?) -> [ShigodekiTask] {
        if sectionId == nil || sectionId == "" { 
            return tasks.filter { ($0.sectionId ?? "").isEmpty } 
        }
        return tasks.filter { $0.sectionId == sectionId }
    }
    
    // MARK: - Drag & Drop Operations
    
    func handleDrop(providers: [NSItemProvider], into section: PhaseSection, project: Project, phase: Phase) -> Bool {
        let typeId = UTType.text.identifier
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(typeId) }) else { 
            return false 
        }
        provider.loadItem(forTypeIdentifier: typeId, options: nil) { [weak self] item, _ in
            Task { @MainActor in
                guard let self = self else { return }
                let taskId: String?
                if let data = item as? Data {
                    taskId = String(data: data, encoding: .utf8)
                } else if let str = item as? String {
                    taskId = str
                } else {
                    return
                }
                
                guard let id = taskId, 
                      let task = self.tasks.first(where: { $0.id == id }) else { return }
                await self.moveTask(task, to: section, project: project, phase: phase)
            }
        }
        return true
    }
    
    // MARK: - Private Helpers
    
    private func tasksIn(sectionId: String?) -> [ShigodekiTask] {
        if sectionId == nil || sectionId == "" { 
            return tasks.filter { ($0.sectionId ?? "").isEmpty } 
        }
        return tasks.filter { $0.sectionId == sectionId }
    }
    
    private func mergeReordered(_ reordered: [ShigodekiTask], for sectionId: String?) -> [ShigodekiTask] {
        var all = tasks
        let ids = Set(reordered.compactMap { $0.id })
        all.removeAll { ids.contains($0.id ?? "") && (($0.sectionId ?? "") == (sectionId ?? "")) }
        all.append(contentsOf: reordered)
        return all
    }
}