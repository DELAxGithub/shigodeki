//
//  TaskCRUDService.swift
//  shigodeki
//
//  Extracted from EnhancedTaskManager.swift for CLAUDE.md compliance
//  Task creation, read, update, delete operations
//

import Foundation
import FirebaseFirestore

@MainActor
class TaskCRUDService: ObservableObject {
    @Published var isLoading = false
    @Published var error: FirebaseError?
    
    private let subtaskManager = SubtaskManager()
    
    // MARK: - Task Creation
    
    func createTask(title: String, description: String? = nil, assignedTo: String? = nil, 
                   createdBy: String, dueDate: Date? = nil, priority: TaskPriority = .medium,
                   listId: String, phaseId: String, projectId: String, order: Int? = nil) async throws -> ShigodekiTask {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let finalOrder: Int
            if let order = order {
                finalOrder = order
            } else {
                finalOrder = try await getNextTaskOrder(listId: listId, phaseId: phaseId, projectId: projectId)
            }
            
            var task = ShigodekiTask(title: title, description: description, assignedTo: assignedTo, 
                                   createdBy: createdBy, dueDate: dueDate, priority: priority,
                                   listId: listId, phaseId: phaseId, projectId: projectId, order: finalOrder)
            
            try task.validate()
            
            let taskCollection = getTaskCollection(listId: listId, phaseId: phaseId, projectId: projectId)
            let documentRef = taskCollection.document()
            task.id = documentRef.documentID
            task.createdAt = Date()
            
            try await documentRef.setData(try Firestore.Encoder().encode(task))
            print("✅ TaskCRUDService: Created task '" + title + "' [" + (task.id ?? "") + "] in list " + listId)
            
            return task
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func createPhaseTask(title: String, description: String? = nil, assignedTo: String? = nil,
                         createdBy: String, dueDate: Date? = nil, priority: TaskPriority = .medium,
                         sectionId: String? = nil, sectionName: String? = nil,
                         phaseId: String, projectId: String, order: Int? = nil) async throws -> ShigodekiTask {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let existing = try await getPhaseTasks(phaseId: phaseId, projectId: projectId)
            let finalOrder = order ?? ((existing.map { $0.order }.max() ?? -1) + 1)
            
            var task = ShigodekiTask(title: title, description: description, assignedTo: assignedTo,
                                     createdBy: createdBy, dueDate: dueDate, priority: priority,
                                     listId: "", phaseId: phaseId, projectId: projectId, order: finalOrder)
            task.sectionId = sectionId
            task.sectionName = sectionName
            
            try task.validate()
            
            let coll = getPhaseTaskCollection(phaseId: phaseId, projectId: projectId)
            let ref = coll.document()
            task.id = ref.documentID
            task.createdAt = Date()
            
            try await ref.setData(try Firestore.Encoder().encode(task))
            return task
        } catch {
            let e = FirebaseError.from(error)
            self.error = e
            throw e
        }
    }
    
    // MARK: - Task Reading
    
    func getTask(id: String, listId: String, phaseId: String, projectId: String) async throws -> ShigodekiTask? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let taskDoc = getTaskCollection(listId: listId, phaseId: phaseId, projectId: projectId).document(id)
            let snapshot = try await taskDoc.getDocument()
            
            guard snapshot.exists else { return nil }
            return try snapshot.data(as: ShigodekiTask.self)
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func getTasks(listId: String, phaseId: String, projectId: String) async throws -> [ShigodekiTask] {
        isLoading = true
        defer { isLoading = false }
        
        guard !listId.isEmpty, !phaseId.isEmpty, !projectId.isEmpty else {
            print("❌ TaskCRUDService.getTasks: Invalid or empty ID provided. Aborting fetch.")
            return []
        }
        
        do {
            let tasksCollection = getTaskCollection(listId: listId, phaseId: phaseId, projectId: projectId)
            let snapshot = try await tasksCollection.order(by: "order").getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: ShigodekiTask.self)
            }
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func getPhaseTasks(phaseId: String, projectId: String) async throws -> [ShigodekiTask] {
        isLoading = true
        defer { isLoading = false }

        guard !phaseId.isEmpty, !projectId.isEmpty else {
            print("❌ TaskCRUDService.getPhaseTasks: Invalid or empty ID provided. Aborting fetch.")
            return []
        }

        do {
            let snapshot = try await getPhaseTaskCollection(phaseId: phaseId, projectId: projectId)
                .order(by: "order")
                .getDocuments()
            return try snapshot.documents.compactMap { try $0.data(as: ShigodekiTask.self) }
        } catch {
            let e = FirebaseError.from(error)
            self.error = e
            throw e
        }
    }
    
