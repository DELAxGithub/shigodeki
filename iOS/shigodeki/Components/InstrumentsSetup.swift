//
//  InstrumentsSetup.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import Foundation
import UIKit
import os.log

// MARK: - Performance Measurement Setup

/// Instrumentsによるパフォーマンス分析のためのセットアップクラス
class InstrumentsSetup {
    static let shared = InstrumentsSetup()
    
    // MARK: - OSLog Categories for Instruments
    
    /// メモリ使用量の測定用ログ
    static let memoryLog = OSLog(subsystem: "com.company.shigodeki", category: "Memory")
    
    /// Firebase接続とリスナーの測定用ログ
    static let firebaseLog = OSLog(subsystem: "com.company.shigodeki", category: "Firebase")
    
    /// UI応答性の測定用ログ
    static let uiLog = OSLog(subsystem: "com.company.shigodeki", category: "UI")
    
    /// アプリ起動時間の測定用ログ
    static let launchLog = OSLog(subsystem: "com.company.shigodeki", category: "Launch")
    
    /// ネットワーク通信の測定用ログ
    static let networkLog = OSLog(subsystem: "com.company.shigodeki", category: "Network")
    
    // MARK: - Performance Signposts
    
    /// アプリ起動のsignpost
    static let appLaunchSignpost = OSSignpostID(log: launchLog)
    
    /// Firebase接続のsignpost
    static let firebaseConnectionSignpost = OSSignpostID(log: firebaseLog)
    
    /// データローディングのsignpost
    static let dataLoadingSignpost = OSSignpostID(log: networkLog)
    
    // MARK: - Measurement Helper Methods
    
    /// アプリ起動時間の測定開始
    func startAppLaunchMeasurement() {
        os_signpost(.begin, log: Self.launchLog, name: "App Launch", signpostID: Self.appLaunchSignpost, "Starting app launch")
        os_log(.info, log: Self.launchLog, "🚀 App launch started")
    }
    
    /// アプリ起動時間の測定終了
    func endAppLaunchMeasurement() {
        os_signpost(.end, log: Self.launchLog, name: "App Launch", signpostID: Self.appLaunchSignpost, "App launch completed")
        os_log(.info, log: Self.launchLog, "✅ App launch completed")
    }
    
    /// Firebase接続時間の測定開始
    func startFirebaseConnectionMeasurement(operation: String) {
        let signpostID = OSSignpostID(log: Self.firebaseLog)
        os_signpost(.begin, log: Self.firebaseLog, name: "Firebase Operation", signpostID: signpostID, "Starting: %{public}@", operation)
        os_log(.info, log: Self.firebaseLog, "🔥 Firebase operation started: %{public}@", operation)
    }
    
    /// Firebase接続時間の測定終了
    func endFirebaseConnectionMeasurement(operation: String, success: Bool) {
        let signpostID = OSSignpostID(log: Self.firebaseLog)
        let status = success ? "Success" : "Failed"
        os_signpost(.end, log: Self.firebaseLog, name: "Firebase Operation", signpostID: signpostID, "%{public}@: %{public}@", operation, status)
        os_log(.info, log: Self.firebaseLog, "🔥 Firebase operation %{public}@: %{public}@", status.lowercased(), operation)
    }
    
    /// メモリ使用量の記録
    func logMemoryUsage(context: String) {
        let memoryInfo = getMemoryUsage()
        os_log(.info, log: Self.memoryLog, "💾 Memory usage [%{public}@]: %.2f MB (Peak: %.2f MB)", 
               context, memoryInfo.current, memoryInfo.peak)
    }
    
    /// UI操作の応答時間測定開始
    func startUIResponseMeasurement(action: String) {
        let signpostID = OSSignpostID(log: Self.uiLog)
        os_signpost(.begin, log: Self.uiLog, name: "UI Response", signpostID: signpostID, "UI Action: %{public}@", action)
    }
    
    /// UI操作の応答時間測定終了
    func endUIResponseMeasurement(action: String) {
        let signpostID = OSSignpostID(log: Self.uiLog)
        os_signpost(.end, log: Self.uiLog, name: "UI Response", signpostID: signpostID, "UI Action completed: %{public}@", action)
    }
    
