//
//  PhaseTaskListViewModel.swift
//  shigodeki
//
//  Centralizes TaskList listening and loading for a phase
//

import Foundation
import Combine

@MainActor
class PhaseTaskListViewModel: ObservableObject {
    @Published private(set) var lists: [TaskList] = []
    @Published private(set) var isLoading: Bool = false
    
    private var taskListManager: TaskListManager?
    private let phaseId: String
    private let projectId: String
    
    init(phaseId: String, projectId: String) {
        self.phaseId = phaseId
        self.projectId = projectId
    }
    
    func bootstrap(store: SharedManagerStore) async {
        let manager = await store.getTaskListManager()
        self.taskListManager = manager
        
        await reload()
        manager.startListeningForTaskLists(phaseId: phaseId, projectId: projectId)
        
        // Bind manager state to VM
        manager.$taskLists
            .receive(on: RunLoop.main)
            .sink { [weak self] lists in self?.lists = lists }
            .store(in: &cancellables)
        manager.$isLoading
            .receive(on: RunLoop.main)
            .sink { [weak self] loading in self?.isLoading = loading }
            .store(in: &cancellables)
    }
    
    func reload() async {
        guard let manager = taskListManager else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await manager.getTaskLists(phaseId: phaseId, projectId: projectId)
            self.lists = fetched
        } catch {
            // Keep previous lists on error
        }
    }
    
    // MARK: - Private
    private var cancellables: Set<AnyCancellable> = []
}