    // MARK: - Task Updates
    
    func updateTask(_ task: ShigodekiTask) async throws -> ShigodekiTask {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try task.validate()
            
            let taskDoc = getTaskCollection(listId: task.listId, phaseId: task.phaseId, projectId: task.projectId).document(task.id ?? "")
            try await taskDoc.setData(try Firestore.Encoder().encode(task), merge: true)
            
            return task
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }

    func updatePhaseTask(_ task: ShigodekiTask) async throws -> ShigodekiTask {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try task.validate()
            let doc = getPhaseTaskCollection(phaseId: task.phaseId, projectId: task.projectId).document(task.id ?? "")
            try await doc.setData(try Firestore.Encoder().encode(task), merge: true)
            return task
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func updateTaskSection(_ task: ShigodekiTask, toSectionId: String?, toSectionName: String?) async throws {
        guard let tid = task.id else { return }
        let doc = getPhaseTaskCollection(phaseId: task.phaseId, projectId: task.projectId).document(tid)
        var updated = task
        updated.sectionId = toSectionId
        updated.sectionName = toSectionName
        try await doc.setData(try Firestore.Encoder().encode(updated), merge: true)
    }
    
    // MARK: - Task Deletion
    
    func deleteTask(id: String, listId: String, phaseId: String, projectId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let subtasks = try await subtaskManager.getSubtasks(taskId: id, listId: listId, phaseId: phaseId, projectId: projectId)
            
            for subtask in subtasks {
                try await subtaskManager.deleteSubtask(id: subtask.id ?? "", taskId: id, listId: listId, phaseId: phaseId, projectId: projectId)
            }
            
            let taskDoc = getTaskCollection(listId: listId, phaseId: phaseId, projectId: projectId).document(id)
            try await taskDoc.delete()
            
            try await reorderTasks(listId: listId, phaseId: phaseId, projectId: projectId)
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // MARK: - Helper Methods
    
    private func getTaskCollection(listId: String, phaseId: String, projectId: String) -> CollectionReference {
        return Firestore.firestore()
            .collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("lists").document(listId)
            .collection("tasks")
    }
    
    private func getPhaseTaskCollection(phaseId: String, projectId: String) -> CollectionReference {
        return Firestore.firestore()
            .collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("tasks")
    }
    
    private func getNextTaskOrder(listId: String, phaseId: String, projectId: String) async throws -> Int {
        let tasks = try await getTasks(listId: listId, phaseId: phaseId, projectId: projectId)
        return tasks.map { $0.order }.max() ?? 0 + 1
    }
    
    private func reorderTasks(listId: String, phaseId: String, projectId: String) async throws {
        let currentTasks = try await getTasks(listId: listId, phaseId: phaseId, projectId: projectId)
        let reorderedTasks = currentTasks.enumerated().map { index, task in
            var updatedTask = task
            updatedTask.order = index
            return updatedTask
        }
        try await TaskOrderingManager.reorderTasks(reorderedTasks, listId: listId, phaseId: phaseId, projectId: projectId)
    }
    
    func reorderTasksInSection(_ tasksInSection: [ShigodekiTask], phaseId: String, projectId: String, sectionId: String?) async throws {
        let batch = Firestore.firestore().batch()
        for (index, t) in tasksInSection.enumerated() {
            var u = t
            u.order = index
            let ref = getPhaseTaskCollection(phaseId: phaseId, projectId: projectId).document(t.id ?? "")
            batch.setData(try Firestore.Encoder().encode(u), forDocument: ref, merge: true)
        }
        try await batch.commit()
    }
}