    /// データローディング時間の測定開始
    func startDataLoadingMeasurement(dataType: String, count: Int) {
        os_signpost(.begin, log: Self.networkLog, name: "Data Loading", signpostID: Self.dataLoadingSignpost, 
                   "Loading %{public}@ (count: %d)", dataType, count)
    }
    
    /// データローディング時間の測定終了
    func endDataLoadingMeasurement(dataType: String, count: Int, success: Bool) {
        let status = success ? "Success" : "Failed"
        os_signpost(.end, log: Self.networkLog, name: "Data Loading", signpostID: Self.dataLoadingSignpost,
                   "%{public}@ loading %{public}@ (count: %d)", dataType, status.lowercased(), count)
    }
    
    // MARK: - Memory Information
    
    private func getMemoryUsage() -> (current: Double, peak: Double) {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            return (current: 0.0, peak: 0.0)
        }
        
        let currentMB = Double(taskInfo.resident_size) / 1024.0 / 1024.0
        let peakMB = Double(taskInfo.resident_size_max) / 1024.0 / 1024.0
        
        return (current: currentMB, peak: peakMB)
    }
    
    // MARK: - Test Scenarios Setup
    
    /// パフォーマンステストシナリオの定義
    enum TestScenario {
        case appLaunch
        case projectListLoading
        case taskCreation
        case firebaseSync
        case memoryStress
        case uiInteraction
        
        var description: String {
            switch self {
            case .appLaunch:
                return "App Launch"
            case .projectListLoading:
                return "Project List Loading"
            case .taskCreation:
                return "Task Creation"
            case .firebaseSync:
                return "Firebase Sync"
            case .memoryStress:
                return "Memory Stress Test"
            case .uiInteraction:
                return "UI Interaction"
            }
        }
    }
    
    /// 測定シナリオの実行
    func runMeasurementScenario(_ scenario: TestScenario, action: @escaping () async -> Void) async {
        let scenarioName = scenario.description
        
        // シナリオ開始の記録
        os_log(.info, log: Self.launchLog, "📊 Starting test scenario: %{public}@", scenarioName)
        logMemoryUsage(context: "Before \(scenarioName)")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // アクション実行
        await action()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // シナリオ終了の記録
        logMemoryUsage(context: "After \(scenarioName)")
        os_log(.info, log: Self.launchLog, "✅ Completed test scenario: %{public}@ in %.3f seconds", scenarioName, duration)
    }
}

// MARK: - Extension for easy logging

extension OSLog {
    /// Shigodekiアプリ専用のログカテゴリー作成
    static func shigodekiLog(category: String) -> OSLog {
        return OSLog(subsystem: "com.company.shigodeki", category: category)
    }
}

// MARK: - Performance Test Helper

/// Instrumentsでのパフォーマンステスト用ヘルパークラス
class PerformanceTestHelper {
    
    /// Firebase操作のパフォーマンス測定
    static func measureFirebaseOperation<T>(
        operation: String,
        action: @escaping () async throws -> T
    ) async rethrows -> T {
        InstrumentsSetup.shared.startFirebaseConnectionMeasurement(operation: operation)
        
        do {
            let result = try await action()
            InstrumentsSetup.shared.endFirebaseConnectionMeasurement(operation: operation, success: true)
            return result
        } catch {
            InstrumentsSetup.shared.endFirebaseConnectionMeasurement(operation: operation, success: false)
            throw error
        }
    }
    
    /// UI操作のパフォーマンス測定
    static func measureUIAction<T>(
        action: String,
        execution: @escaping () -> T
    ) -> T {
        InstrumentsSetup.shared.startUIResponseMeasurement(action: action)
        let result = execution()
        InstrumentsSetup.shared.endUIResponseMeasurement(action: action)
        return result
    }
    
    /// データローディングのパフォーマンス測定
    static func measureDataLoading<T>(
        dataType: String,
        expectedCount: Int,
        action: @escaping () async throws -> T
    ) async rethrows -> T {
        InstrumentsSetup.shared.startDataLoadingMeasurement(dataType: dataType, count: expectedCount)
        
        do {
            let result = try await action()
            InstrumentsSetup.shared.endDataLoadingMeasurement(dataType: dataType, count: expectedCount, success: true)
            return result
        } catch {
            InstrumentsSetup.shared.endDataLoadingMeasurement(dataType: dataType, count: expectedCount, success: false)
            throw error
        }
    }
}