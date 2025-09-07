//
//  PerformanceReportGenerator.swift
//  shigodeki
//
//  Extracted from IntegratedPerformanceMonitor.swift on 2025-09-07.
//

import Foundation

// MARK: - Performance Report Generator

struct PerformanceReportGenerator {
    
    /// 統合パフォーマンスレポートを生成
    /// - Parameters:
    ///   - metrics: 現在のパフォーマンスメトリクス
    ///   - alerts: アクティブなパフォーマンスアラート
    /// - Returns: フォーマットされたレポート文字列
    static func generateReport(
        metrics: IntegratedPerformanceMetrics,
        alerts: [PerformanceAlert]
    ) -> String {
        var report = ""
        report += "📊 統合パフォーマンスレポート\n"
        report += "==============================\n"
        report += "生成日時: \(DateFormatter.localizedString(from: metrics.timestamp, dateStyle: .short, timeStyle: .medium))\n\n"
        
        report += "🎯 総合スコア: \(String(format: "%.1f", metrics.overallScore))/100\n\n"
        
        report += "📊 主要メトリクス:\n"
        report += "  総メモリ使用量: \(String(format: "%.0f", metrics.totalMemoryUsage))MB\n"
        report += "  現在のFPS: \(String(format: "%.1f", metrics.currentFPS))\n"
        report += "  アクティブFirebaseリスナー: \(metrics.activeFirebaseListeners)個\n"
        report += "  アクティブManager: \(metrics.activeManagers)個\n"
        report += "  キャッシュメモリ: \(String(format: "%.1f", metrics.cacheMemoryUsage))MB\n\n"
        
        report += "🎯 目標達成状況:\n"
        report += "  メモリ目標 (150MB): \(metrics.totalMemoryUsage <= 150 ? "✅" : "❌") \(String(format: "%.0f", (metrics.totalMemoryUsage / 150) * 100))%\n"
        report += "  FPS目標 (55fps): \(metrics.currentFPS >= 55 ? "✅" : "❌") \(String(format: "%.0f", (metrics.currentFPS / 55) * 100))%\n"
        report += "  リスナー目標 (8個): \(metrics.activeFirebaseListeners <= 8 ? "✅" : "❌") \(metrics.activeFirebaseListeners)/8\n"
        report += "  Manager目標 (12個): \(metrics.activeManagers <= 12 ? "✅" : "❌") \(metrics.activeManagers)/12\n\n"
        
        if !alerts.isEmpty {
            report += "⚠️ パフォーマンスアラート:\n"
            for alert in alerts {
                let emoji = alert.severity == .critical ? "🔴" : "🟡"
                report += "  \(emoji) \(alert.message)\n"
            }
            report += "\n"
        } else {
            report += "✅ パフォーマンスアラートなし\n\n"
        }
        
        report += "📈 Phase別改善状況:\n"
        report += "  Phase 1 (分析): ✅ 完了\n"
        report += "  Phase 2 (アーキテクチャ最適化): ✅ 完了\n"
        report += "  Phase 3 (機能統合): 🔄 実行中\n"
        
        return report
    }
}