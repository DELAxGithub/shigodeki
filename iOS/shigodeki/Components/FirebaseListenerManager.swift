//
//  FirebaseListenerManager.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import Foundation
import FirebaseFirestore
import Combine
import os

/// 中央集中化されたFirebaseリスナー管理システム
/// Phase 1で特定された「20個のリスナー過剰使用」問題を解決
@MainActor
class FirebaseListenerManager: ObservableObject {
    
    // MARK: - Singleton Pattern
    
    static let shared = FirebaseListenerManager()
    
    private init() {
        setupMemoryWarningHandling()
    }
    
    // MARK: - Listener Management
    
    /// アクティブなリスナーの管理
    private var activeListeners: [String: ListenerRegistration] = [:]
    
    /// リスナーのメタデータ
    private var listenerMetadata: [String: ListenerMetadata] = [:]
    
    /// リスナー使用状況の統計
    @Published var listenerStats = ListenerStatistics()
    
    // MARK: - Listener Metadata
    
    struct ListenerMetadata {
        let id: String
        let type: ListenerType
        let createdAt: Date
        let lastAccessed: Date
        let accessCount: Int
        let path: String
        let priority: Priority
        
        enum ListenerType {
            case project, phase, taskList, task, subtask, user, family
        }
        
        enum Priority {
            case high, medium, low
        }
    }
    
    struct ListenerStatistics {
        var totalActive: Int = 0
        var byType: [String: Int] = [:]
        var memoryUsage: Double = 0.0
        var lastOptimized: Date?
    }
    
    // MARK: - Smart Listener Creation
    
    /// インテリジェントなリスナー作成（重複チェック付き）
    func createListener<T: Codable>(
        id: String,
        query: Query,
        type: ListenerMetadata.ListenerType,
        priority: ListenerMetadata.Priority = .medium,
        completion: @escaping (Result<[T], FirebaseError>) -> Void
    ) -> String {
        
        // 既存リスナーの確認
        if activeListeners[id] != nil {
            updateAccessMetadata(for: id)
            InstrumentsSetup.shared.endFirebaseConnectionMeasurement(operation: "Listener Reuse", success: true)
            return id
        }
        
        InstrumentsSetup.shared.startFirebaseConnectionMeasurement(operation: "Create Listener: \(id)")
        
        // 新しいリスナーを作成
        let listener = query.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                self?.updateAccessMetadata(for: id)
                
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
        listenerMetadata[id] = ListenerMetadata(
            id: id,
            type: type,
            createdAt: Date(),
            lastAccessed: Date(),
            accessCount: 1,
            path: query.description,
            priority: priority
        )
        
        updateStatistics()
        
        // 自動最適化のトリガー
        if activeListeners.count > 15 {
            optimizeListeners()
        }
        
        return id
    }
    
    /// 単一ドキュメント用のリスナー作成
    func createDocumentListener<T: Codable>(
        id: String,
        document: DocumentReference,
        type: ListenerMetadata.ListenerType,
        priority: ListenerMetadata.Priority = .medium,
        completion: @escaping (Result<T?, FirebaseError>) -> Void
    ) -> String {
        
        // 既存リスナーチェック
        if activeListeners[id] != nil {
            updateAccessMetadata(for: id)
            return id
        }
        
        InstrumentsSetup.shared.startFirebaseConnectionMeasurement(operation: "Create Document Listener: \(id)")
        
        let listener = document.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                self?.updateAccessMetadata(for: id)
                
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
        listenerMetadata[id] = ListenerMetadata(
            id: id,
            type: type,
            createdAt: Date(),
            lastAccessed: Date(),
            accessCount: 1,
            path: document.path,
            priority: priority
        )
        
        updateStatistics()
        return id
    }
    
    // MARK: - Listener Management Operations
    
    /// リスナーの削除
    func removeListener(id: String) {
        guard let listener = activeListeners[id] else { return }
        
        listener.remove()
        activeListeners.removeValue(forKey: id)
        listenerMetadata.removeValue(forKey: id)
        
        updateStatistics()
        InstrumentsSetup.shared.logMemoryUsage(context: "After Listener Removal")
    }
    
    /// 複数リスナーの一括削除
    func removeListeners(ids: [String]) {
        for id in ids {
            removeListener(id: id)
        }
    }
    
    /// タイプ別リスナー削除
    func removeListeners(ofType type: ListenerMetadata.ListenerType) {
        let idsToRemove = listenerMetadata.compactMap { key, metadata in
            metadata.type == type ? key : nil
        }
        removeListeners(ids: idsToRemove)
    }
    
