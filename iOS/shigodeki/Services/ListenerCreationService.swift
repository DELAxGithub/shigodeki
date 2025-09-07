//
//  ListenerCreationService.swift
//  shigodeki
//
//  Created by Claude on 2025-09-06.
//

import Foundation
import FirebaseFirestore

struct ListenerCreationService {
    // MARK: - Smart Listener Creation
    
    /// インテリジェントなリスナー作成（重複チェック付き）
    static func createListener<T: Codable>(
        id: String,
        query: Query,
        type: FirebaseListenerManager.ListenerMetadata.ListenerType,
        priority: FirebaseListenerManager.ListenerMetadata.Priority = .medium,
        activeListeners: inout [String: ListenerRegistration],
        listenerMetadata: inout [String: FirebaseListenerManager.ListenerMetadata],
        updateAccessCallback: @escaping (String) -> Void,
        updateStatisticsCallback: @escaping () -> Void,
        optimizeCallback: @escaping () -> Void,
        completion: @escaping (Result<[T], FirebaseError>) -> Void
    ) -> String {
        
        // Issue #50 Fix: Enhanced duplicate detection with detailed logging
        if activeListeners[id] != nil {
            updateAccessCallback(id)
            InstrumentsSetup.shared.endFirebaseConnectionMeasurement(operation: "Listener Reuse", success: true)
            
            #if DEBUG
            print("🔄 Issue #50: Firebase Listener REUSED: \(id) (type: \(type), priority: \(priority))")
            print("📊 Issue #50: Active listeners count: \(activeListeners.count)")
            if let metadata = listenerMetadata[id] {
                print("📈 Issue #50: Listener access count: \(metadata.accessCount), last accessed: \(metadata.lastAccessed)")
            }
            #endif
            return id
        }
        
        InstrumentsSetup.shared.startFirebaseConnectionMeasurement(operation: "Create Listener: \(id)")
        
        // 新しいリスナーを作成
        let listener = query.addSnapshotListener { snapshot, error in
            Task { @MainActor in
                updateAccessCallback(id)
                
                if let error = error {
                    completion(.failure(FirebaseError.from(error)))
                    InstrumentsSetup.shared.endFirebaseConnectionMeasurement(operation: "Create Listener: \(id)", success: false)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    InstrumentsSetup.shared.endFirebaseConnectionMeasurement(operation: "Create Listener: \(id)", success: true)
                    return
                }
                
                do {
                    let items = try documents.compactMap { document in
                        try document.data(as: T.self)
                    }
                    completion(.success(items))
                    InstrumentsSetup.shared.endFirebaseConnectionMeasurement(operation: "Create Listener: \(id)", success: true)
                } catch {
                    completion(.failure(FirebaseError.from(error)))
                    InstrumentsSetup.shared.endFirebaseConnectionMeasurement(operation: "Create Listener: \(id)", success: false)
                }
            }
        }
        
        // リスナーとメタデータの保存
        activeListeners[id] = listener
        listenerMetadata[id] = FirebaseListenerManager.ListenerMetadata(
            id: id,
            type: type,
            createdAt: Date(),
            lastAccessed: Date(),
            accessCount: 1,
            path: query.description,
            priority: priority
        )
        
        updateStatisticsCallback()
        
        #if DEBUG
        print("🆕 Issue #50: Firebase Listener CREATED: \(id) (type: \(type), priority: \(priority))")
        print("📊 Issue #50: Total active listeners: \(activeListeners.count)")
        print("🗂️ Issue #50: Query path: \(query.description)")
        #endif
        
        // 自動最適化のトリガー
        if activeListeners.count > 15 {
            #if DEBUG
            print("⚠️ Issue #50: High listener count (\(activeListeners.count)), triggering optimization")
            #endif
            optimizeCallback()
        }
        
        return id
    }
    
    /// 単一ドキュメント用のリスナー作成
    static func createDocumentListener<T: Codable>(
        id: String,
        document: DocumentReference,
        type: FirebaseListenerManager.ListenerMetadata.ListenerType,
        priority: FirebaseListenerManager.ListenerMetadata.Priority = .medium,
        activeListeners: inout [String: ListenerRegistration],
        listenerMetadata: inout [String: FirebaseListenerManager.ListenerMetadata],
        updateAccessCallback: @escaping (String) -> Void,
        updateStatisticsCallback: @escaping () -> Void,
        completion: @escaping (Result<T?, FirebaseError>) -> Void
    ) -> String {
        
        // 既存リスナーチェック
        if activeListeners[id] != nil {
            updateAccessCallback(id)
            return id
        }
        
        InstrumentsSetup.shared.startFirebaseConnectionMeasurement(operation: "Create Document Listener: \(id)")
        
        let listener = document.addSnapshotListener { snapshot, error in
            Task { @MainActor in
                updateAccessCallback(id)
                
                if let error = error {
                    completion(.failure(FirebaseError.from(error)))
                    InstrumentsSetup.shared.endFirebaseConnectionMeasurement(operation: "Create Document Listener: \(id)", success: false)
                    return
                }
                
                guard let document = snapshot, document.exists else {
                    completion(.success(nil))
                    InstrumentsSetup.shared.endFirebaseConnectionMeasurement(operation: "Create Document Listener: \(id)", success: true)
                    return
                }
                
                do {
                    let item = try document.data(as: T.self)
                    completion(.success(item))
                    InstrumentsSetup.shared.endFirebaseConnectionMeasurement(operation: "Create Document Listener: \(id)", success: true)
                } catch {
                    completion(.failure(FirebaseError.from(error)))
                    InstrumentsSetup.shared.endFirebaseConnectionMeasurement(operation: "Create Document Listener: \(id)", success: false)
                }
            }
        }
        
        activeListeners[id] = listener
        listenerMetadata[id] = FirebaseListenerManager.ListenerMetadata(
            id: id,
            type: type,
            createdAt: Date(),
            lastAccessed: Date(),
            accessCount: 1,
            path: document.path,
            priority: priority
        )
        
        updateStatisticsCallback()
        return id
    }
    
