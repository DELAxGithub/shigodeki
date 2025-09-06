//
//  TaskListenerService.swift
//  shigodeki
//
//  Extracted from EnhancedTaskManager.swift for CLAUDE.md compliance
//  Firebase listener management and real-time task updates
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class TaskListenerService: ObservableObject {
    @Published var tasks: [ShigodekiTask] = []
    @Published var currentTask: ShigodekiTask?
    @Published var error: FirebaseError?
    
    private let listenerManager = FirebaseListenerManager.shared
    private var activeListenerIds: Set<String> = []
    private var directTaskListeners: [String: ListenerRegistration] = [:]
    private var currentScopeKey: String? = nil
    
    // Pending update tracking
    private var pendingUpdateTimestamps: [String: Date] = [:]
    private var pendingDeleteTimestamps: [String: Date] = [:]
    private var pendingReorderUntil: Date? = nil
    private let pendingTTL: TimeInterval = 5.0
    
    deinit {
        Task { @MainActor [weak self] in
            self?.removeAllListeners()
        }
    }
    
    // MARK: - Task List Listeners
    
    func startListeningForTasks(listId: String, phaseId: String, projectId: String) {
        print("🎧 TaskListenerService: Starting direct task listener")
        let listenerKey = "direct_tasks_\(projectId)_\(phaseId)_\(listId)"
        
        if currentScopeKey != nil && currentScopeKey != listenerKey {
            removeDirectTaskListeners(except: nil)
            tasks = []
        }
        
        if activeListenerIds.contains(listenerKey) || directTaskListeners[listenerKey] != nil {
            print("⚠️ TaskListenerService: Direct task listener already active for key \(listenerKey)")
            return
        }
        
        currentScopeKey = listenerKey
        let collection = getTaskCollection(listId: listId, phaseId: phaseId, projectId: projectId)
        let listener = collection.order(by: "order").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let error = error {
                    print("❌ TaskListenerService: Direct task listener error: \(error)")
                    self.error = FirebaseError.from(error)
                    return
                }
                
                guard let docs = snapshot?.documents else { return }
                self.processTaskSnapshot(docs)
            }
        }
        
        activeListenerIds.insert(listenerKey)
        directTaskListeners[listenerKey] = listener
    }
    
    func startListeningForPhaseTasks(phaseId: String, projectId: String) {
        print("🎧 TaskListenerService: Starting phase task listener")
        let key = "phase_tasks_\(projectId)_\(phaseId)"
        
        if currentScopeKey != nil && currentScopeKey != key {
            removeDirectTaskListeners(except: nil)
            tasks = []
        }
        
        if activeListenerIds.contains(key) || directTaskListeners[key] != nil { return }
        
        currentScopeKey = key
        let collection = getPhaseTaskCollection(phaseId: phaseId, projectId: projectId)
        let listener = collection.order(by: "order").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let error = error { 
                    self.error = FirebaseError.from(error)
                    return 
                }
                
                guard let docs = snapshot?.documents else { return }
                do {
                    let items: [ShigodekiTask] = try docs.compactMap { try $0.data(as: ShigodekiTask.self) }
                    self.tasks = items
                } catch { 
                    self.error = FirebaseError.from(error) 
                }
            }
        }
        
        activeListenerIds.insert(key)
        directTaskListeners[key] = listener
    }
    
    func startListeningForTask(id: String, listId: String, phaseId: String, projectId: String) {
        let listenerId = "task_detail_\(id)"
        
        if activeListenerIds.contains(listenerId) {
            print("⚠️ TaskListenerService: Task detail listener already exists")
            return
        }
        
        print("🎧 TaskListenerService: Starting optimized task detail listener")
        
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
                    print("🔄 TaskListenerService: Task detail updated")
                    self.currentTask = task
                case .failure(let error):
                    print("❌ TaskListenerService: Task detail listener error: \(error)")
                    self.error = error
                    self.currentTask = nil
                }
            }
        }
        
        activeListenerIds.insert(actualListenerId)
    }
    
    // MARK: - Optimistic Updates
    
    func addOptimisticTask(_ task: ShigodekiTask) {
        if !(tasks.contains { $0.id == task.id }) {
            tasks.append(task)
            tasks.sort { $0.order < $1.order }
        }
    }
    
    func updateOptimisticTask(_ task: ShigodekiTask) {
        if let id = task.id {
            pendingUpdateTimestamps[id] = Date()
        }
        
        if currentTask?.id == task.id {
            currentTask = task
        }
        
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
        }
    }
    
    func markTaskForDeletion(id: String) {
        pendingDeleteTimestamps[id] = Date()
        tasks.removeAll { $0.id == id }
        if currentTask?.id == id {
            currentTask = nil
        }
    }
    
    func markReorderPending() {
        pendingReorderUntil = Date()
    }
    
    // MARK: - Private Helpers
    
    private func processTaskSnapshot(_ docs: [QueryDocumentSnapshot]) {
        do {
            let remotePairs: [(String, ShigodekiTask)] = try docs.compactMap { doc in
                if doc.metadata.hasPendingWrites { return nil }
                if let ts = pendingDeleteTimestamps[doc.documentID], 
                   Date().timeIntervalSince(ts) < pendingTTL { return nil }
                let model = try doc.data(as: ShigodekiTask.self)
                return (doc.documentID, model)
            }
            
            var remoteMap: [String: ShigodekiTask] = Dictionary(uniqueKeysWithValues: remotePairs)
            var merged: [ShigodekiTask] = []
            var seen = Set<String>()
            let now = Date()
            
            // Clean expired pending flags
            pendingUpdateTimestamps = pendingUpdateTimestamps.filter { now.timeIntervalSince($0.value) < pendingTTL }
            
            for cur in tasks {
                let cid = cur.id ?? ""
                if let r = remoteMap[cid] {
                    if let ts = pendingUpdateTimestamps[cid], now.timeIntervalSince(ts) < pendingTTL {
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
            for (rid, r) in remoteMap where !seen.contains(rid) { 
                merged.append(r) 
            }
            
            // Maintain order
            if let ts = pendingReorderUntil, Date().timeIntervalSince(ts) < pendingTTL {
                // Preserve current order during reorder window
            } else {
                merged.sort { $0.order < $1.order }
                pendingReorderUntil = nil
            }
            
            print("🔄 TaskListenerService: Merged tasks (cur: \(tasks.count) -> new: \(merged.count))")
            tasks = merged
        } catch {
            self.error = FirebaseError.from(error)
        }
    }
    
    private func removeDirectTaskListeners(except keepKey: String?) {
        for (key, reg) in directTaskListeners {
            if let keepKey, key == keepKey { continue }
            reg.remove()
            activeListenerIds.remove(key)
        }
        
        if keepKey == nil { 
            directTaskListeners.removeAll() 
        } else {
            directTaskListeners = directTaskListeners.filter { $0.key == keepKey }
        }
        
        if keepKey == nil { currentScopeKey = nil }
    }
    
    func removeAllListeners() {
        print("🔄 TaskListenerService: Removing \(activeListenerIds.count) optimized listeners")
        removeDirectTaskListeners(except: nil)
        
        for listenerId in activeListenerIds { 
            listenerManager.removeListener(id: listenerId) 
        }
        activeListenerIds.removeAll()
        print("✅ TaskListenerService: All optimized listeners removed")
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
}