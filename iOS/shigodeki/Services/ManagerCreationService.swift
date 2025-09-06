//
//  ManagerCreationService.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import Foundation
import os

@MainActor
struct ManagerCreationService {
    
    // MARK: - Thread Safety
    
    private static var isCreatingManager: Set<String> = []
    
    /// 非同期Manager作成メソッド（デッドロック回避）
    static func createManagerSafely<T>(
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
    
    // MARK: - Preload Management
    
    /// Issue #50 Fix: Preload all essential managers to prevent tab-switching initialization conflicts
    static func preloadEssentialManagers(
        sharedStore: SharedManagerStore
    ) async {
        #if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🚀 SharedManagerStore: Starting centralized preload to prevent tab-switching issues")
        #endif
        
        // Preload essential managers in dependency order
        _ = await sharedStore.getAuthManager()
        _ = await sharedStore.getProjectManager()
        _ = await sharedStore.getFamilyManager()
        _ = await sharedStore.getTaskListManager()
        
        #if DEBUG
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
        print("✅ SharedManagerStore: Preload completed in \(Int(elapsedTime * 1000))ms")
        print("🎯 Issue #50: Tab switching should now be stable with preloaded managers")
        #endif
    }
}