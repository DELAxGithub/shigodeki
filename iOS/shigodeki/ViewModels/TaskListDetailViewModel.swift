//
//  TaskListDetailViewModel.swift
//  shigodeki
//
//  Lightweight VM for TaskListDetailView: binds to EnhancedTaskManager
//

import Foundation
import Combine

@MainActor
class TaskListDetailViewModel: ObservableObject {
    @Published private(set) var tasks: [ShigodekiTask] = []
    @Published private(set) var isLoading: Bool = false
    
    private var taskManager: EnhancedTaskManager?
    private let listId: String
    private let phaseId: String
    private let projectId: String
    private var cancellables: Set<AnyCancellable> = []
    
    init(listId: String, phaseId: String, projectId: String) {
        self.listId = listId
        self.phaseId = phaseId
        self.projectId = projectId
    }
    
    func bootstrap(store: SharedManagerStore) async {
        let manager = await store.getTaskManager()
        self.taskManager = manager
        
        await reload()
        manager.startListeningForTasks(listId: listId, phaseId: phaseId, projectId: projectId)
        
        manager.$tasks
            .receive(on: RunLoop.main)
            .sink { [weak self] tasks in self?.tasks = tasks }
            .store(in: &cancellables)
        manager.$isLoading
            .receive(on: RunLoop.main)
            .sink { [weak self] loading in self?.isLoading = loading }
            .store(in: &cancellables)
    }
    
    func reload() async {
        guard let manager = taskManager else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await manager.getTasks(listId: listId, phaseId: phaseId, projectId: projectId)
            self.tasks = fetched
        } catch {
            // keep previous
        }
    }
    
    func toggleCompletion(_ task: ShigodekiTask) async {
        guard var updated = tasks.first(where: { $0.id == task.id }) else { return }
        updated.isCompleted.toggle()
        do { _ = try await taskManager?.updateTask(updated) } catch { }
    }
    
    func getManager() -> EnhancedTaskManager? { taskManager }
}

