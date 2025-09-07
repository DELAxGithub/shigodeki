//
//  ListenerManagementService.swift
//  shigodeki
//
//  Created by Claude on 2025-09-06.
//

import Foundation
import FirebaseFirestore

struct ListenerManagementService {
    // MARK: - Listener Management Operations
    
    /// リスナーの削除
    static func removeListener(
        id: String,
        activeListeners: inout [String: ListenerRegistration],
        listenerMetadata: inout [String: FirebaseListenerManager.ListenerMetadata],
        updateStatisticsCallback: @escaping () -> Void
    ) {
        guard let listener = activeListeners[id] else { return }
        
        #if DEBUG
        if let metadata = listenerMetadata[id] {
            print("❌ Issue #50: Firebase Listener REMOVED: \(id) (type: \(metadata.type), access count: \(metadata.accessCount))")
        }
        #endif
        
        listener.remove()
        activeListeners.removeValue(forKey: id)
        listenerMetadata.removeValue(forKey: id)
        
        updateStatisticsCallback()
        
        #if DEBUG
        print("📊 Issue #50: Remaining active listeners: \(activeListeners.count)")
        #endif
        
        InstrumentsSetup.shared.logMemoryUsage(context: "After Listener Removal")
    }
    
    /// 複数リスナーの一括削除
    static func removeListeners(
        ids: [String],
        activeListeners: inout [String: ListenerRegistration],
        listenerMetadata: inout [String: FirebaseListenerManager.ListenerMetadata],
        updateStatisticsCallback: @escaping () -> Void
    ) {
        for id in ids {
            removeListener(
                id: id,
                activeListeners: &activeListeners,
                listenerMetadata: &listenerMetadata,
                updateStatisticsCallback: updateStatisticsCallback
            )
        }
    }
    
    /// タイプ別リスナー削除
    static func removeListeners(
        ofType type: FirebaseListenerManager.ListenerMetadata.ListenerType,
        listenerMetadata: [String: FirebaseListenerManager.ListenerMetadata],
        activeListeners: inout [String: ListenerRegistration],
        listenerMetadataRef: inout [String: FirebaseListenerManager.ListenerMetadata],
        updateStatisticsCallback: @escaping () -> Void
    ) {
        let idsToRemove = listenerMetadata.compactMap { key, metadata in
            metadata.type == type ? key : nil
        }
        removeListeners(
            ids: idsToRemove,
            activeListeners: &activeListeners,
            listenerMetadata: &listenerMetadataRef,
            updateStatisticsCallback: updateStatisticsCallback
        )
    }
    
    /// 全リスナーの削除
    static func removeAllListeners(
        activeListeners: inout [String: ListenerRegistration],
        listenerMetadata: inout [String: FirebaseListenerManager.ListenerMetadata],
        updateStatisticsCallback: @escaping () -> Void
    ) {
        #if DEBUG
        let count = activeListeners.count
        print("🗑️ Issue #50: Removing ALL Firebase Listeners (\(count) total)")
        for (id, _) in activeListeners {
            if let metadata = listenerMetadata[id] {
                print("  ❌ Removing: \(id) (type: \(metadata.type))")
            }
        }
        #endif
        
        for (_, listener) in activeListeners {
            listener.remove()
        }
        activeListeners.removeAll()
        listenerMetadata.removeAll()
        updateStatisticsCallback()
        
        #if DEBUG
        print("✅ Issue #50: All Firebase Listeners removed. Active count: \(activeListeners.count)")
        #endif
        
        InstrumentsSetup.shared.logMemoryUsage(context: "After All Listeners Removal")
    }
}