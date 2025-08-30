//
//  SharedManagerStore.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import Foundation
import SwiftUI
import Combine
import os

/// 中央集中化されたManager管理システム  
/// Phase 1で特定された「36個の@StateObject重複作成」問題を解決
/// 非同期関数でデッドロック問題を根本解決
@MainActor
class SharedManagerStore: ObservableObject {
    
    // MARK: - Singleton Pattern
    
    static let shared = SharedManagerStore()
    
    // MARK: - Thread Safety (非同期関数により保証)
    private var isCreatingManager: Set<String> = []
    
    private init() {
        setupMemoryWarningHandling()
    }
    
    // MARK: - Shared Manager Instances
    
    /// 認証管理（最も頻繁に使用される）
    @Published private var _authManager: AuthenticationManager?
    
    /// プロジェクト管理
    @Published private var _projectManager: ProjectManager?
    
    /// タスク管理（統合版）
    @Published private var _taskManager: EnhancedTaskManager?
    
    /// フェーズ管理
    @Published private var _phaseManager: PhaseManager?
    
    /// サブタスク管理
    @Published private var _subtaskManager: SubtaskManager?
    
    /// 家族管理
    @Published private var _familyManager: FamilyManager?
    
    /// タスクリスト管理
    @Published private var _taskListManager: TaskListManager?
    
    /// AI関連
    @Published private var _aiGenerator: AITaskGenerator?
    
    /// タスク改善エンジン
    @Published private var _taskImprovementEngine: TaskImprovementEngine?
    
    // MARK: - Thread-Safe Manager Creation
    
    /// 非同期Manager作成メソッド（デッドロック回避）
    private func createManagerSafely<T>(
        key: String,
        existing: T?,
        create: @escaping () -> T,
        assign: @escaping (T) -> Void,
        logContext: String
    ) async -> T {
        // 既存インスタンスがある場合はそのまま返す
        if let existing = existing {
            return existing
        }
        
        // 既に作成中の場合は待機（非同期）
        if isCreatingManager.contains(key) {
            print("⏳ SharedManagerStore: \(key) is being created, waiting...")
            
            // 作成完了まで非同期待機（最大5秒でタイムアウト）
            let startTime = Date()
            let maxWaitTime: TimeInterval = 5.0
            
            while isCreatingManager.contains(key) && Date().timeIntervalSince(startTime) < maxWaitTime {
                try? await Task.sleep(for: .milliseconds(10))
            }
            
            // タイムアウトした場合
            if Date().timeIntervalSince(startTime) >= maxWaitTime {
                print("❌ SharedManagerStore: Timeout waiting for \(key) creation, forcing cleanup")
                isCreatingManager.remove(key)
            }
            
            // 作成完了後に再度チェック
            if let existing = existing {
                print("✅ SharedManagerStore: \(key) created by other thread")
                return existing
            }
        }
        
        // 作成中フラグを立てる
        isCreatingManager.insert(key)
        
        // Managerを作成（MainActorで実行）
        let newManager = create()
        
        // 状態更新
        assign(newManager)
        
        #if DEBUG
        InstrumentsSetup.shared.logMemoryUsage(context: logContext)
        print("🏭 SharedManagerStore: Created \(key)")
        #endif
        
        // 作成完了フラグをクリア
        isCreatingManager.remove(key)
        
        return newManager
    }
    
    // MARK: - Instance Access with Lazy Initialization
    
    /// AuthenticationManager のシングルインスタンス（非同期）
    func getAuthManager() async -> AuthenticationManager {
        return await createManagerSafely(
            key: "AuthManager",
            existing: _authManager,
            create: { AuthenticationManager() },
            assign: { self._authManager = $0 },
            logContext: "AuthManager Created"
        )
    }
    
    /// ProjectManager のシングルインスタンス（非同期）
    func getProjectManager() async -> ProjectManager {
        return await createManagerSafely(
            key: "ProjectManager",
            existing: _projectManager,
            create: { ProjectManager() },
            assign: { self._projectManager = $0 },
            logContext: "ProjectManager Created"
        )
    }
    
