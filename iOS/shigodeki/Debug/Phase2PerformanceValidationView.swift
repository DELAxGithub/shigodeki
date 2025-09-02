#if DEBUG
//
//  Phase2PerformanceValidationView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import SwiftUI
import Foundation
import os

/// Phase 2実装後のパフォーマンス検証用デバッグView
struct Phase2PerformanceValidationView: View {
    
    @EnvironmentObject var sharedManagers: SharedManagerStore
    
    @State private var performanceReport = ""
    @State private var showReport = false
    @State private var isRunningTests = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                HeaderView()
                
                MetricsView()
                
                ButtonsView()
                
                if showReport {
                    ScrollView {
                        Text(performanceReport)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Phase 2 検証")
        }
    }
    
    // MARK: - Sub Views
    
    private func HeaderView() -> some View {
        VStack {
            Text("🚀 Phase 2 パフォーマンス改善検証")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Firebase リスナー統合 + @StateObject 最適化")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private func MetricsView() -> some View {
        VStack(spacing: 16) {
            
            MetricCard(
                title: "Firebase リスナー数",
                before: "20個",
                after: "\(FirebaseListenerManager.shared.listenerStats.totalActive)個",
                improvement: calculateListenerImprovement()
            )
            
            MetricCard(
                title: "@StateObject インスタンス",
                before: "36個",
                after: "\(sharedManagers.getManagerStatistics().totalActiveManagers)個",
                improvement: calculateStateObjectImprovement()
            )
            
            MetricCard(
                title: "推定メモリ使用量",
                before: "250-300MB",
                after: String(format: "%.0fMB", getTotalMemoryEstimate()),
                improvement: calculateMemoryImprovement()
            )
        }
    }
    
    private func ButtonsView() -> some View {
        VStack(spacing: 12) {
            
            Button(action: {
                generatePerformanceReport()
            }) {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                    Text("詳細レポート生成")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isRunningTests)
            
            Button(action: {
                runPerformanceTests()
            }) {
                HStack {
                    if isRunningTests {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "stopwatch")
                    }
                    Text("パフォーマンステスト実行")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isRunningTests)
            
            Button(action: {
                exportResults()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("結果をエクスポート")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateListenerImprovement() -> String {
        let current = FirebaseListenerManager.shared.listenerStats.totalActive
        let before = 20
        let improvement = Double(before - current) / Double(before) * 100
        return String(format: "%.0f%%改善", improvement)
    }
    
    private func calculateStateObjectImprovement() -> String {
        let current = sharedManagers.getManagerStatistics().totalActiveManagers
        let before = 36
        let improvement = Double(before - current) / Double(before) * 100
        return String(format: "%.0f%%改善", improvement)
    }
    
    private func getTotalMemoryEstimate() -> Double {
        let managerMemory = sharedManagers.getManagerStatistics().memoryEstimate
        let listenerMemory = FirebaseListenerManager.shared.listenerStats.memoryUsage
        return managerMemory + listenerMemory
    }
    
    private func calculateMemoryImprovement() -> String {
        let current = getTotalMemoryEstimate()
        let before = 275.0 // 平均推定値
        let improvement = (before - current) / before * 100
        return String(format: "%.0f%%改善", improvement)
    }
    
    private func generatePerformanceReport() {
        let managerStats = sharedManagers.getManagerStatistics()
        let listenerStats = FirebaseListenerManager.shared.listenerStats
        
        var report = ""
        report += "📊 Phase 2 実装結果レポート\n"
        report += "=====================================\n"
        report += "生成日時: \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium))\n\n"
        
        // Before/After 比較
        report += "🎯 主要改善項目:\n"
        report += "  Firebase リスナー: 20個 → \(listenerStats.totalActive)個 (\(calculateListenerImprovement()))\n"
        report += "  @StateObject: 36個 → \(managerStats.totalActiveManagers)個 (\(calculateStateObjectImprovement()))\n"
        report += "  推定メモリ: 275MB → \(String(format: "%.0f", getTotalMemoryEstimate()))MB (\(calculateMemoryImprovement()))\n\n"
        
        // Manager詳細
        report += "🏭 Manager使用状況:\n"
        report += "  AuthenticationManager: \(managerStats.authManagerActive ? "✅" : "❌")\n"
        report += "  ProjectManager: \(managerStats.projectManagerActive ? "✅" : "❌")\n"
        report += "  EnhancedTaskManager: \(managerStats.taskManagerActive ? "✅" : "❌")\n"
        report += "  PhaseManager: \(managerStats.phaseManagerActive ? "✅" : "❌")\n"
        report += "  SubtaskManager: \(managerStats.subtaskManagerActive ? "✅" : "❌")\n"
        report += "  FamilyManager: \(managerStats.familyManagerActive ? "✅" : "❌")\n"
        report += "  TaskListManager: \(managerStats.taskListManagerActive ? "✅" : "❌")\n"
        report += "  AITaskGenerator: \(managerStats.aiGeneratorActive ? "✅" : "❌")\n\n"
        
        // Firebase リスナー詳細
        report += "🔥 Firebase リスナー詳細:\n"
        for (type, count) in listenerStats.byType {
            report += "  \(type): \(count)個\n"
        }
        report += "  総メモリ使用量: \(String(format: "%.1f", listenerStats.memoryUsage))MB\n\n"
        
        // 目標達成状況
        report += "🎯 目標達成状況:\n"
        let listenerGoal = Double(listenerStats.totalActive) / 8.0 // 目標8個
        let memoryGoal = getTotalMemoryEstimate() / 150.0 // 目標150MB
        let stateObjectGoal = Double(managerStats.totalActiveManagers) / 12.0 // 目標12個
        
        report += "  リスナー削減目標: \(listenerGoal <= 1.0 ? "✅ 達成" : "🟡 \(String(format: "%.0f", listenerGoal * 100))%")\n"
        report += "  メモリ削減目標: \(memoryGoal <= 1.0 ? "✅ 達成" : "🟡 \(String(format: "%.0f", memoryGoal * 100))%")\n"
        report += "  @StateObject削減目標: \(stateObjectGoal <= 1.0 ? "✅ 達成" : "🟡 \(String(format: "%.0f", stateObjectGoal * 100))%")\n\n"
        
        // 推奨事項
        report += "📋 次のステップ:\n"
        if listenerGoal > 1.0 {
            report += "  • さらなるリスナー最適化が必要\n"
        }
        if memoryGoal > 1.0 {
            report += "  • PerformanceOptimization.swiftの活用を検討\n"
        }
        if stateObjectGoal > 1.0 {
            report += "  • 追加のView統合が必要\n"
        }
        
        if listenerGoal <= 1.0 && memoryGoal <= 1.0 && stateObjectGoal <= 1.0 {
            report += "  🎉 すべての目標を達成！Phase 3へ進む準備完了\n"
        }
        
        performanceReport = report
        showReport = true
        
        // OSLogにも記録
        os_log(.info, log: InstrumentsSetup.launchLog, "%{public}@", report)
    }
    
    private func runPerformanceTests() {
        isRunningTests = true
        
        Task {
            await InstrumentsSetup.shared.runMeasurementScenario(.memoryStress) {
                // メモリストレステストの実行
                for i in 0..<10 {
                    let _ = await sharedManagers.getProjectManager()
                    let _ = await sharedManagers.getTaskManager()
                    let _ = await sharedManagers.getPhaseManager()
                    
                    await Task.sleep(UInt64(100_000_000)) // 0.1秒待機
                    
                    if i % 3 == 0 {
                        await sharedManagers.cleanupUnusedManagers()
                    }
                }
            }
            
            await MainActor.run {
                isRunningTests = false
                generatePerformanceReport()
            }
        }
    }
    
    private func exportResults() {
        let report = performanceReport.isEmpty ? sharedManagers.generateDebugReport() : performanceReport
        
        // クリップボードにコピー
        UIPasteboard.general.string = report
        
        // 実際のアプリではファイル出力を実装
        print("📤 Phase 2 結果をクリップボードにコピーしました")
    }
}

// MARK: - Metric Card Component

struct MetricCard: View {
    let title: String
    let before: String
    let after: String
    let improvement: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack {
                    Text("Before")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(before)
                        .font(.title3)
                        .foregroundColor(.red)
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.blue)
                
                VStack {
                    Text("After")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(after)
                        .font(.title3)
                        .foregroundColor(.green)
                }
                
                VStack {
                    Text("改善")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(improvement)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview
struct Phase2PerformanceValidationView_Previews: PreviewProvider {
    static var previews: some View {
        Phase2PerformanceValidationView()
            .environmentObject(SharedManagerStore.shared)
    }
}
#endif