    /// 全リスナーの削除
    func removeAllListeners() {
        for (_, listener) in activeListeners {
            listener.remove()
        }
        activeListeners.removeAll()
        listenerMetadata.removeAll()
        updateStatistics()
        InstrumentsSetup.shared.logMemoryUsage(context: "After All Listeners Removal")
    }
    
    // MARK: - Smart Optimization
    
    /// 自動リスナー最適化
    func optimizeListeners() {
        let now = Date()
        let inactiveThreshold: TimeInterval = 300 // 5分
        
        // 非アクティブなリスナーを特定
        let inactiveListeners = listenerMetadata.compactMap { key, metadata in
            now.timeIntervalSince(metadata.lastAccessed) > inactiveThreshold && metadata.priority == .low ? key : nil
        }
        
        if !inactiveListeners.isEmpty {
            removeListeners(ids: inactiveListeners)
            listenerStats.lastOptimized = now
        }
    }
    
    /// アクセス頻度に基づく優先度調整
    private func updateAccessMetadata(for id: String) {
        guard let metadata = listenerMetadata[id] else { return }
        
        listenerMetadata[id] = ListenerMetadata(
            id: metadata.id,
            type: metadata.type,
            createdAt: metadata.createdAt,
            lastAccessed: Date(),
            accessCount: metadata.accessCount + 1,
            path: metadata.path,
            priority: metadata.priority
        )
    }
    
    /// 統計情報の更新
    private func updateStatistics() {
        listenerStats.totalActive = activeListeners.count
        
        var typeCount: [String: Int] = [:]
        for metadata in listenerMetadata.values {
            let typeKey = String(describing: metadata.type)
            typeCount[typeKey, default: 0] += 1
        }
        listenerStats.byType = typeCount
        
        // メモリ使用量の推定（1リスナーあたり約0.5MB）
        listenerStats.memoryUsage = Double(activeListeners.count) * 0.5
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryWarningHandling() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
    }
    
    private func handleMemoryWarning() {
        // 低優先度のリスナーを削除
        let lowPriorityIds = listenerMetadata.compactMap { key, metadata in
            metadata.priority == .low ? key : nil
        }
        
        if !lowPriorityIds.isEmpty {
            removeListeners(ids: lowPriorityIds)
        }
        
        InstrumentsSetup.shared.logMemoryUsage(context: "After Memory Warning Cleanup")
    }
    
    // MARK: - Debugging and Monitoring
    
    /// リスナー状況の詳細レポート
    func getDetailedReport() -> String {
        var report = "📊 Firebase Listener Manager Report\n"
        report += "====================================\n"
        report += "Total Active Listeners: \(listenerStats.totalActive)\n"
        report += "Memory Usage: \(String(format: "%.1f", listenerStats.memoryUsage))MB\n"
        
        if let lastOptimized = listenerStats.lastOptimized {
            report += "Last Optimized: \(DateFormatter.localizedString(from: lastOptimized, dateStyle: .short, timeStyle: .medium))\n"
        }
        
        report += "\nBy Type:\n"
        for (type, count) in listenerStats.byType.sorted(by: { $0.value > $1.value }) {
            report += "  \(type): \(count)\n"
        }
        
        report += "\nActive Listeners:\n"
        for (id, metadata) in listenerMetadata.sorted(by: { $0.value.lastAccessed > $1.value.lastAccessed }) {
            let timeSinceAccess = Date().timeIntervalSince(metadata.lastAccessed)
            report += "  [\(metadata.type)] \(id) - Accessed: \(Int(timeSinceAccess))s ago (\(metadata.accessCount) times)\n"
        }
        
        return report
    }
    
    /// デバッグ情報のログ出力
    func logDebugInfo() {
        let report = getDetailedReport()
        print(report)
        
        // OSLogにも記録
        os_log(.info, log: InstrumentsSetup.firebaseLog, "%{public}@", report)
    }
}

// MARK: - Convenience Extensions

extension FirebaseListenerManager {
    
    /// プロジェクト用の便利メソッド
    func createProjectListener(
        userId: String,
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
            completion: completion
        )
    }
    
    /// フェーズ用の便利メソッド
    func createPhaseListener(
        projectId: String,
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
            completion: completion
        )
    }
    
    /// タスクリスト用の便利メソッド
    func createTaskListListener(
        projectId: String,
        phaseId: String,
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
            completion: completion
        )
    }
    
    /// タスク用の便利メソッド
    func createTaskListener(
        projectId: String,
        phaseId: String,
        listId: String,
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
            completion: completion
        )
    }
}