    /// EnhancedTaskManager のシングルインスタンス（非同期）
    func getTaskManager() async -> EnhancedTaskManager {
        return await createManagerSafely(
            key: "EnhancedTaskManager",
            existing: _taskManager,
            create: { EnhancedTaskManager() },
            assign: { self._taskManager = $0 },
            logContext: "TaskManager Created"
        )
    }
    
    /// PhaseManager のシングルインスタンス（非同期）
    func getPhaseManager() async -> PhaseManager {
        return await createManagerSafely(
            key: "PhaseManager",
            existing: _phaseManager,
            create: { PhaseManager() },
            assign: { self._phaseManager = $0 },
            logContext: "PhaseManager Created"
        )
    }
    
    /// SubtaskManager のシングルインスタンス（非同期）
    func getSubtaskManager() async -> SubtaskManager {
        return await createManagerSafely(
            key: "SubtaskManager",
            existing: _subtaskManager,
            create: { SubtaskManager() },
            assign: { self._subtaskManager = $0 },
            logContext: "SubtaskManager Created"
        )
    }
    
    /// FamilyManager のシングルインスタンス（非同期）
    func getFamilyManager() async -> FamilyManager {
        return await createManagerSafely(
            key: "FamilyManager",
            existing: _familyManager,
            create: { FamilyManager() },
            assign: { self._familyManager = $0 },
            logContext: "FamilyManager Created"
        )
    }
    
    /// TaskListManager のシングルインスタンス（非同期）
    func getTaskListManager() async -> TaskListManager {
        return await createManagerSafely(
            key: "TaskListManager",
            existing: _taskListManager,
            create: { TaskListManager() },
            assign: { self._taskListManager = $0 },
            logContext: "TaskListManager Created"
        )
    }
    
    /// AITaskGenerator のシングルインスタンス（非同期）
    func getAiGenerator() async -> AITaskGenerator {
        return await createManagerSafely(
            key: "AITaskGenerator",
            existing: _aiGenerator,
            create: { AITaskGenerator() },
            assign: { self._aiGenerator = $0 },
            logContext: "AIGenerator Created"
        )
    }
    
    /// TaskImprovementEngine のシングルインスタンス（非同期）
    func getTaskImprovementEngine() async -> TaskImprovementEngine {
        return await createManagerSafely(
            key: "TaskImprovementEngine",
            existing: _taskImprovementEngine,
            create: { 
                TaskImprovementEngine(
                    aiGenerator: AITaskGenerator(),
                    taskManager: TaskManager(),
                    familyManager: FamilyManager()
                )
            },
            assign: { self._taskImprovementEngine = $0 },
            logContext: "TaskImprovementEngine Created"
        )
    }
    
    // MARK: - Memory Management (🆕 統合キャッシュ管理)
    
    /// 未使用のManagerインスタンスを解放
    func cleanupUnusedManagers() async {
        #if DEBUG
        print("🧹 SharedManagerStore: Cleaning up unused managers and caches")
        #endif
        
        // 各Managerのリスナーを削除（非同期）
        if let projectManager = _projectManager {
            await MainActor.run { projectManager.removeAllListeners() }
        }
        if let taskManager = _taskManager {
            await MainActor.run { taskManager.removeAllListeners() }
        }
        if let phaseManager = _phaseManager {
            await MainActor.run { phaseManager.removeAllListeners() }
        }
        if let subtaskManager = _subtaskManager {
            await MainActor.run { subtaskManager.removeAllListeners() }
        }
        
        // 🆕 統合キャッシュシステムのクリーンアップ
        await cleanupIntegratedCaches()
        
        await MainActor.run {
            InstrumentsSetup.shared.logMemoryUsage(context: "After Manager and Cache Cleanup")
        }
    }
    
