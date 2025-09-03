//
//  IntegratedPerformanceMonitor.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import SwiftUI
import Foundation
import Combine

/// 統合されたパフォーマンス監視システム
/// Phase 1-3のすべての最適化を監視・管理
@MainActor
class IntegratedPerformanceMonitor: ObservableObject {
    
    static let shared = IntegratedPerformanceMonitor()
    
    // MARK: - Published Properties
    
    @Published var currentMetrics = IntegratedPerformanceMetrics()
    @Published var isMonitoring = false
    @Published var performanceAlerts: [PerformanceAlert] = []
    
    // MARK: - Dependencies
    
    private let performanceMonitor = PerformanceMonitor.shared
    private let sharedManagers = SharedManagerStore.shared
    private let listenerManager = FirebaseListenerManager.shared
    
    // MARK: - Monitoring State
    
    private var monitoringTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastOptimizationTime: Date = Date.distantPast
    private let optimizationCooldownInterval: TimeInterval = 120.0 // 2分クールダウン（頻度を下げてループ抑制）
    private var initializationTime: Date = Date()
    private let initializationGracePeriod: TimeInterval = 45.0 // 45秒の初期化猶予期間（起動直後の最適化を抑止）
    private var lastGraceLogTime: Date = Date.distantPast // 🆕 Grace期間ログの頻度制御
    
