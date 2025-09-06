//
//  ManagerStatisticsService.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import Foundation
import os

// MARK: - Manager Statistics Data Model

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
    
    @MainActor var memoryEstimate: Double {
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
        
        // 統合キャッシュシステムの推定使用量を追加
        estimate += getCacheMemoryEstimate()
        
        return estimate
    }
    
    // キャッシュメモリ使用量の推定
    @MainActor
    func getCacheMemoryEstimate() -> Double {
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

// MARK: - Statistics Service

struct ManagerStatisticsService {
    
    // MARK: - Statistics Generation
    
    static func generateStatistics(
        authManager: AuthenticationManager?,
        projectManager: ProjectManager?,
        taskManager: EnhancedTaskManager?,
        phaseManager: PhaseManager?,
        subtaskManager: SubtaskManager?,
        familyManager: FamilyManager?,
        taskListManager: TaskListManager?,
        aiGenerator: AITaskGenerator?,
        taskImprovementEngine: TaskImprovementEngine?
    ) -> ManagerStatistics {
        return ManagerStatistics(
            authManagerActive: authManager != nil,
            projectManagerActive: projectManager != nil,
            taskManagerActive: taskManager != nil,
            phaseManagerActive: phaseManager != nil,
            subtaskManagerActive: subtaskManager != nil,
            familyManagerActive: familyManager != nil,
            taskListManagerActive: taskListManager != nil,
            aiGeneratorActive: aiGenerator != nil,
            taskImprovementEngineActive: taskImprovementEngine != nil
        )
    }
    
    // MARK: - Debug Report Generation
    
    @MainActor static func generateDebugReport(stats: ManagerStatistics) -> String {
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
    
    // MARK: - Debug Logging
    
    @MainActor static func logDebugInfo(stats: ManagerStatistics) {
        let report = generateDebugReport(stats: stats)
        print(report)
        
        // OSLogにも記録
        os_log(.info, log: InstrumentsSetup.memoryLog, "%{public}@", report)
    }
}