    // MARK: - Convenience Methods
    
    /// プロジェクト用の便利メソッド
    static func createProjectListener(
        userId: String,
        activeListeners: inout [String: ListenerRegistration],
        listenerMetadata: inout [String: FirebaseListenerManager.ListenerMetadata],
        updateAccessCallback: @escaping (String) -> Void,
        updateStatisticsCallback: @escaping () -> Void,
        optimizeCallback: @escaping () -> Void,
        completion: @escaping (Result<[Project], FirebaseError>) -> Void
    ) -> String {
        let id = "projects_\(userId)"
        let query = Firestore.firestore()
            .collection("projects")
            .whereField("memberIds", arrayContains: userId)
        
        return createListener(
            id: id,
            query: query,
            type: .project,
            priority: .high,
            activeListeners: &activeListeners,
            listenerMetadata: &listenerMetadata,
            updateAccessCallback: updateAccessCallback,
            updateStatisticsCallback: updateStatisticsCallback,
            optimizeCallback: optimizeCallback,
            completion: completion
        )
    }
    
    /// フェーズ用の便利メソッド
    static func createPhaseListener(
        projectId: String,
        activeListeners: inout [String: ListenerRegistration],
        listenerMetadata: inout [String: FirebaseListenerManager.ListenerMetadata],
        updateAccessCallback: @escaping (String) -> Void,
        updateStatisticsCallback: @escaping () -> Void,
        optimizeCallback: @escaping () -> Void,
        completion: @escaping (Result<[Phase], FirebaseError>) -> Void
    ) -> String {
        let id = "phases_\(projectId)"
        let query = Firestore.firestore()
            .collection("projects").document(projectId)
            .collection("phases")
            .order(by: "order")
        
        return createListener(
            id: id,
            query: query,
            type: .phase,
            priority: .medium,
            activeListeners: &activeListeners,
            listenerMetadata: &listenerMetadata,
            updateAccessCallback: updateAccessCallback,
            updateStatisticsCallback: updateStatisticsCallback,
            optimizeCallback: optimizeCallback,
            completion: completion
        )
    }
    
    /// タスクリスト用の便利メソッド
    static func createTaskListListener(
        projectId: String,
        phaseId: String,
        activeListeners: inout [String: ListenerRegistration],
        listenerMetadata: inout [String: FirebaseListenerManager.ListenerMetadata],
        updateAccessCallback: @escaping (String) -> Void,
        updateStatisticsCallback: @escaping () -> Void,
        optimizeCallback: @escaping () -> Void,
        completion: @escaping (Result<[TaskList], FirebaseError>) -> Void
    ) -> String {
        let id = "tasklists_\(projectId)_\(phaseId)"
        let query = Firestore.firestore()
            .collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("lists")
            .order(by: "order")
        
        return createListener(
            id: id,
            query: query,
            type: .taskList,
            priority: .medium,
            activeListeners: &activeListeners,
            listenerMetadata: &listenerMetadata,
            updateAccessCallback: updateAccessCallback,
            updateStatisticsCallback: updateStatisticsCallback,
            optimizeCallback: optimizeCallback,
            completion: completion
        )
    }
    
    /// タスク用の便利メソッド
    static func createTaskListener(
        projectId: String,
        phaseId: String,
        listId: String,
        activeListeners: inout [String: ListenerRegistration],
        listenerMetadata: inout [String: FirebaseListenerManager.ListenerMetadata],
        updateAccessCallback: @escaping (String) -> Void,
        updateStatisticsCallback: @escaping () -> Void,
        optimizeCallback: @escaping () -> Void,
        completion: @escaping (Result<[ShigodekiTask], FirebaseError>) -> Void
    ) -> String {
        let id = "tasks_\(projectId)_\(phaseId)_\(listId)"
        let query = Firestore.firestore()
            .collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("lists").document(listId)
            .collection("tasks")
            .order(by: "order")
        
        return createListener(
            id: id,
            query: query,
            type: .task,
            priority: .low, // タスクは低優先度（頻繁に変更される）
            activeListeners: &activeListeners,
            listenerMetadata: &listenerMetadata,
            updateAccessCallback: updateAccessCallback,
            updateStatisticsCallback: updateStatisticsCallback,
            optimizeCallback: optimizeCallback,
            completion: completion
        )
    }
}