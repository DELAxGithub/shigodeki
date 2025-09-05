//
//  EnhancedTaskManager.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class EnhancedTaskManager: ObservableObject {
    @Published var tasks: [ShigodekiTask] = []
    @Published var currentTask: ShigodekiTask?
    @Published var isLoading = false
    @Published var error: FirebaseError?
    
    // 🆕 統合された Firebase リスナー管理
    private let listenerManager = FirebaseListenerManager.shared
    private var activeListenerIds: Set<String> = []
    // Pending update tracking to mitigate race between optimistic updates and listener snapshots
    private var pendingUpdateTimestamps: [String: Date] = [:]
    private let pendingTTL: TimeInterval = 5.0
    private var pendingDeleteTimestamps: [String: Date] = [:]
    private var pendingReorderUntil: Date? = nil
    // Direct task listeners scoped by list key
    private var directTaskListeners: [String: ListenerRegistration] = [:]
    private var currentScopeKey: String? = nil
    
    deinit {
        // 🆕 中央集中化されたリスナー管理で削除
        Task { @MainActor [weak self] in
            self?.removeAllListeners()
        }
    }
    
    // MARK: - Task CRUD Operations
    
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
            print("✅ EnhancedTaskManager: Created task '" + title + "' [" + (task.id ?? "") + "] in list " + listId)
            // Optimistic local update for current list
            if !(self.tasks.contains { $0.id == task.id }) {
                self.tasks.append(task)
                self.tasks.sort { $0.order < $1.order }
            }
            return task
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }

    // New: Create task under phase-level collection (section-based)
    func createPhaseTask(title: String, description: String? = nil, assignedTo: String? = nil,
                         createdBy: String, dueDate: Date? = nil, priority: TaskPriority = .medium,
                         sectionId: String? = nil, sectionName: String? = nil,
                         phaseId: String, projectId: String, order: Int? = nil) async throws -> ShigodekiTask {
        isLoading = true
        defer { isLoading = false }
        do {
            // Decide order by current max
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
            // Optimistic local update when listening to this scope
            if currentScopeKey == "phase_tasks_\(projectId)_\(phaseId)" {
                tasks.append(task)
                tasks.sort { $0.order < $1.order }
            }
            return task
        } catch {
            let e = FirebaseError.from(error)
            self.error = e
            throw e
        }
    }
    
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
        
        // 🚨 クラッシュ対策: IDが空文字の場合、Firestoreがクラッシュするため早期リターン
        guard !listId.isEmpty, !phaseId.isEmpty, !projectId.isEmpty else {
            print("❌ EnhancedTaskManager.getTasks: Invalid or empty ID provided. Aborting fetch.")
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
    
    func updateTask(_ task: ShigodekiTask) async throws -> ShigodekiTask {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try task.validate()
            
            // Optimistic local update and mark pending
            if let id = task.id {
                pendingUpdateTimestamps[id] = Date()
            }
            if currentTask?.id == task.id {
                currentTask = task
            }
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                let _ = tasks[idx] // keep old in case of rollback
                tasks[idx] = task
            }
            
            // Send to Firestore
            let taskDoc = getTaskCollection(listId: task.listId, phaseId: task.phaseId, projectId: task.projectId).document(task.id ?? "")
            try await taskDoc.setData(try Firestore.Encoder().encode(task), merge: true)
            
            return task
        } catch {
            // Rollback optimistic update on error
            if let id = task.id, let idx = tasks.firstIndex(where: { $0.id == id }) {
                // Attempt to refetch latest known from Firestore synchronously if possible, otherwise remove pending flag
                // For simplicity, just remove pending mark; listener will reconcile
                pendingUpdateTimestamps.removeValue(forKey: id)
            }
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }

    // Phase-level tasks update (new model)
    func updatePhaseTask(_ task: ShigodekiTask) async throws -> ShigodekiTask {
        isLoading = true
        defer { isLoading = false }
        do {
            try task.validate()
            let doc = getPhaseTaskCollection(phaseId: task.phaseId, projectId: task.projectId).document(task.id ?? "")
            try await doc.setData(try Firestore.Encoder().encode(task), merge: true)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) { tasks[idx] = task }
            return task
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func deleteTask(id: String, listId: String, phaseId: String, projectId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            pendingDeleteTimestamps[id] = Date()
            let subtaskManager = SubtaskManager()
            let subtasks = try await subtaskManager.getSubtasks(taskId: id, listId: listId, phaseId: phaseId, projectId: projectId)
            
            for subtask in subtasks {
                try await subtaskManager.deleteSubtask(id: subtask.id ?? "", taskId: id, listId: listId, phaseId: phaseId, projectId: projectId)
            }
            
            let taskDoc = getTaskCollection(listId: listId, phaseId: phaseId, projectId: projectId).document(id)
            try await taskDoc.delete()
            
            tasks.removeAll { $0.id == id }
            if currentTask?.id == id {
                currentTask = nil
            }
            
            try await reorderTasks(listId: listId, phaseId: phaseId, projectId: projectId)
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // MARK: - Helper Methods
    
    internal func getTaskCollection(listId: String, phaseId: String, projectId: String) -> CollectionReference {
        return Firestore.firestore()
            .collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("lists").document(listId)
            .collection("tasks")
    }
    
    internal func getPhaseTaskCollection(phaseId: String, projectId: String) -> CollectionReference {
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
        pendingReorderUntil = Date()
        let currentTasks = try await getTasks(listId: listId, phaseId: phaseId, projectId: projectId)
        let reorderedTasks = currentTasks.enumerated().map { index, task in
            var updatedTask = task
            updatedTask.order = index
            return updatedTask
        }
        try await TaskOrderingManager.reorderTasks(reorderedTasks, listId: listId, phaseId: phaseId, projectId: projectId)
    }
    
    // MARK: - Section updates (phase-level tasks)
    func updateTaskSection(_ task: ShigodekiTask, toSectionId: String?, toSectionName: String?) async throws {
        guard let tid = task.id else { return }
        let doc = getPhaseTaskCollection(phaseId: task.phaseId, projectId: task.projectId).document(tid)
        var updated = task
        updated.sectionId = toSectionId
        updated.sectionName = toSectionName
        try await doc.setData(try Firestore.Encoder().encode(updated), merge: true)
        if let idx = tasks.firstIndex(where: { $0.id == tid }) {
            tasks[idx] = updated
        }
    }

    func reorderTasksInSection(_ tasksInSection: [ShigodekiTask], phaseId: String, projectId: String, sectionId: String?) async throws {
        let batch = Firestore.firestore().batch()
        for (index, t) in tasksInSection.enumerated() {
            var u = t
            u.order = index
            let ref = getPhaseTaskCollection(phaseId: phaseId, projectId: projectId).document(t.id ?? "")
            try batch.setData(try Firestore.Encoder().encode(u), forDocument: ref, merge: true)
        }
        try await batch.commit()
    }

    // 🆕 統合されたリスナー管理システム（実装は下部 removeAllListeners 参照）
    
    // 🆕 統合されたリスナー作成
    func startListeningForTasks(listId: String, phaseId: String, projectId: String) {
        // 安定化のため、タスクリスナーは直接Firestoreで購読
        print("🎧 EnhancedTaskManager: Starting direct task listener")
        let listenerKey = "direct_tasks_\(projectId)_\(phaseId)_\(listId)"
        // If switching to a different list, tear down existing listeners and reset state
        if currentScopeKey != nil && currentScopeKey != listenerKey {
            removeDirectTaskListeners(except: nil)
            tasks = []
        }
        if activeListenerIds.contains(listenerKey) || directTaskListeners[listenerKey] != nil {
            print("⚠️ EnhancedTaskManager: Direct task listener already active for key \(listenerKey)")
            return
        }
        currentScopeKey = listenerKey
        let collection = getTaskCollection(listId: listId, phaseId: phaseId, projectId: projectId)
        let listener = collection.order(by: "order").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let error = error {
                    print("❌ EnhancedTaskManager: Direct task listener error: \(error)")
                    self.error = FirebaseError.from(error)
                    return
                }
                guard let docs = snapshot?.documents else { return }
                do {
                    // Ignore local echo updates to avoid racing with optimistic UI
                    let remotePairs: [(String, ShigodekiTask)] = try docs.compactMap { doc in
                        if doc.metadata.hasPendingWrites { return nil }
                        if let ts = self.pendingDeleteTimestamps[doc.documentID], Date().timeIntervalSince(ts) < self.pendingTTL { return nil }
                        let model = try doc.data(as: ShigodekiTask.self)
                        return (doc.documentID, model)
                    }
                    var remoteMap: [String: ShigodekiTask] = Dictionary(uniqueKeysWithValues: remotePairs)
                    // Merge with current to keep optimistic entries until remote confirms
                    var merged: [ShigodekiTask] = []
                    var seen = Set<String>()
                    let now = Date()
                    // Clean expired pending flags
                    self.pendingUpdateTimestamps = self.pendingUpdateTimestamps.filter { now.timeIntervalSince($0.value) < self.pendingTTL }
                    for cur in self.tasks {
                        let cid = cur.id ?? ""
                        if let r = remoteMap[cid] {
                            if let ts = self.pendingUpdateTimestamps[cid], now.timeIntervalSince(ts) < self.pendingTTL {
                                // Prefer optimistic local during TTL window
                                merged.append(cur)
                            } else {
                                merged.append(r)
                                seen.insert(cid)
                            }
                            remoteMap.removeValue(forKey: cid)
                        } else {
                            merged.append(cur)
                        }
                    }
                    // Append any new remote docs not in current
                    for (rid, r) in remoteMap where !seen.contains(rid) { merged.append(r) }
                    // Keep order by 'order' if available unless reorder pending window is active
                    if let ts = self.pendingReorderUntil, Date().timeIntervalSince(ts) < self.pendingTTL {
                        // Preserve current order (merged is seeded by current tasks first)
                    } else {
                        merged.sort { $0.order < $1.order }
                        self.pendingReorderUntil = nil
                    }
                    print("🔄 EnhancedTaskManager: Merged tasks (cur: \(self.tasks.count) -> new: \(merged.count))")
                    self.tasks = merged
                } catch {
                    self.error = FirebaseError.from(error)
                }
            }
        }
        // マーカーだけ保持（実リスナーはFirestoreが保持）
        activeListenerIds.insert(listenerKey)
        directTaskListeners[listenerKey] = listener
    }
    
    // Phase-level tasks (no list). New model support.
    func startListeningForPhaseTasks(phaseId: String, projectId: String) {
        print("🎧 EnhancedTaskManager: Starting phase task listener")
        let key = "phase_tasks_\(projectId)_\(phaseId)"
        if currentScopeKey != nil && currentScopeKey != key {
            removeDirectTaskListeners(except: nil)
            tasks = []
        }
        if activeListenerIds.contains(key) || directTaskListeners[key] != nil { return }
        currentScopeKey = key
        let collection = getPhaseTaskCollection(phaseId: phaseId, projectId: projectId)
        // Use single order field to avoid requiring a composite index
        let listener = collection.order(by: "order").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let error = error { self.error = FirebaseError.from(error); return }
                guard let docs = snapshot?.documents else { return }
                do {
                    let items: [ShigodekiTask] = try docs.compactMap { try $0.data(as: ShigodekiTask.self) }
                    self.tasks = items
                } catch { self.error = FirebaseError.from(error) }
            }
        }
        activeListenerIds.insert(key)
        directTaskListeners[key] = listener
    }

    func getPhaseTasks(phaseId: String, projectId: String) async throws -> [ShigodekiTask] {
        isLoading = true
        defer { isLoading = false }

        // 🚨 クラッシュ対策: IDが空文字の場合、Firestoreがクラッシュするため早期リターン
        guard !phaseId.isEmpty, !projectId.isEmpty else {
            print("❌ EnhancedTaskManager.getPhaseTasks: Invalid or empty ID provided. Aborting fetch.")
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
    
    // 🆕 個別タスク用の統合リスナー
    func startListeningForTask(id: String, listId: String, phaseId: String, projectId: String) {
        let listenerId = "task_detail_\(id)"
        
        if activeListenerIds.contains(listenerId) {
            print("⚠️ EnhancedTaskManager: Task detail listener already exists")
            return
        }
        
        print("🎧 EnhancedTaskManager: Starting optimized task detail listener")
        
        let document = Firestore.firestore()
            .collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("lists").document(listId)
            .collection("tasks").document(id)
        
        let actualListenerId = listenerManager.createDocumentListener(
            id: listenerId,
            document: document,
            type: .task,
            priority: .low
        ) { [weak self] (result: Result<ShigodekiTask?, FirebaseError>) in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                switch result {
                case .success(let task):
                    print("🔄 EnhancedTaskManager: Task detail updated")
                    self.currentTask = task
                case .failure(let error):
                    print("❌ EnhancedTaskManager: Task detail listener error: \(error)")
                    self.error = error
                    self.currentTask = nil
                }
            }
        }
        
        activeListenerIds.insert(actualListenerId)
    }

    // MARK: - Direct Listener Teardown
    private func removeDirectTaskListeners(except keepKey: String?) {
        for (key, reg) in directTaskListeners {
            if let keepKey, key == keepKey { continue }
            reg.remove()
            activeListenerIds.remove(key)
        }
        if keepKey == nil { directTaskListeners.removeAll() } else {
            directTaskListeners = directTaskListeners.filter { $0.key == keepKey }
        }
        if keepKey == nil { currentScopeKey = nil }
    }
    
    func removeAllListeners() {
        print("🔄 EnhancedTaskManager: Removing \(activeListenerIds.count) optimized listeners")
        // Remove direct task listeners explicitly
        removeDirectTaskListeners(except: nil)
        // Also remove any centralized listeners
        for listenerId in activeListenerIds { listenerManager.removeListener(id: listenerId) }
        activeListenerIds.removeAll()
        print("✅ EnhancedTaskManager: All optimized listeners removed")
    }
}
