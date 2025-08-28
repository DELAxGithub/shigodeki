//
//  TaskRealtimeListeners.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore

extension EnhancedTaskManager {
    
    func startListeningForTasks(listId: String, phaseId: String, projectId: String) {
        let tasksCollection = getTaskCollection(listId: listId, phaseId: phaseId, projectId: projectId)
        
        let listener = tasksCollection.order(by: "order").addSnapshotListener { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = FirebaseError.from(error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.tasks = []
                    return
                }
                
                do {
                    let tasks = try documents.compactMap { document in
                        try document.data(as: ShigodekiTask.self)
                    }
                    self?.tasks = tasks
                } catch {
                    self?.error = FirebaseError.from(error)
                }
            }
        }
        
        listeners.append(listener)
    }
    
    func startListeningForTask(id: String, listId: String, phaseId: String, projectId: String) {
        let taskDoc = getTaskCollection(listId: listId, phaseId: phaseId, projectId: projectId).document(id)
        
        let listener = taskDoc.addSnapshotListener { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = FirebaseError.from(error)
                    return
                }
                
                guard let document = snapshot, document.exists else {
                    self?.currentTask = nil
                    return
                }
                
                do {
                    let task = try document.data(as: ShigodekiTask.self)
                    self?.currentTask = task
                } catch {
                    self?.error = FirebaseError.from(error)
                }
            }
        }
        
        listeners.append(listener)
    }
}

extension SubtaskManager {
    
    func startListeningForSubtasks(taskId: String, listId: String, phaseId: String, projectId: String) {
        let subtasksCollection = getSubtaskCollection(taskId: taskId, listId: listId, phaseId: phaseId, projectId: projectId)
        
        let listener = subtasksCollection.order(by: "order").addSnapshotListener { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = FirebaseError.from(error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.subtasks = []
                    return
                }
                
                do {
                    let subtasks = try documents.compactMap { document in
                        try document.data(as: Subtask.self)
                    }
                    self?.subtasks = subtasks
                } catch {
                    self?.error = FirebaseError.from(error)
                }
            }
        }
        
        listeners.append(listener)
    }
}