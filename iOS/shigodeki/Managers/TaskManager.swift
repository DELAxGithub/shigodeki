//
//  TaskManager.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class TaskManager: ObservableObject {
    @Published var taskLists: [TaskList] = []
    @Published var tasks: [String: [ShigodekiTask]] = [:] // taskListId -> [ShigodekiTask]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var taskListListeners: [ListenerRegistration] = []
    private var taskListeners: [String: ListenerRegistration] = [:]
    private let listenerQueue = DispatchQueue(label: "com.shigodeki.taskManager.listeners", qos: .userInteractive)
    
    // MARK: - TaskList Operations
    
    func createTaskList(name: String, familyId: String, creatorUserId: String, color: TaskListColor = .blue) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            return try await TaskListService.createTaskList(
                name: name, 
                familyId: familyId, 
                creatorUserId: creatorUserId, 
                color: color,
                db: db
            )
        } catch {
            errorMessage = "タスクリストの作成に失敗しました"
            throw error
        }
    }
    
    func loadTaskLists(familyId: String) async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            taskLists = try await TaskListService.loadTaskLists(familyId: familyId, db: db)
        } catch {
            errorMessage = "タスクリストの読み込みに失敗しました"
        }
    }
    
    // MARK: - Task Operations
    
    // MARK: - Phase-based Task Creation
    
    func createPhaseTask(title: String, description: String? = nil, taskListId: String, projectId: String, phaseId: String, creatorUserId: String, assignedTo: String? = nil, dueDate: Date? = nil, priority: TaskPriority = .medium, attachments: [String] = []) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            return try await TaskOperationService.createPhaseTask(
                title: title,
                description: description,
                taskListId: taskListId,
                projectId: projectId,
                phaseId: phaseId,
                creatorUserId: creatorUserId,
                assignedTo: assignedTo,
                dueDate: dueDate,
                priority: priority,
                attachments: attachments,
                db: db
            )
        } catch {
            errorMessage = "フェーズタスクの作成に失敗しました"
            throw error
        }
    }

    func createTask(title: String, description: String? = nil, taskListId: String, familyId: String, creatorUserId: String, assignedTo: String? = nil, dueDate: Date? = nil, priority: TaskPriority = .medium, tags: [String] = [], attachments: [String] = []) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            return try await TaskOperationService.createTask(
                title: title,
                description: description,
                taskListId: taskListId,
                familyId: familyId,
                creatorUserId: creatorUserId,
                assignedTo: assignedTo,
                dueDate: dueDate,
                priority: priority,
                tags: tags,
                attachments: attachments,
                db: db
            )
        } catch {
            errorMessage = "タスクの作成に失敗しました"
            throw error
        }
    }
    
    func toggleTaskCompletion(taskId: String, taskListId: String, familyId: String) async throws {
        do {
            try await TaskOperationService.toggleTaskCompletion(
                taskId: taskId,
                taskListId: taskListId,
                familyId: familyId,
                db: db
            )
        } catch {
            errorMessage = "タスクの更新に失敗しました"
            throw error
        }
    }
    
    func loadTasks(taskListId: String, familyId: String) async {
        do {
            tasks[taskListId] = try await TaskOperationService.loadTasks(
                taskListId: taskListId,
                familyId: familyId,
                db: db
            )
        } catch {
            errorMessage = "タスクの読み込みに失敗しました"
        }
    }
    
    // MARK: - Attachments
    
    func updateTaskAttachments(taskId: String, taskListId: String, familyId: String, attachments: [String]) async throws {
        do {
            try await TaskOperationService.updateTaskAttachments(
                taskId: taskId,
                taskListId: taskListId,
                familyId: familyId,
                attachments: attachments,
                db: db
            )
        } catch {
            errorMessage = "添付の更新に失敗しました"
            throw error
        }
    }
    
    // MARK: - Real-time Listeners
    
    func startListeningToTaskLists(familyId: String) {
        TaskRealtimeService.startListeningToTaskLists(
            familyId: familyId,
            taskListListeners: &taskListListeners,
            taskListsUpdateCallback: { [weak self] updatedTaskLists in
                self?.taskLists = updatedTaskLists
            },
            errorCallback: { [weak self] message in
                self?.errorMessage = message
            },
            db: db
        )
    }
    
    func startListeningToTasks(taskListId: String, familyId: String) {
        TaskRealtimeService.startListeningToTasks(
            taskListId: taskListId,
            familyId: familyId,
            taskListeners: &taskListeners,
            tasksUpdateCallback: { [weak self] taskListId, updatedTasks in
                self?.tasks[taskListId] = updatedTasks
            },
            errorCallback: { [weak self] message in
                self?.errorMessage = message
            },
            db: db
        )
    }
    
    func stopListeningToTaskLists() {
        TaskRealtimeService.stopListeningToTaskLists(taskListListeners: &taskListListeners)
    }
    
    func stopListeningToTasks(taskListId: String? = nil) {
        TaskRealtimeService.stopListeningToTasks(
            taskListId: taskListId,
            taskListeners: &taskListeners
        )
    }
    
    // MARK: - Cleanup
    
    func cleanupInactiveTaskListeners() {
        TaskRealtimeService.cleanupInactiveTaskListeners(
            taskLists: taskLists,
            taskListeners: &taskListeners,
            tasks: &tasks
        )
    }
    
    deinit {
        TaskRealtimeService.cleanupAllListeners(
            taskListListeners: &taskListListeners,
            taskListeners: &taskListeners
        )
    }
}

// MARK: - Error Types

enum TaskError: LocalizedError {
    case invalidName
    case invalidTitle
    case creationFailed(String)
    case updateFailed(String)
    case notFound
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "タスクリスト名が無効です"
        case .invalidTitle:
            return "タスクタイトルが無効です"
        case .creationFailed(let message):
            return "作成に失敗しました: \(message)"
        case .updateFailed(let message):
            return "更新に失敗しました: \(message)"
        case .notFound:
            return "タスクが見つかりません"
        case .permissionDenied:
            return "この操作の権限がありません"
        }
    }
}
