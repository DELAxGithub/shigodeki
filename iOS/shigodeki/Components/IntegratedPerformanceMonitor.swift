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
    
    // ✅ Issue #82 Fix: 手動グレース期間を完全廃止
    // 適切なロード完了検知に基づく最適化制御に変更
    
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
        return PerformanceScoreCalculator.calculateOverallScore(
            listenerCount: listenerManager.listenerStats.totalActive,
            memoryUsage: sharedManagers.getCurrentMemoryUsage(),
            fps: performanceMonitor.metrics.currentFPS,
            managerCount: sharedManagers.getManagerStatistics().totalActiveManagers
        )
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
        
        // ✅ Issue #82 Fix: 初期化グレース期間を完全削除
        // 適切なロード状態に基づく判定に変更
        
        // SharedManagerStoreのプリロード完了チェック
        guard sharedManagers.isPreloaded else {
            #if DEBUG
            print("🔧 IntegratedPerformanceMonitor: Waiting for SharedManagerStore preload completion")
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
        // ✅ Issue #82 Fix: アプリライフサイクル監視を簡略化
        // UIApplicationの直接使用を避け、より軽量な実装に変更
        
        // メモリ警告の監視のみ維持（パフォーマンス監視に必要最小限）
        NotificationCenter.default.addObserver(
            forName: Notification.Name("UIApplicationDidReceiveMemoryWarningNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
    }
    
    private func setupPerformanceMonitorSubscription() {
        performanceMonitor.objectWillChange
            .sink { [weak self] (_: Void) in
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
    
    /// ✅ Issue #82 Fix: Grace period extension removed
    /// 適切な処理完了待ちに基づく制御に変更済み
    func extendOptimizationCooldown(seconds: TimeInterval) {
        #if DEBUG
        print("⏳ Extending performance optimization cooldown by \(seconds)s.")
        #endif
        self.lastOptimizationTime = Date().addingTimeInterval(seconds - optimizationCooldownInterval)
    }
    
    // MARK: - Reporting
    
    func generatePerformanceReport() -> String {
        return PerformanceReportGenerator.generateReport(
            metrics: currentMetrics,
            alerts: performanceAlerts
        )
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
