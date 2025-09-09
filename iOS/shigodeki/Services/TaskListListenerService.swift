//
//  TaskListListenerService.swift
//  shigodeki
//
//  Created by Claude on 2025-09-07.
//

import Foundation
import FirebaseFirestore
import Combine

struct TaskListListenerService {
    
    // MARK: - Listener Management
    
    static func startListeningForTaskLists(
        phaseId: String, 
        projectId: String,
        pendingDeleteTimestamps: [String: Date],
        pendingReorderUntil: Date?,
        pendingTTL: TimeInterval,
        onUpdate: @escaping ([TaskList], Date?, FirebaseError?) -> Void
    ) -> ListenerRegistration {
        
        let taskListsCollection = TaskListCRUDService.getTaskListCollection(phaseId: phaseId, projectId: projectId)
        
        let listener = taskListsCollection.order(by: "order").addSnapshotListener { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    onUpdate([], nil, FirebaseError.from(error))
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                do {
                    // Build remote map excluding local-pending writes and pending deletes
                    let now = Date()
                    let remotePairs: [(String, TaskList)] = try documents.compactMap { doc in
                        if doc.metadata.hasPendingWrites { return nil }
                        if let ts = pendingDeleteTimestamps[doc.documentID], now.timeIntervalSince(ts) < pendingTTL { return nil }
                        let model = try doc.data(as: TaskList.self)
                        return (doc.documentID, model)
                    }
                    let remoteMap = Dictionary(uniqueKeysWithValues: remotePairs)
                    var merged: [TaskList] = []
                    
                    // Merge logic would need currentTaskLists from manager
                    // For now, just use remote data
                    merged = Array(remoteMap.values)
                    
                    if let ts = pendingReorderUntil, now.timeIntervalSince(ts) < pendingTTL {
                        // preserve merged order
                    } else {
                        merged.sort { $0.order < $1.order }
                    }
                    
                    onUpdate(merged, nil, nil)
                    
                    #if DEBUG
                    print("🔔 TaskListListenerService: Merged lists for phase \(phaseId): \(merged.count)")
                    #endif
                } catch {
                    onUpdate([], nil, FirebaseError.from(error))
                }
            }
        }
        
        return listener
    }
    
    // Legacy listener for backward compatibility
    static func startListeningForTaskLists(
        familyId: String,
        onUpdate: @escaping ([TaskList], FirebaseError?) -> Void
    ) -> ListenerRegistration {
        
        let taskListsCollection = Firestore.firestore().collection("families").document(familyId).collection("taskLists")
        
        let listener = taskListsCollection.addSnapshotListener { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    onUpdate([], FirebaseError.from(error))
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                do {
                    let taskLists = try documents.compactMap { document in
                        try document.data(as: TaskList.self)
                    }
                    onUpdate(taskLists, nil)
                } catch {
                    onUpdate([], FirebaseError.from(error))
                }
            }
        }
        
        return listener
    }
}
