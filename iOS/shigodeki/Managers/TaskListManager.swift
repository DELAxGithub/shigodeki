//
//  TaskListManager.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class TaskListManager: ObservableObject {
    @Published var taskLists: [TaskList] = []
    @Published var currentTaskList: TaskList?
    @Published var isLoading = false
    @Published var error: FirebaseError?
    
    private var listeners: [ListenerRegistration] = []
    private var pendingDeleteTimestamps: [String: Date] = [:]
    private var pendingReorderUntil: Date? = nil
    private let pendingTTL: TimeInterval = 5.0
    
    deinit {
        // Clean up listeners synchronously in deinit to prevent retain cycles
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - TaskList CRUD Operations
    
    func createTaskList(name: String, phaseId: String, projectId: String, createdBy: String, color: TaskListColor = .blue, order: Int? = nil) async throws -> TaskList {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let taskList = try await TaskListCRUDService.createTaskList(name: name, phaseId: phaseId, projectId: projectId, createdBy: createdBy, color: color, order: order)
            // Optimistic local update
            if !(self.taskLists.contains { $0.id == taskList.id }) {
                self.taskLists.append(taskList)
                self.taskLists.sort { $0.order < $1.order }
            }
            return taskList
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // Legacy method for backward compatibility
    func createTaskList(name: String, familyId: String, createdBy: String, color: TaskListColor = .blue) async throws -> TaskList {
        isLoading = true
        defer { isLoading = false }
        
        do {
            return try await TaskListCRUDService.createTaskList(name: name, familyId: familyId, createdBy: createdBy, color: color)
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func getTaskList(id: String, phaseId: String, projectId: String) async throws -> TaskList? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            return try await TaskListCRUDService.getTaskList(id: id, phaseId: phaseId, projectId: projectId)
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func getTaskLists(phaseId: String, projectId: String) async throws -> [TaskList] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            return try await TaskListCRUDService.getTaskLists(phaseId: phaseId, projectId: projectId)
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // Legacy method for backward compatibility
    func getTaskLists(familyId: String) async throws -> [TaskList] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            return try await TaskListCRUDService.getTaskLists(familyId: familyId)
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func updateTaskList(_ taskList: TaskList) async throws -> TaskList {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let updatedTaskList = try await TaskListCRUDService.updateTaskList(taskList)
            
            // Update local state
            if currentTaskList?.id == taskList.id {
                currentTaskList = updatedTaskList
            }
            
            if let index = taskLists.firstIndex(where: { $0.id == taskList.id }) {
                taskLists[index] = updatedTaskList
            }
            
            return updatedTaskList
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func deleteTaskList(id: String, phaseId: String, projectId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            pendingDeleteTimestamps[id] = Date()
            try await TaskListCRUDService.deleteTaskList(id: id, phaseId: phaseId, projectId: projectId)
            
            // Update local state
            taskLists.removeAll { $0.id == id }
            if currentTaskList?.id == id {
                currentTaskList = nil
            }
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // Legacy method for backward compatibility
    func deleteTaskList(id: String, familyId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await TaskListCRUDService.deleteTaskList(id: id, familyId: familyId)
            
            taskLists.removeAll { $0.id == id }
            if currentTaskList?.id == id {
                currentTaskList = nil
            }
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // MARK: - TaskList Ordering
    
    func reorderTaskLists(_ taskLists: [TaskList], phaseId: String, projectId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            pendingReorderUntil = Date()
            try await TaskListOrderingService.reorderTaskLists(taskLists, phaseId: phaseId, projectId: projectId)
            self.taskLists = taskLists.sorted { $0.order < $1.order }
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // MARK: - Archive Operations
    
    func archiveTaskList(id: String, phaseId: String, projectId: String) async throws {
        try await TaskListArchiveService.archiveTaskList(id: id, phaseId: phaseId, projectId: projectId)
    }
    
    func unarchiveTaskList(id: String, phaseId: String, projectId: String) async throws {
        try await TaskListArchiveService.unarchiveTaskList(id: id, phaseId: phaseId, projectId: projectId)
    }
    
    // MARK: - Helper Methods
    
    private func getTaskListCollection(phaseId: String, projectId: String) -> CollectionReference {
        return TaskListCRUDService.getTaskListCollection(phaseId: phaseId, projectId: projectId)
    }
    
    // MARK: - Real-time Listeners
    
    func startListeningForTaskLists(phaseId: String, projectId: String) {
        // Avoid duplicate listeners
        removeAllListeners()
        
        let listener = TaskListListenerService.startListeningForTaskLists(
            phaseId: phaseId,
            projectId: projectId,
            pendingDeleteTimestamps: pendingDeleteTimestamps,
            pendingReorderUntil: pendingReorderUntil,
            pendingTTL: pendingTTL
        ) { [weak self] taskLists, newPendingReorderUntil, firebaseError in
            if let error = firebaseError {
                self?.error = error
                return
            }
            
            // Enhanced merge logic with current state
            var merged: [TaskList] = []
            var seen = Set<String>()
            for cur in self?.taskLists ?? [] {
                let cid = cur.id ?? ""
                if let r = taskLists.first(where: { $0.id == cid }) {
                    merged.append(r); seen.insert(cid)
                } else {
                    merged.append(cur)
                }
            }
            for r in taskLists where !seen.contains(r.id ?? "") { merged.append(r) }
            
            let now = Date()
            if let ts = self?.pendingReorderUntil, now.timeIntervalSince(ts) < (self?.pendingTTL ?? 5.0) {
                // preserve merged order seeded by current
            } else {
                merged.sort { $0.order < $1.order }
                self?.pendingReorderUntil = nil
            }
            self?.taskLists = merged
        }
        
        listeners.append(listener)
    }
    
    // Legacy listener for backward compatibility
    func startListeningForTaskLists(familyId: String) {
        // Avoid duplicate listeners
        removeAllListeners()
        
        let listener = TaskListListenerService.startListeningForTaskLists(familyId: familyId) { [weak self] taskLists, firebaseError in
            if let error = firebaseError {
                self?.error = error
                return
            }
            self?.taskLists = taskLists
        }
        
        listeners.append(listener)
    }
    
    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - Validation Helpers
    
    func validateTaskListHierarchy(taskList: TaskList) async throws {
        try await TaskListValidationService.validateTaskListHierarchy(taskList: taskList)
    }
}
