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
        
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TaskError.invalidName
        }
        
        var taskList = TaskList(name: name.trimmingCharacters(in: .whitespacesAndNewlines), 
                               familyId: familyId, 
                               createdBy: creatorUserId, 
                               color: color)
        taskList.createdAt = Date()
        
        let taskListData: [String: Any] = [
            "name": taskList.name,
            "familyId": taskList.familyId as Any,
            "createdBy": taskList.createdBy,
            "color": taskList.color.rawValue,
            "isArchived": taskList.isArchived,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        do {
            let taskListRef = try await db.collection("families").document(familyId)
                .collection("taskLists").addDocument(data: taskListData)
            let taskListId = taskListRef.documentID
            
            print("TaskList created successfully with ID: \(taskListId)")
            return taskListId
            
        } catch {
            print("Error creating task list: \(error)")
            errorMessage = "タスクリストの作成に失敗しました"
            throw TaskError.creationFailed(error.localizedDescription)
        }
    }
    
    func loadTaskLists(familyId: String) async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let taskListsSnapshot = try await db.collection("families").document(familyId)
                .collection("taskLists")
                .whereField("isArchived", isEqualTo: false)
                .order(by: "createdAt", descending: false)
                .getDocuments()
            
            var loadedTaskLists: [TaskList] = []
            
            for document in taskListsSnapshot.documents {
                if let taskList = parseTaskList(from: document) {
                    loadedTaskLists.append(taskList)
                }
            }
            
            taskLists = loadedTaskLists
            
        } catch {
            print("Error loading task lists: \(error)")
            errorMessage = "タスクリストの読み込みに失敗しました"
        }
    }
    
    // MARK: - Task Operations
    
    // MARK: - Phase-based Task Creation
    
    func createPhaseTask(title: String, description: String? = nil, taskListId: String, projectId: String, phaseId: String, creatorUserId: String, assignedTo: String? = nil, dueDate: Date? = nil, priority: TaskPriority = .medium) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TaskError.invalidTitle
        }
        
        var task = ShigodekiTask(title: title.trimmingCharacters(in: .whitespacesAndNewlines), 
                       description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
                       assignedTo: assignedTo,
                       createdBy: creatorUserId,
                       dueDate: dueDate,
                       priority: priority)
        task.createdAt = Date()
        
        let taskData: [String: Any] = [
            "title": task.title,
            "description": task.description ?? "",
            "isCompleted": task.isCompleted,
            "assignedTo": task.assignedTo ?? "",
            "createdBy": task.createdBy,
            "priority": task.priority.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "completedAt": NSNull(),
            "dueDate": task.dueDate != nil ? Timestamp(date: task.dueDate!) : NSNull()
        ]
        
        do {
            // 🚀 Optimistic UI Update: Add to local list immediately
            print("⚡ Adding phase task optimistically to UI")
            task.id = "optimistic_\(UUID().uuidString)"
            
            if tasks[taskListId] == nil {
                tasks[taskListId] = []
            }
            tasks[taskListId]?.append(task)
            
            // Save to project-based path: projects/{projectId}/phases/{phaseId}/lists/{taskListId}/tasks
            let taskRef = try await db.collection("projects").document(projectId)
                .collection("phases").document(phaseId)
                .collection("lists").document(taskListId)
                .collection("tasks").addDocument(data: taskData)
            let taskId = taskRef.documentID
            
            // Update the local task with the real ID from Firestore
            if let taskIndex = tasks[taskListId]?.firstIndex(where: { $0.id == task.id }) {
                tasks[taskListId]?[taskIndex].id = taskId
            }
            
            print("Phase task created successfully with ID: \(taskId)")
            return taskId
            
        } catch {
            print("Error creating phase task: \(error)")
            errorMessage = "フェーズタスクの作成に失敗しました"
            
            // 🔄 Rollback: Remove optimistically added task on error
            print("🔄 Rolling back optimistic UI update")
            tasks[taskListId]?.removeAll { $0.id == task.id }
            
            throw TaskError.creationFailed(error.localizedDescription)
        }
    }

    func createTask(title: String, description: String? = nil, taskListId: String, familyId: String, creatorUserId: String, assignedTo: String? = nil, dueDate: Date? = nil, priority: TaskPriority = .medium, tags: [String] = []) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TaskError.invalidTitle
        }
        
        var task = ShigodekiTask(title: title.trimmingCharacters(in: .whitespacesAndNewlines), 
                       description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
                       assignedTo: assignedTo,
                       createdBy: creatorUserId,
                       dueDate: dueDate,
                       priority: priority)
        task.createdAt = Date()
        task.tags = tags
        
        let taskData: [String: Any] = [
            "title": task.title,
            "description": task.description ?? "",
            "isCompleted": task.isCompleted,
            "assignedTo": task.assignedTo ?? "",
            "createdBy": task.createdBy,
            "priority": task.priority.rawValue,
            "tags": task.tags,
            "createdAt": FieldValue.serverTimestamp(),
            "completedAt": NSNull(),
            "dueDate": task.dueDate != nil ? Timestamp(date: task.dueDate!) : NSNull()
        ]
        
        do {
            // 🚀 Optimistic UI Update: Add to local list immediately
            print("⚡ Adding task optimistically to UI")
            task.id = "optimistic_\(UUID().uuidString)"
            
            if tasks[taskListId] == nil {
                tasks[taskListId] = []
            }
            tasks[taskListId]?.append(task)
            
            let taskRef = try await db.collection("families").document(familyId)
                .collection("taskLists").document(taskListId)
                .collection("tasks").addDocument(data: taskData)
            let taskId = taskRef.documentID
            
            // Update the local task with the real ID from Firestore
            if let taskIndex = tasks[taskListId]?.firstIndex(where: { $0.id == task.id }) {
                tasks[taskListId]?[taskIndex].id = taskId
            }
            
            print("Task created successfully with ID: \(taskId)")
            return taskId
            
        } catch {
            print("Error creating task: \(error)")
            errorMessage = "タスクの作成に失敗しました"
            
            // 🔄 Rollback: Remove optimistically added task on error
            print("🔄 Rolling back optimistic UI update")
            tasks[taskListId]?.removeAll { $0.id == task.id }
            
            throw TaskError.creationFailed(error.localizedDescription)
        }
    }
    
    func toggleTaskCompletion(taskId: String, taskListId: String, familyId: String) async throws {
        let taskRef = db.collection("families").document(familyId)
            .collection("taskLists").document(taskListId)
            .collection("tasks").document(taskId)
        
        do {
            let taskDoc = try await taskRef.getDocument()
            guard let data = taskDoc.data(),
                  let isCompleted = data["isCompleted"] as? Bool else {
                throw TaskError.notFound
            }
            
            let newCompletedState = !isCompleted
            let updateData: [String: Any] = [
                "isCompleted": newCompletedState,
                "completedAt": newCompletedState ? FieldValue.serverTimestamp() : NSNull()
            ]
            
            try await taskRef.updateData(updateData)
            
        } catch {
            print("Error toggling task completion: \(error)")
            errorMessage = "タスクの更新に失敗しました"
            throw TaskError.updateFailed(error.localizedDescription)
        }
    }
    
    func loadTasks(taskListId: String, familyId: String) async {
        do {
            let tasksSnapshot = try await db.collection("families").document(familyId)
                .collection("taskLists").document(taskListId)
                .collection("tasks")
                .order(by: "createdAt", descending: false)
                .getDocuments()
            
            var loadedTasks: [ShigodekiTask] = []
            
            for document in tasksSnapshot.documents {
                if let task = parseTask(from: document) {
                    loadedTasks.append(task)
                }
            }
            
            tasks[taskListId] = loadedTasks
            
        } catch {
            print("Error loading tasks: \(error)")
            errorMessage = "タスクの読み込みに失敗しました"
        }
    }
    
    // MARK: - Real-time Listeners
    
    func startListeningToTaskLists(familyId: String) {
        stopListeningToTaskLists()
        
        let listener = db.collection("families").document(familyId)
            .collection("taskLists")
            .whereField("isArchived", isEqualTo: false)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] querySnapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("TaskList listener error: \(error)")
                        self.errorMessage = "タスクリストの同期中にエラーが発生しました"
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else { return }
                    
                    var updatedTaskLists: [TaskList] = []
                    for document in documents {
                        if let taskList = self.parseTaskList(from: document) {
                            updatedTaskLists.append(taskList)
                        }
                    }
                    
                    self.taskLists = updatedTaskLists
                }
            }
        
        taskListListeners.append(listener)
    }
    
    func startListeningToTasks(taskListId: String, familyId: String) {
        // Remove existing listener for this task list if any
        taskListeners[taskListId]?.remove()
        
        let listener = db.collection("families").document(familyId)
            .collection("taskLists").document(taskListId)
            .collection("tasks")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] querySnapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Tasks listener error: \(error)")
                        self.errorMessage = "タスクの同期中にエラーが発生しました"
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else { return }
                    
                    var updatedTasks: [ShigodekiTask] = []
                    for document in documents {
                        if let task = self.parseTask(from: document) {
                            updatedTasks.append(task)
                        }
                    }
                    
                    self.tasks[taskListId] = updatedTasks
                }
            }
        
        taskListeners[taskListId] = listener
    }
    
    func stopListeningToTaskLists() {
        taskListListeners.forEach { $0.remove() }
        taskListListeners.removeAll()
    }
    
    func stopListeningToTasks(taskListId: String? = nil) {
        if let taskListId = taskListId {
            taskListeners[taskListId]?.remove()
            taskListeners.removeValue(forKey: taskListId)
        } else {
            taskListeners.values.forEach { $0.remove() }
            taskListeners.removeAll()
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseTaskList(from document: QueryDocumentSnapshot) -> TaskList? {
        let data = document.data()
        
        guard let name = data["name"] as? String,
              let familyId = data["familyId"] as? String,
              let createdBy = data["createdBy"] as? String else {
            return nil
        }
        
        var taskList = TaskList(
            name: name,
            familyId: familyId,
            createdBy: createdBy,
            color: TaskListColor(rawValue: data["color"] as? String ?? "blue") ?? .blue
        )
        
        taskList.id = document.documentID
        taskList.isArchived = data["isArchived"] as? Bool ?? false
        taskList.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        
        return taskList
    }
    
    private func parseTask(from document: QueryDocumentSnapshot) -> ShigodekiTask? {
        let data = document.data()
        
        guard let title = data["title"] as? String,
              let createdBy = data["createdBy"] as? String else {
            return nil
        }
        
        let description = data["description"] as? String
        let assignedTo = data["assignedTo"] as? String
        let dueDate = (data["dueDate"] as? Timestamp)?.dateValue()
        let priority = TaskPriority(rawValue: data["priority"] as? String ?? "medium") ?? .medium
        
        var task = ShigodekiTask(
            title: title,
            description: description?.isEmpty == false ? description : nil,
            assignedTo: assignedTo?.isEmpty == false ? assignedTo : nil,
            createdBy: createdBy,
            dueDate: dueDate,
            priority: priority
        )
        
        task.id = document.documentID
        task.isCompleted = data["isCompleted"] as? Bool ?? false
        task.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        task.completedAt = (data["completedAt"] as? Timestamp)?.dateValue()
        
        return task
    }
    
    // MARK: - Cleanup
    
    func cleanupInactiveTaskListeners() {
        // Remove listeners for task lists that no longer exist
        let activeTaskListIds = Set(taskLists.compactMap { $0.id })
        let inactiveIds = Set(taskListeners.keys).subtracting(activeTaskListIds)
        
        for taskListId in inactiveIds {
            taskListeners[taskListId]?.remove()
            taskListeners.removeValue(forKey: taskListId)
            tasks.removeValue(forKey: taskListId)
        }
    }
    
    deinit {
        taskListListeners.forEach { $0.remove() }
        taskListListeners.removeAll()
        taskListeners.values.forEach { $0.remove() }
        taskListeners.removeAll()
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