    private init() {
        setupMonitoring()
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        #if DEBUG
        print("📊 IntegratedPerformanceMonitor: Starting comprehensive monitoring")
        #endif
        isMonitoring = true
        
        // 定期的なメトリクス更新を開始（2秒→10秒に変更）
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMetrics()
            }
        }
        
        // PerformanceMonitorの監視開始
        setupPerformanceMonitorSubscription()
        
        #if DEBUG
        InstrumentsSetup.shared.logMemoryUsage(context: "Monitoring Started")
        #endif
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        #if DEBUG
        print("⏹️ IntegratedPerformanceMonitor: Stopping monitoring")
        #endif
        isMonitoring = false
        
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        cancellables.removeAll()
        
        #if DEBUG
        InstrumentsSetup.shared.logMemoryUsage(context: "Monitoring Stopped")
        #endif
    }
    
    // MARK: - Metrics Update
    
    private func updateMetrics() async {
        let managerStats = sharedManagers.getManagerStatistics()
        let memoryUsage = sharedManagers.getCurrentMemoryUsage()
        let cacheMemoryUsage = await MainActor.run { managerStats.getCacheMemoryEstimate() }
        
        let newMetrics = IntegratedPerformanceMetrics(
            // Firebase関連
            activeFirebaseListeners: listenerManager.listenerStats.totalActive,
            firebaseMemoryUsage: listenerManager.listenerStats.memoryUsage,
            
            // Manager関連
            activeManagers: managerStats.totalActiveManagers,
            managerMemoryUsage: managerStats.memoryEstimate,
            
            // システム全体
            currentFPS: performanceMonitor.metrics.currentFPS,
            totalMemoryUsage: memoryUsage,
            cacheMemoryUsage: cacheMemoryUsage,
            
            // パフォーマンス評価
            overallScore: await calculateOverallScore(),
            timestamp: Date()
        )
        
        // アラートチェック
        checkPerformanceAlerts(newMetrics)
        
        // @Published更新をメインキューで非同期実行してPublishing警告を回避
        DispatchQueue.main.async { [weak self] in
            self?.currentMetrics = newMetrics
        }
        
        // 自動最適化トリガー
        triggerAutoOptimizationIfNeeded(newMetrics)
    }
    
    // MARK: - Performance Analysis
    
    private func calculateOverallScore() async -> Double {
        var score = 100.0
        
        // Firebase リスナー数による減点
        let listenerCount = Double(listenerManager.listenerStats.totalActive)
        score -= max(0, (listenerCount - 8.0) * 5.0) // 8個超過で1個あたり5点減点
        
        // メモリ使用量による減点
        let memoryUsage = sharedManagers.getCurrentMemoryUsage()
        score -= max(0, (memoryUsage - 150.0) * 0.5) // 150MB超過で1MBあたり0.5点減点
        
        // FPSによる減点
        let fps = performanceMonitor.metrics.currentFPS
        score -= max(0, (55.0 - fps) * 2.0) // 55fps未満で1fpsあたり2点減点
        
        // Manager数による減点
        let managerStats = sharedManagers.getManagerStatistics()
        let managerCount = Double(managerStats.totalActiveManagers)
        score -= max(0, (managerCount - 12.0) * 3.0) // 12個超過で1個あたり3点減点
        
        return max(0, min(100, score))
    }
    
    private func checkPerformanceAlerts(_ metrics: IntegratedPerformanceMetrics) {
        var newAlerts: [PerformanceAlert] = []
        
        // 高メモリ使用量アラート（閾値をより実用的に調整）
        if metrics.totalMemoryUsage > 250 {
            newAlerts.append(PerformanceAlert(
                type: .highMemoryUsage,
                message: "メモリ使用量が250MBを超過しています (\(String(format: "%.0f", metrics.totalMemoryUsage))MB)",
                severity: .critical
            ))
        } else if metrics.totalMemoryUsage > 180 {
            newAlerts.append(PerformanceAlert(
                type: .highMemoryUsage,
                message: "メモリ使用量が180MBを超過しています (\(String(format: "%.0f", metrics.totalMemoryUsage))MB)",
                severity: .warning
            ))
        }
        
        // 低FPSアラート
        if metrics.currentFPS < 30 {
            newAlerts.append(PerformanceAlert(
                type: .lowFrameRate,
                message: "FPSが30を下回っています (\(String(format: "%.1f", metrics.currentFPS))fps)",
                severity: .critical
            ))
        } else if metrics.currentFPS < 55 {
            newAlerts.append(PerformanceAlert(
                type: .lowFrameRate,
                message: "FPSが55を下回っています (\(String(format: "%.1f", metrics.currentFPS))fps)",
                severity: .warning
            ))
        }
        
        // Firebase リスナー過剰アラート
        if metrics.activeFirebaseListeners > 15 {
            newAlerts.append(PerformanceAlert(
                type: .excessiveListeners,
                message: "Firebaseリスナー数が15を超過しています (\(metrics.activeFirebaseListeners)個)",
                severity: .warning
            ))
        }
        
        // @Published更新をメインキューで非同期実行してPublishing警告を回避
        DispatchQueue.main.async { [weak self] in
            self?.performanceAlerts = newAlerts
        }
    }
    
    private func triggerAutoOptimizationIfNeeded(_ metrics: IntegratedPerformanceMetrics) {
        let now = Date()
        
        // 初期化猶予期間チェック（起動直後の最適化を防ぐ）
        guard now.timeIntervalSince(initializationTime) > initializationGracePeriod else {
            #if DEBUG
            // 🆕 Grace期間ログを3秒間隔に制限（26回→5回に削減）
            if now.timeIntervalSince(lastGraceLogTime) > 3.0 {
                let remainingGrace = initializationGracePeriod - now.timeIntervalSince(initializationTime)
                print("🕐 IntegratedPerformanceMonitor: Grace period active (\(String(format: "%.1f", remainingGrace))s remaining)")
                lastGraceLogTime = now
            }
            #endif
            return
        }
        
        // クールダウン期間チェック
        guard now.timeIntervalSince(lastOptimizationTime) > optimizationCooldownInterval else {
            return
        }
        
        // 自動最適化条件（さらに保守的に: 300MB→350MB）
        if metrics.totalMemoryUsage > 350 || metrics.overallScore < 20 {
            #if DEBUG
            print("🔧 IntegratedPerformanceMonitor: Triggering auto-optimization (cooldown: \(optimizationCooldownInterval)s)")
            #endif
            
            lastOptimizationTime = now
            Task {
                await performAutoOptimization()
            }
        }
    }
    
    private func performAutoOptimization() async {
        #if DEBUG
        print("⚡ IntegratedPerformanceMonitor: Performing auto-optimization")
        #endif
        
        // 統合キャッシュ管理の実行
        await sharedManagers.smartCacheManagement()
        
        // Firebase リスナーの最適化
        await MainActor.run {
            listenerManager.optimizeListeners()
        }
        
        // 低優先度のManagerを一時的に解放（さらに閾値を調整: 300MB→350MB）
        if currentMetrics.totalMemoryUsage > 350 {
            await sharedManagers.cleanupUnusedManagers()
        }
        
        // 🚨 CTO修正: パフォーマンス最適化処理での1秒遅延を撤廃
        // メモリクリーンアップは非同期で実行され、人工的遅延は不要
        
        // ⚠️ 最適化後のメトリクス更新を削除してループを防止
        // updateMetrics() // この行をコメントアウトしてカスケードループを防止
        
        #if DEBUG
        print("✅ IntegratedPerformanceMonitor: Auto-optimization completed")
        #endif
    }
    
    // MARK: - Setup Methods
    
    private func setupMonitoring() {
        // アプリのライフサイクル監視
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.stopMonitoring()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.startMonitoring()
            }
        }
    }
    
    private func setupPerformanceMonitorSubscription() {
        performanceMonitor.objectWillChange
            .sink { [weak self] _ in
                // PerformanceMonitorの変更を受信
                Task { @MainActor in
                    await self?.updateMetrics()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleMemoryWarning() {
        #if DEBUG
        print("⚠️ IntegratedPerformanceMonitor: Memory warning received")
        #endif
        
        // @Published更新をメインキューで非同期実行してPublishing警告を回避
        DispatchQueue.main.async { [weak self] in
            self?.performanceAlerts.append(PerformanceAlert(
                type: .systemMemoryWarning,
                message: "システムからメモリ警告を受信しました",
                severity: .critical
            ))
        }
        
        // 即座に最適化を実行（クールダウンを無視）
        lastOptimizationTime = Date.distantPast
        Task {
            await performAutoOptimization()
        }
    }
    
    /// Extends the initial grace period to prevent optimizations during heavy operations like template imports.
    func extendGracePeriod(seconds: TimeInterval) {
        #if DEBUG
        print("⏳ Extending performance monitor grace period by \(seconds)s.")
        #endif
        self.initializationTime = Date().addingTimeInterval(seconds - self.initializationGracePeriod)
    }
    
    // MARK: - Reporting
    
    func generatePerformanceReport() -> String {
        var report = ""
        report += "📊 統合パフォーマンスレポート\n"
        report += "==============================\n"
        report += "生成日時: \(DateFormatter.localizedString(from: currentMetrics.timestamp, dateStyle: .short, timeStyle: .medium))\n\n"
        
        report += "🎯 総合スコア: \(String(format: "%.1f", currentMetrics.overallScore))/100\n\n"
        
        report += "📊 主要メトリクス:\n"
        report += "  総メモリ使用量: \(String(format: "%.0f", currentMetrics.totalMemoryUsage))MB\n"
        report += "  現在のFPS: \(String(format: "%.1f", currentMetrics.currentFPS))\n"
        report += "  アクティブFirebaseリスナー: \(currentMetrics.activeFirebaseListeners)個\n"
        report += "  アクティブManager: \(currentMetrics.activeManagers)個\n"
        report += "  キャッシュメモリ: \(String(format: "%.1f", currentMetrics.cacheMemoryUsage))MB\n\n"
        
        report += "🎯 目標達成状況:\n"
        report += "  メモリ目標 (150MB): \(currentMetrics.totalMemoryUsage <= 150 ? "✅" : "❌") \(String(format: "%.0f", (currentMetrics.totalMemoryUsage / 150) * 100))%\n"
        report += "  FPS目標 (55fps): \(currentMetrics.currentFPS >= 55 ? "✅" : "❌") \(String(format: "%.0f", (currentMetrics.currentFPS / 55) * 100))%\n"
        report += "  リスナー目標 (8個): \(currentMetrics.activeFirebaseListeners <= 8 ? "✅" : "❌") \(currentMetrics.activeFirebaseListeners)/8\n"
        report += "  Manager目標 (12個): \(currentMetrics.activeManagers <= 12 ? "✅" : "❌") \(currentMetrics.activeManagers)/12\n\n"
        
        if !performanceAlerts.isEmpty {
            report += "⚠️ パフォーマンスアラート:\n"
            for alert in performanceAlerts {
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

// MARK: - Data Models

struct IntegratedPerformanceMetrics {
    let activeFirebaseListeners: Int
    let firebaseMemoryUsage: Double
    let activeManagers: Int
    let managerMemoryUsage: Double
    let currentFPS: Double
    let totalMemoryUsage: Double
    let cacheMemoryUsage: Double
    let overallScore: Double
    let timestamp: Date
    
    init() {
        self.activeFirebaseListeners = 0
        self.firebaseMemoryUsage = 0.0
        self.activeManagers = 0
        self.managerMemoryUsage = 0.0
        self.currentFPS = 60.0
        self.totalMemoryUsage = 0.0
        self.cacheMemoryUsage = 0.0
        self.overallScore = 100.0
        self.timestamp = Date()
    }
    
    init(activeFirebaseListeners: Int, firebaseMemoryUsage: Double, activeManagers: Int,
         managerMemoryUsage: Double, currentFPS: Double, totalMemoryUsage: Double,
         cacheMemoryUsage: Double, overallScore: Double, timestamp: Date) {
        self.activeFirebaseListeners = activeFirebaseListeners
        self.firebaseMemoryUsage = firebaseMemoryUsage
        self.activeManagers = activeManagers
        self.managerMemoryUsage = managerMemoryUsage
        self.currentFPS = currentFPS
        self.totalMemoryUsage = totalMemoryUsage
        self.cacheMemoryUsage = cacheMemoryUsage
        self.overallScore = overallScore
        self.timestamp = timestamp
    }
}

struct PerformanceAlert: Identifiable {
    let id = UUID()
    let type: AlertType
    let message: String
    let severity: Severity
    
    enum AlertType {
        case highMemoryUsage
        case lowFrameRate
        case excessiveListeners
        case systemMemoryWarning
    }
    
    enum Severity {
        case warning, critical
    }
}

// MARK: - SwiftUI Integration

extension View {
    /// 統合パフォーマンス監視を有効にする
    func withIntegratedPerformanceMonitoring() -> some View {
        self.environmentObject(IntegratedPerformanceMonitor.shared)
            .onAppear {
                IntegratedPerformanceMonitor.shared.startMonitoring()
            }
            .onDisappear {
                IntegratedPerformanceMonitor.shared.stopMonitoring()
            }
    }
}