    /// 統合キャッシュシステムのクリーンアップ
    private func cleanupIntegratedCaches() async {
        await MainActor.run {
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
    }
    
    /// 🆕 スマートキャッシュ管理（メモリ使用量に基づく）
    func smartCacheManagement() async {
        let memoryUsage = getCurrentMemoryUsage()
        
        if memoryUsage > 200 { // 200MB超過時
            #if DEBUG
            print("⚠️ SharedManagerStore: High memory usage (\(memoryUsage)MB), performing aggressive cleanup")
            #endif
            await cleanupIntegratedCaches()
            
            // 低優先度のManagerを一時解放
            if _aiGenerator != nil {
                _aiGenerator = nil
                print("🗑️ Temporarily released AITaskGenerator")
            }
            if _taskImprovementEngine != nil {
                _taskImprovementEngine = nil
                print("🗑️ Temporarily released TaskImprovementEngine")
            }
            
        } else if memoryUsage > 150 { // 150MB超過時
            #if DEBUG
            print("🟡 SharedManagerStore: Moderate memory usage (\(memoryUsage)MB), performing selective cleanup")
            #endif
            
            await MainActor.run {
                // 古いキャッシュのみクリア
                CacheManager.shared.clearAll()
                
                // Firebase Listenerの最適化
                FirebaseListenerManager.shared.optimizeListeners()
            }
        }
    }
    
    /// 現在のメモリ使用量を取得（MB単位）
    func getCurrentMemoryUsage() -> Double {
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
    
    /// 全Managerのリスナーを削除（非同期）
    func removeAllListeners() async {
        print("🧹 SharedManagerStore: Removing all listeners from shared managers")
        
        // 各Managerのリスナーを削除（MainActorで実行）
        if let projectManager = _projectManager {
            await MainActor.run { projectManager.removeAllListeners() }
        }
        if let taskManager = _taskManager {
            await MainActor.run { taskManager.removeAllListeners() }
        }
        if let phaseManager = _phaseManager {
            await MainActor.run { phaseManager.removeAllListeners() }
        }
        if let subtaskManager = _subtaskManager {
            await MainActor.run { subtaskManager.removeAllListeners() }
        }
        if let taskListManager = _taskListManager {
            await MainActor.run { taskListManager.removeAllListeners() }
        }
        
        // Firebase リスナー統計の表示
        await MainActor.run { FirebaseListenerManager.shared.logDebugInfo() }
    }
    
    /// メモリ警告ハンドリング
    @MainActor
    private func setupMemoryWarningHandling() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleMemoryWarning()
            }
        }
    }
    
    private func handleMemoryWarning() async {
        print("⚠️ SharedManagerStore: Memory warning received, cleaning up")
        await cleanupUnusedManagers()
    }
    
    // MARK: - Debug and Monitoring
    
    /// アクティブなManagerの統計を取得
    func getManagerStatistics() -> ManagerStatistics {
        return ManagerStatistics(
            authManagerActive: _authManager != nil,
            projectManagerActive: _projectManager != nil,
            taskManagerActive: _taskManager != nil,
            phaseManagerActive: _phaseManager != nil,
            subtaskManagerActive: _subtaskManager != nil,
            familyManagerActive: _familyManager != nil,
            taskListManagerActive: _taskListManager != nil,
            aiGeneratorActive: _aiGenerator != nil,
            taskImprovementEngineActive: _taskImprovementEngine != nil
        )
    }
    
    struct ManagerStatistics {
        let authManagerActive: Bool
        let projectManagerActive: Bool
        let taskManagerActive: Bool
        let phaseManagerActive: Bool
        let subtaskManagerActive: Bool
        let familyManagerActive: Bool
        let taskListManagerActive: Bool
        let aiGeneratorActive: Bool
        let taskImprovementEngineActive: Bool
        
        var totalActiveManagers: Int {
            [authManagerActive, projectManagerActive, taskManagerActive,
             phaseManagerActive, subtaskManagerActive, familyManagerActive,
             taskListManagerActive, aiGeneratorActive, taskImprovementEngineActive].filter { $0 }.count
        }
        
        var memoryEstimate: Double {
            // 各Managerの推定メモリ使用量（MB）
            var estimate = 0.0
            if authManagerActive { estimate += 10.0 }
            if projectManagerActive { estimate += 15.0 }
            if taskManagerActive { estimate += 12.0 }
            if phaseManagerActive { estimate += 8.0 }
            if subtaskManagerActive { estimate += 8.0 }
            if familyManagerActive { estimate += 6.0 }
            if taskListManagerActive { estimate += 10.0 }
            if aiGeneratorActive { estimate += 5.0 }
            if taskImprovementEngineActive { estimate += 8.0 }
            
            // 🆕 統合キャッシュシステムの推定使用量を追加（簡略化）
            estimate += 35.0 // getCacheMemoryEstimate() の代替として固定値
            
            return estimate
        }
        
        // 🆕 キャッシュメモリ使用量の推定
        @MainActor func getCacheMemoryEstimate() -> Double {
            var cacheMemory = 0.0
            
            // ImageCache: 最大50MB設定
            cacheMemory += 25.0 // 平均使用量として推定
            
            // CacheManager: 最大50MB設定  
            cacheMemory += 10.0 // 一般データキャッシュ
            
            // Firebase Listener Manager
            cacheMemory += FirebaseListenerManager.shared.listenerStats.memoryUsage
            
            return cacheMemory
        }
    }
    
    /// デバッグレポートの生成
    func generateDebugReport() -> String {
        let stats = getManagerStatistics()
        let listenerStats = FirebaseListenerManager.shared.listenerStats
        
        var report = "📊 SharedManagerStore Debug Report\n"
        report += "=====================================\n"
        report += "Active Managers: \(stats.totalActiveManagers)/9\n"
        report += "Estimated Memory: \(String(format: "%.1f", stats.memoryEstimate))MB\n"
        report += "Firebase Listeners: \(listenerStats.totalActive)\n"
        report += "Listener Memory: \(String(format: "%.1f", listenerStats.memoryUsage))MB\n\n"
        
        report += "Manager Status:\n"
        report += "  AuthenticationManager: \(stats.authManagerActive ? "✅" : "❌")\n"
        report += "  ProjectManager: \(stats.projectManagerActive ? "✅" : "❌")\n"
        report += "  EnhancedTaskManager: \(stats.taskManagerActive ? "✅" : "❌")\n"
        report += "  PhaseManager: \(stats.phaseManagerActive ? "✅" : "❌")\n"
        report += "  SubtaskManager: \(stats.subtaskManagerActive ? "✅" : "❌")\n"
        report += "  FamilyManager: \(stats.familyManagerActive ? "✅" : "❌")\n"
        report += "  TaskListManager: \(stats.taskListManagerActive ? "✅" : "❌")\n"
        report += "  AITaskGenerator: \(stats.aiGeneratorActive ? "✅" : "❌")\n"
        report += "  TaskImprovementEngine: \(stats.taskImprovementEngineActive ? "✅" : "❌")\n\n"
        
        report += "Performance Impact:\n"
        let totalMemory = stats.memoryEstimate + listenerStats.memoryUsage
        report += "  Total Memory Usage: \(String(format: "%.1f", totalMemory))MB\n"
        
        if totalMemory > 150 {
            report += "  ⚠️ Memory usage above target (150MB)\n"
        } else {
            report += "  ✅ Memory usage within target\n"
        }
        
        return report
    }
    
    /// デバッグ情報のログ出力
    func logDebugInfo() {
        let report = generateDebugReport()
        print(report)
        
        // OSLogにも記録
        os_log(.info, log: InstrumentsSetup.memoryLog, "%{public}@", report)
    }
}

// MARK: - SwiftUI Environment Integration

/// SharedManagerStore を Environment で利用するためのキー
struct SharedManagerStoreEnvironmentKey: EnvironmentKey {
    @MainActor static var defaultValue: SharedManagerStore { SharedManagerStore.shared }
}

extension EnvironmentValues {
    var sharedManagerStore: SharedManagerStore {
        get { self[SharedManagerStoreEnvironmentKey.self] }
        set { self[SharedManagerStoreEnvironmentKey.self] = newValue }
    }
}

// MARK: - Convenience View Extensions

extension View {
    /// SharedManagerStore を Environment に注入
    func withSharedManagers() -> some View {
        self.environmentObject(SharedManagerStore.shared)
    }
}