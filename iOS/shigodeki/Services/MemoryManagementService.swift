//
//  MemoryManagementService.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import Foundation
import UIKit

struct MemoryManagementService {
    
    // MARK: - Memory Usage Monitoring
    
    /// 現在のメモリ使用量を取得（MB単位）
    static func getCurrentMemoryUsage() -> Double {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else { return 0.0 }
        return Double(taskInfo.resident_size) / 1024.0 / 1024.0
    }
    
    // MARK: - Cache Management
    
    /// 統合キャッシュシステムのクリーンアップ
    @MainActor
    static func cleanupIntegratedCaches() {
        // CacheManagerの一般キャッシュクリア
        CacheManager.shared.clearAll()
        
        // ImageCacheの画像キャッシュクリア
        ImageCache.shared.clearCache()
        
        // Firebase Listener Managerの最適化
        FirebaseListenerManager.shared.optimizeListeners()
        
        #if DEBUG
        print("🗑️ SharedManagerStore: All caches cleaned up")
        #endif
    }
    
    // MARK: - Smart Memory Management
    
    /// スマートキャッシュ管理（メモリ使用量に基づく）
    @MainActor
    static func performSmartCacheManagement(
        currentMemoryUsage: Double,
        aiGeneratorRef: inout AITaskGenerator?,
        taskImprovementEngineRef: inout TaskImprovementEngine?
    ) {
        if currentMemoryUsage > 200 { // 200MB超過時
            #if DEBUG
            print("⚠️ SharedManagerStore: High memory usage (\(currentMemoryUsage)MB), performing aggressive cleanup")
            #endif
            cleanupIntegratedCaches()
            
            // 低優先度のManagerを一時解放
            if aiGeneratorRef != nil {
                aiGeneratorRef = nil
                print("🗑️ Temporarily released AITaskGenerator")
            }
            if taskImprovementEngineRef != nil {
                taskImprovementEngineRef = nil
                print("🗑️ Temporarily released TaskImprovementEngine")
            }
            
        } else if currentMemoryUsage > 150 { // 150MB超過時
            #if DEBUG
            print("🟡 SharedManagerStore: Moderate memory usage (\(currentMemoryUsage)MB), performing selective cleanup")
            #endif
            
            // 古いキャッシュのみクリア
            CacheManager.shared.clearAll()
            
            // Firebase Listenerの最適化
            FirebaseListenerManager.shared.optimizeListeners()
        }
    }
    
    // MARK: - Manager Cleanup
    
    /// 各Managerのリスナーを削除（非同期）
    static func cleanupManagerListeners(
        projectManager: ProjectManager?,
        taskManager: EnhancedTaskManager?,
        phaseManager: PhaseManager?,
        subtaskManager: SubtaskManager?,
        taskListManager: TaskListManager?
    ) async {
        print("🧹 SharedManagerStore: Cleaning up unused managers and caches")
        
        // 各Managerのリスナーを削除（非同期）
        if let projectManager = projectManager {
            await MainActor.run { projectManager.removeAllListeners() }
        }
        if let taskManager = taskManager {
            await MainActor.run { taskManager.removeAllListeners() }
        }
        if let phaseManager = phaseManager {
            await MainActor.run { phaseManager.removeAllListeners() }
        }
        if let subtaskManager = subtaskManager {
            await MainActor.run { subtaskManager.removeAllListeners() }
        }
        if let taskListManager = taskListManager {
            await MainActor.run { taskListManager.removeAllListeners() }
        }
        
        await MainActor.run {
            cleanupIntegratedCaches()
            InstrumentsSetup.shared.logMemoryUsage(context: "After Manager and Cache Cleanup")
        }
    }
    
    // MARK: - Memory Warning Handling
    
    static func setupMemoryWarningHandling(cleanupHandler: @escaping () async -> Void) {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                print("⚠️ SharedManagerStore: Memory warning received, cleaning up")
                await cleanupHandler()
            }
        }
    }
}