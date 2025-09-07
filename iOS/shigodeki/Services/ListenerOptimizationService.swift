//
//  ListenerOptimizationService.swift
//  shigodeki
//
//  Created by Claude on 2025-09-06.
//

import Foundation
import FirebaseFirestore
import os

struct ListenerOptimizationService {
    // MARK: - Smart Optimization
    
    /// 自動リスナー最適化
    static func optimizeListeners(
        activeListeners: [String: ListenerRegistration],
        listenerMetadata: [String: FirebaseListenerManager.ListenerMetadata],
        currentStats: FirebaseListenerManager.ListenerStatistics,
        removeListenersCallback: @escaping ([String]) -> Void
    ) -> FirebaseListenerManager.ListenerStatistics {
        let now = Date()
        let inactiveThreshold: TimeInterval = 300 // 5分
        
        // 非アクティブなリスナーを特定
        let inactiveListeners = listenerMetadata.compactMap { key, metadata in
            now.timeIntervalSince(metadata.lastAccessed) > inactiveThreshold && metadata.priority == .low ? key : nil
        }
        
        var updatedStats = currentStats
        if !inactiveListeners.isEmpty {
            removeListenersCallback(inactiveListeners)
            updatedStats.lastOptimized = now
        }
        return updatedStats
    }
    
    /// アクセス頻度に基づく優先度調整
    static func updateAccessMetadata(
        for id: String,
        listenerMetadata: [String: FirebaseListenerManager.ListenerMetadata]
    ) -> [String: FirebaseListenerManager.ListenerMetadata] {
        guard let metadata = listenerMetadata[id] else { return listenerMetadata }
        
        var updatedMetadata = listenerMetadata
        updatedMetadata[id] = FirebaseListenerManager.ListenerMetadata(
            id: metadata.id,
            type: metadata.type,
            createdAt: metadata.createdAt,
            lastAccessed: Date(),
            accessCount: metadata.accessCount + 1,
            path: metadata.path,
            priority: metadata.priority
        )
        
        return updatedMetadata
    }
    
    /// 統計情報の更新
    static func updateStatistics(
        activeListeners: [String: ListenerRegistration],
        listenerMetadata: [String: FirebaseListenerManager.ListenerMetadata],
        currentStats: FirebaseListenerManager.ListenerStatistics
    ) -> FirebaseListenerManager.ListenerStatistics {
        var updatedStats = currentStats
        updatedStats.totalActive = activeListeners.count
        
        var typeCount: [String: Int] = [:]
        for metadata in listenerMetadata.values {
            let typeKey = String(describing: metadata.type)
            typeCount[typeKey, default: 0] += 1
        }
        updatedStats.byType = typeCount
        
        // メモリ使用量の推定（1リスナーあたり約0.5MB）
        updatedStats.memoryUsage = Double(activeListeners.count) * 0.5
        
        return updatedStats
    }
    
    // MARK: - Memory Management
    
    /// メモリ警告時の処理
    static func handleMemoryWarning(
        listenerMetadata: [String: FirebaseListenerManager.ListenerMetadata],
        removeListenersCallback: @escaping ([String]) -> Void
    ) {
        // 低優先度のリスナーを削除
        let lowPriorityIds = listenerMetadata.compactMap { key, metadata in
            metadata.priority == .low ? key : nil
        }
        
        if !lowPriorityIds.isEmpty {
            removeListenersCallback(lowPriorityIds)
        }
        
        InstrumentsSetup.shared.logMemoryUsage(context: "After Memory Warning Cleanup")
    }
    
    // MARK: - Debugging and Monitoring
    
    /// リスナー状況の詳細レポート
    static func getDetailedReport(
        listenerStats: FirebaseListenerManager.ListenerStatistics,
        listenerMetadata: [String: FirebaseListenerManager.ListenerMetadata]
    ) -> String {
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
    static func logDebugInfo(
        listenerStats: FirebaseListenerManager.ListenerStatistics,
        listenerMetadata: [String: FirebaseListenerManager.ListenerMetadata]
    ) {
        let report = getDetailedReport(listenerStats: listenerStats, listenerMetadata: listenerMetadata)
        print(report)
        
        // OSLogにも記録
        os_log(.info, log: InstrumentsSetup.firebaseLog, "%{public}@", report)
    }
}