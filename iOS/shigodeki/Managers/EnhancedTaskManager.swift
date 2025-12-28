//
//  EnhancedTaskManager.swift
//  shigodeki
//
//  Refactored for CLAUDE.md compliance - Lightweight coordinator
//  CRUD operations extracted to TaskCRUDService.swift
//  Listener management extracted to TaskListenerService.swift
//

import Foundation
import Combine

@MainActor
class EnhancedTaskManager: ObservableObject {
    @Published var tasks: [ShigodekiTask] = []
    @Published var currentTask: ShigodekiTask?
    @Published var isLoading = false
    @Published var error: FirebaseError?
    
    private let crudService = TaskCRUDService()
    private let listenerService = TaskListenerService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupServiceBindings()
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.removeAllListeners()
        }
    }
    
    private func setupServiceBindings() {
        // Bind CRUD service state
        crudService.$isLoading
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
            
        crudService.$error
            .assign(to: \.error, on: self)
            .store(in: &cancellables)
        
        // Bind listener service state
        listenerService.$tasks
            .assign(to: \.tasks, on: self)
            .store(in: &cancellables)
            
        listenerService.$currentTask
            .assign(to: \.currentTask, on: self)
            .store(in: &cancellables)
            
        listenerService.$error
            .compactMap { $0 }
            .assign(to: \.error, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Task CRUD Operations
    
    func createTask(title: String, description: String? = nil, assignedTo: String? = nil, 
                   createdBy: String, dueDate: Date? = nil, priority: TaskPriority = .medium,
                   listId: String, phaseId: String, projectId: String, order: Int? = nil) async throws -> ShigodekiTask {
        var task = try await crudService.createTask(
            title: title, description: description, assignedTo: assignedTo,
            createdBy: createdBy, dueDate: dueDate, priority: priority,
            listId: listId, phaseId: phaseId, projectId: projectId, order: order
        )
        
        if FeatureFlags.undoEnabled {
            task.syncStatus = .pending
            if let id = task.id {
                Task {
                    _ = await SyncQueue.shared.enqueue(.confirmPhaseCreate(projectId: projectId, phaseId: phaseId, listId: listId, taskId: id))
                }
            }
        }

        listenerService.addOptimisticTask(task)
        return task
    }
    
    func createPhaseTask(title: String, description: String? = nil, assignedTo: String? = nil,
                         createdBy: String, dueDate: Date? = nil, priority: TaskPriority = .medium,
                         sectionId: String? = nil, sectionName: String? = nil,
                         phaseId: String, projectId: String, order: Int? = nil) async throws -> ShigodekiTask {
        var task = try await crudService.createPhaseTask(
            title: title, description: description, assignedTo: assignedTo,
            createdBy: createdBy, dueDate: dueDate, priority: priority,
            sectionId: sectionId, sectionName: sectionName,
            phaseId: phaseId, projectId: projectId, order: order
        )
        
        if FeatureFlags.undoEnabled {
            task.syncStatus = .pending
            if let id = task.id, !task.listId.isEmpty {
                Task {
                    _ = await SyncQueue.shared.enqueue(.confirmPhaseCreate(projectId: projectId, phaseId: phaseId, listId: task.listId, taskId: id))
                }
            }
        }

        listenerService.addOptimisticTask(task)
        return task
    }
    
    func getTask(id: String, listId: String, phaseId: String, projectId: String) async throws -> ShigodekiTask? {
        return try await crudService.getTask(id: id, listId: listId, phaseId: phaseId, projectId: projectId)
    }
    
    func getTasks(listId: String, phaseId: String, projectId: String) async throws -> [ShigodekiTask] {
        return try await crudService.getTasks(listId: listId, phaseId: phaseId, projectId: projectId)
    }
    
    func getPhaseTasks(phaseId: String, projectId: String) async throws -> [ShigodekiTask] {
        return try await crudService.getPhaseTasks(phaseId: phaseId, projectId: projectId)
    }
    
    func updateTask(_ task: ShigodekiTask) async throws -> ShigodekiTask {
        listenerService.updateOptimisticTask(task)
        return try await crudService.updateTask(task)
    }
    
    func updatePhaseTask(_ task: ShigodekiTask) async throws -> ShigodekiTask {
        listenerService.updateOptimisticTask(task)
        return try await crudService.updatePhaseTask(task)
    }
    
    func deleteTask(id: String, listId: String, phaseId: String, projectId: String) async throws {
        listenerService.markTaskForDeletion(id: id)
        try await crudService.deleteTask(id: id, listId: listId, phaseId: phaseId, projectId: projectId)
        if FeatureFlags.undoEnabled {
            Task {
                _ = await SyncQueue.shared.enqueue(.deletePhaseTask(projectId: projectId, phaseId: phaseId, listId: listId, taskId: id))
            }
        }
    }
    
    func updateTaskSection(_ task: ShigodekiTask, toSectionId: String?, toSectionName: String?) async throws {
        try await crudService.updateTaskSection(task, toSectionId: toSectionId, toSectionName: toSectionName)
        listenerService.updateOptimisticTask(task)
    }
    
    func reorderTasksInSection(_ tasksInSection: [ShigodekiTask], phaseId: String, projectId: String, sectionId: String?) async throws {
        listenerService.markReorderPending()
        try await crudService.reorderTasksInSection(tasksInSection, phaseId: phaseId, projectId: projectId, sectionId: sectionId)
    }
    
    // MARK: - Listener Management
    
    func startListeningForTasks(listId: String, phaseId: String, projectId: String) {
        listenerService.startListeningForTasks(listId: listId, phaseId: phaseId, projectId: projectId)
    }
    
    func startListeningForPhaseTasks(phaseId: String, projectId: String) {
        listenerService.startListeningForPhaseTasks(phaseId: phaseId, projectId: projectId)
    }
    
    func startListeningForTask(id: String, listId: String, phaseId: String, projectId: String) {
        listenerService.startListeningForTask(id: id, listId: listId, phaseId: phaseId, projectId: projectId)
    }
    
    func removeAllListeners() {
        listenerService.removeAllListeners()
    }
}
