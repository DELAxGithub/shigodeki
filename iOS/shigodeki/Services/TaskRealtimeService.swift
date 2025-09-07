//
//  TaskRealtimeService.swift
//  shigodeki
//
//  Created by Claude on 2025-09-06.
//

import Foundation
import FirebaseFirestore

struct TaskRealtimeService {
    // MARK: - Real-time Listeners
    
    static func startListeningToTaskLists(
        familyId: String,
        taskListListeners: inout [ListenerRegistration],
        taskListsUpdateCallback: @escaping ([TaskList]) -> Void,
        errorCallback: @escaping (String) -> Void,
        db: Firestore
    ) {
        stopListeningToTaskLists(taskListListeners: &taskListListeners)
        
        let listener = db.collection("families").document(familyId)
            .collection("taskLists")
            .whereField("isArchived", isEqualTo: false)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { querySnapshot, error in
                Task { @MainActor in
                    if let error = error {
                        print("TaskList listener error: \(error)")
                        errorCallback("タスクリストの同期中にエラーが発生しました")
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else { return }
                    
                    var updatedTaskLists: [TaskList] = []
                    for document in documents {
                        if let taskList = TaskListService.parseTaskList(from: document) {
                            updatedTaskLists.append(taskList)
                        }
                    }
                    
                    taskListsUpdateCallback(updatedTaskLists)
                }
            }
        
        taskListListeners.append(listener)
    }
    
    static func startListeningToTasks(
        taskListId: String, 
        familyId: String,
        taskListeners: inout [String: ListenerRegistration],
        tasksUpdateCallback: @escaping (String, [ShigodekiTask]) -> Void,
        errorCallback: @escaping (String) -> Void,
        db: Firestore
    ) {
        // Remove existing listener for this task list if any
        taskListeners[taskListId]?.remove()
        
        let listener = db.collection("families").document(familyId)
            .collection("taskLists").document(taskListId)
            .collection("tasks")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { querySnapshot, error in
                Task { @MainActor in
                    if let error = error {
                        print("Tasks listener error: \(error)")
                        errorCallback("タスクの同期中にエラーが発生しました")
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else { return }
                    
                    var updatedTasks: [ShigodekiTask] = []
                    for document in documents {
                        if let task = TaskOperationService.parseTask(from: document) {
                            updatedTasks.append(task)
                        }
                    }
                    
                    tasksUpdateCallback(taskListId, updatedTasks)
                }
            }
        
        taskListeners[taskListId] = listener
    }
    
    static func stopListeningToTaskLists(taskListListeners: inout [ListenerRegistration]) {
        taskListListeners.forEach { $0.remove() }
        taskListListeners.removeAll()
    }
    
    static func stopListeningToTasks(
        taskListId: String? = nil,
        taskListeners: inout [String: ListenerRegistration]
    ) {
        if let taskListId = taskListId {
            taskListeners[taskListId]?.remove()
            taskListeners.removeValue(forKey: taskListId)
        } else {
            taskListeners.values.forEach { $0.remove() }
            taskListeners.removeAll()
        }
    }
    
    // MARK: - Cleanup
    
    static func cleanupInactiveTaskListeners(
        taskLists: [TaskList],
        taskListeners: inout [String: ListenerRegistration],
        tasks: inout [String: [ShigodekiTask]]
    ) {
        // Remove listeners for task lists that no longer exist
        let activeTaskListIds = Set(taskLists.compactMap { $0.id })
        let inactiveIds = Set(taskListeners.keys).subtracting(activeTaskListIds)
        
        for taskListId in inactiveIds {
            taskListeners[taskListId]?.remove()
            taskListeners.removeValue(forKey: taskListId)
            tasks.removeValue(forKey: taskListId)
        }
    }
    
    static func cleanupAllListeners(
        taskListListeners: inout [ListenerRegistration],
        taskListeners: inout [String: ListenerRegistration]
    ) {
        taskListListeners.forEach { $0.remove() }
        taskListListeners.removeAll()
        taskListeners.values.forEach { $0.remove() }
        taskListeners.removeAll()
    }
}