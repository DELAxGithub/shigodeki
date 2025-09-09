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
    
    /// Thread safety for listenerStats updates
    private let statsQueue = DispatchQueue(label: "com.shigodeki.listenerStats", attributes: .concurrent)
    
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
        
        return ListenerCreationService.createListener(
            id: id,
            query: query,
            type: type,
            priority: priority,
            activeListeners: &activeListeners,
            listenerMetadata: &listenerMetadata,
            updateAccessCallback: { [weak self] id in
                self?.updateAccessMetadata(for: id)
            },
            updateStatisticsCallback: { [weak self] in
                self?.updateStatistics()
            },
            optimizeCallback: { [weak self] in
                self?.optimizeListeners()
            },
            completion: completion
        )
    }
    
    /// 単一ドキュメント用のリスナー作成
    func createDocumentListener<T: Codable>(
        id: String,
        document: DocumentReference,
        type: ListenerMetadata.ListenerType,
        priority: ListenerMetadata.Priority = .medium,
        completion: @escaping (Result<T?, FirebaseError>) -> Void
    ) -> String {
        
        return ListenerCreationService.createDocumentListener(
            id: id,
            document: document,
            type: type,
            priority: priority,
            activeListeners: &activeListeners,
            listenerMetadata: &listenerMetadata,
            updateAccessCallback: { [weak self] id in
                self?.updateAccessMetadata(for: id)
            },
            updateStatisticsCallback: { [weak self] in
                self?.updateStatistics()
            },
            completion: completion
        )
    }
    
    // MARK: - Listener Management Operations
    
    /// リスナーの削除
    func removeListener(id: String) {
        ListenerManagementService.removeListener(
            id: id,
            activeListeners: &activeListeners,
            listenerMetadata: &listenerMetadata,
            updateStatisticsCallback: { [weak self] in
                self?.updateStatistics()
            }
        )
    }
    
    /// 複数リスナーの一括削除
    func removeListeners(ids: [String]) {
        ListenerManagementService.removeListeners(
            ids: ids,
            activeListeners: &activeListeners,
            listenerMetadata: &listenerMetadata,
            updateStatisticsCallback: { [weak self] in
                self?.updateStatistics()
            }
        )
    }
    
    /// タイプ別リスナー削除
    func removeListeners(ofType type: ListenerMetadata.ListenerType) {
        ListenerManagementService.removeListeners(
            ofType: type,
            listenerMetadata: listenerMetadata,
            activeListeners: &activeListeners,
            listenerMetadataRef: &listenerMetadata,
            updateStatisticsCallback: { [weak self] in
                self?.updateStatistics()
            }
        )
    }
    
    /// 全リスナーの削除
    func removeAllListeners() {
        ListenerManagementService.removeAllListeners(
            activeListeners: &activeListeners,
            listenerMetadata: &listenerMetadata,
            updateStatisticsCallback: { [weak self] in
                self?.updateStatistics()
            }
        )
    }
    
    // MARK: - Smart Optimization
    
    /// 自動リスナー最適化
    func optimizeListeners() {
        listenerStats = ListenerOptimizationService.optimizeListeners(
            activeListeners: activeListeners,
            listenerMetadata: listenerMetadata,
            currentStats: listenerStats,
            removeListenersCallback: { [weak self] ids in
                self?.removeListeners(ids: ids)
            }
        )
    }
    
    /// アクセス頻度に基づく優先度調整
    private func updateAccessMetadata(for id: String) {
        listenerMetadata = ListenerOptimizationService.updateAccessMetadata(
            for: id,
            listenerMetadata: listenerMetadata
        )
    }
    
    /// 統計情報の更新 - Thread-safe implementation
    private func updateStatistics() {
        // Take snapshots on the main actor to avoid crossing isolation in background closure
        let active = activeListeners
        let metadata = listenerMetadata
        let stats = listenerStats
        
        statsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let updatedStats = ListenerOptimizationService.updateStatistics(
                activeListeners: active,
                listenerMetadata: metadata,
                currentStats: stats
            )
            
            DispatchQueue.main.async {
                self.listenerStats = updatedStats
            }
        }
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
        ListenerOptimizationService.handleMemoryWarning(
            listenerMetadata: listenerMetadata,
            removeListenersCallback: { [weak self] ids in
                self?.removeListeners(ids: ids)
            }
        )
    }
    
    // MARK: - Debugging and Monitoring
    
    /// リスナー状況の詳細レポート
    func getDetailedReport() -> String {
        return ListenerOptimizationService.getDetailedReport(
            listenerStats: listenerStats,
            listenerMetadata: listenerMetadata
        )
    }
    
    /// デバッグ情報のログ出力
    func logDebugInfo() {
        ListenerOptimizationService.logDebugInfo(
            listenerStats: listenerStats,
            listenerMetadata: listenerMetadata
        )
    }
}

// MARK: - Convenience Extensions

extension FirebaseListenerManager {
    
    /// プロジェクト用の便利メソッド
    func createProjectListener(
        userId: String,
        completion: @escaping (Result<[Project], FirebaseError>) -> Void
    ) -> String {
        return ListenerCreationService.createProjectListener(
            userId: userId,
            activeListeners: &activeListeners,
            listenerMetadata: &listenerMetadata,
            updateAccessCallback: { [weak self] id in
                self?.updateAccessMetadata(for: id)
            },
            updateStatisticsCallback: { [weak self] in
                self?.updateStatistics()
            },
            optimizeCallback: { [weak self] in
                self?.optimizeListeners()
            },
            completion: completion
        )
    }
    
    /// フェーズ用の便利メソッド
    func createPhaseListener(
        projectId: String,
        completion: @escaping (Result<[Phase], FirebaseError>) -> Void
    ) -> String {
        return ListenerCreationService.createPhaseListener(
            projectId: projectId,
            activeListeners: &activeListeners,
            listenerMetadata: &listenerMetadata,
            updateAccessCallback: { [weak self] id in
                self?.updateAccessMetadata(for: id)
            },
            updateStatisticsCallback: { [weak self] in
                self?.updateStatistics()
            },
            optimizeCallback: { [weak self] in
                self?.optimizeListeners()
            },
            completion: completion
        )
    }
    
    /// タスクリスト用の便利メソッド
    func createTaskListListener(
        projectId: String,
        phaseId: String,
        completion: @escaping (Result<[TaskList], FirebaseError>) -> Void
    ) -> String {
        return ListenerCreationService.createTaskListListener(
            projectId: projectId,
            phaseId: phaseId,
            activeListeners: &activeListeners,
            listenerMetadata: &listenerMetadata,
            updateAccessCallback: { [weak self] id in
                self?.updateAccessMetadata(for: id)
            },
            updateStatisticsCallback: { [weak self] in
                self?.updateStatistics()
            },
            optimizeCallback: { [weak self] in
                self?.optimizeListeners()
            },
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
        return ListenerCreationService.createTaskListener(
            projectId: projectId,
            phaseId: phaseId,
            listId: listId,
            activeListeners: &activeListeners,
            listenerMetadata: &listenerMetadata,
            updateAccessCallback: { [weak self] id in
                self?.updateAccessMetadata(for: id)
            },
            updateStatisticsCallback: { [weak self] in
                self?.updateStatistics()
            },
            optimizeCallback: { [weak self] in
                self?.optimizeListeners()
            },
            completion: completion
        )
    }
}
