//
//  ManagerCreationService.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import Foundation
import os

actor ManagerFactory {
    private var creationTasks: [String: Task<Any, Never>] = [:]
    
    func getOrCreate<T>(
        key: String,
        create: @escaping @Sendable () async -> T
    ) async -> T {
        // If there's already a creation task for this key, await its result
        if let existingTask = creationTasks[key] {
            return await existingTask.value as! T
        }
        
        // Create new task and store it
        let task = Task<Any, Never> {
            let result = await create()
            return result
        }
        
        creationTasks[key] = task
        
        let result = await task.value as! T
        
        // Clean up completed task
        creationTasks.removeValue(forKey: key)
        
        return result
    }
}

@MainActor
struct ManagerCreationService {
    
    // MARK: - Thread Safety
    
    private static let factory = ManagerFactory()
    
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
        
        // Use actor-based factory to avoid busy-waiting
        return await factory.getOrCreate(key: key) {
            // Managerを作成
            let newManager = await MainActor.run {
                let manager = create()
                assign(manager)
                return manager
            }
            
            #if DEBUG
            await MainActor.run {
                InstrumentsSetup.shared.logMemoryUsage(context: logContext)
                print("🏭 SharedManagerStore: Created \(key)")
            }
            #endif
            
            return newManager
        }
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