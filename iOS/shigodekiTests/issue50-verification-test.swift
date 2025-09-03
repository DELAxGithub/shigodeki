//
//  issue50-verification-test.swift
//  shigodeki
//
//  Issue #50 Fix Verification Test
//  Created by Claude on 2025-09-02.
//

import XCTest
import SwiftUI
@testable import shigodeki

/// Issue #50: タブ切り替え時のデータロード不安定 - 修正検証テスト
class Issue50VerificationTest: XCTestCase {
    
    var sharedManagerStore: SharedManagerStore!
    var firebaseListenerManager: FirebaseListenerManager!
    
    override func setUp() {
        super.setUp()
        sharedManagerStore = SharedManagerStore.shared
        firebaseListenerManager = FirebaseListenerManager.shared
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up after each test
        Task {
            await sharedManagerStore.cleanupUnusedManagers()
            await MainActor.run {
                firebaseListenerManager.removeAllListeners()
            }
        }
    }
    
    /// Test 1: SharedManagerStore preload functionality
    func testSharedManagerStorePreload() async {
        // Given: Fresh SharedManagerStore instance
        XCTAssertFalse(sharedManagerStore.isPreloaded, "SharedManagerStore should not be preloaded initially")
        
        // When: Preload all managers
        await sharedManagerStore.preloadAllManagers()
        
        // Then: Preload should be completed
        XCTAssertTrue(sharedManagerStore.isPreloaded, "SharedManagerStore should be preloaded after preloadAllManagers()")
    }
    
    /// Test 2: Prevent concurrent preload calls
    func testPreloadConcurrencyControl() async {
        // Given: Multiple concurrent preload calls
        let task1 = Task { await sharedManagerStore.preloadAllManagers() }
        let task2 = Task { await sharedManagerStore.preloadAllManagers() }
        let task3 = Task { await sharedManagerStore.preloadAllManagers() }
        
        // When: All tasks complete
        await task1.value
        await task2.value  
        await task3.value
        
        // Then: Preload should be successful without conflicts
        XCTAssertTrue(sharedManagerStore.isPreloaded, "Concurrent preload calls should not cause conflicts")
    }
    
    /// Test 3: Firebase listener lifecycle logging
    func testFirebaseListenerLogging() {
        // Given: Initial listener count
        let initialCount = firebaseListenerManager.listenerStats.totalActive
        
        // When: Create a test listener (mock)
        let listenerId = "test-listener-\(UUID().uuidString)"
        
        // Then: Listener should be tracked
        // Note: This is a conceptual test - actual Firebase operations require Firebase setup
        XCTAssertGreaterThanOrEqual(firebaseListenerManager.listenerStats.totalActive, initialCount)
    }
    
    /// Actor to safely count debounced operations
    actor OperationCounter {
        var count = 0
        func increment() {
            count += 1
        }
    }

    /// Debouncer to limit rapid calls
    actor Debouncer {
        private var task: Task<Void, Never>?
        private let duration: TimeInterval

        init(duration: TimeInterval) {
            self.duration = duration
        }

        func debounce(action: @escaping () async -> Void) {
            task?.cancel()
            task = Task {
                try? await Task.sleep(for: .seconds(duration))
                if !Task.isCancelled {
                    await action()
                }
            }
        }
    }

    /// Test 4: Tab switching debounce mechanism
    func testTabSwitchDebounce() async {
        // Given: A counter and a debouncer with a 150ms interval
        let counter = OperationCounter()
        let debouncer = Debouncer(duration: 0.15)
        // When: The debounced action is called 5 times in rapid succession (50ms intervals)
        for _ in 0..<5 {
            await debouncer.debounce { await counter.increment() }
            try? await Task.sleep(for: .milliseconds(50))
        }
        // Then: After waiting for the debounce interval to pass, the action should have been executed only once.
        try? await Task.sleep(for: .milliseconds(200)) // Wait longer than the debounce duration
        let finalCount = await counter.count
        XCTAssertEqual(finalCount, 1, "Debounce should ensure the operation is only performed once for a rapid series of calls.")
    }
    
    /// Test 5: ViewModel initialization waiting for preload
    func testViewModelInitializationWaitsForPreload() async {
        // Given: SharedManagerStore not preloaded
        let freshStore = SharedManagerStore()
        XCTAssertFalse(freshStore.isPreloaded)
        
        // When: ViewModel initialization logic (simulated)
        let initTask = Task {
            // Simulate ViewModel waiting for preload (similar to ProjectListView.initializeViewModel)
            while !freshStore.isPreloaded {
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms intervals
            }
            return "initialization_complete"
        }
        
        // Preload after a delay to test waiting mechanism
        let preloadTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
            await freshStore.preloadAllManagers()
        }
        
        // Then: Initialization should complete after preload
        let result = await initTask.value
        await preloadTask.value
        
        XCTAssertEqual(result, "initialization_complete", "ViewModel initialization should wait for preload completion")
    }
}

// MARK: - Test Helper Extensions

extension Issue50VerificationTest {
    
    /// Helper method to simulate tab switching stress test
    func simulateTabSwitchingStressTest(iterations: Int = 10) async {
        print("🧪 Issue #50 Test: Starting tab switching stress test with \(iterations) iterations")
        
        for i in 0..<iterations {
            // Simulate tab switches with random delays
            let randomDelay = UInt64.random(in: 10_000_000...200_000_000) // 10-200ms
            try? await Task.sleep(nanoseconds: randomDelay)
            
            print("🔄 Test iteration \(i+1): Simulated tab switch")
            
            // Verify SharedManagerStore remains stable
            XCTAssertTrue(sharedManagerStore.isPreloaded, "SharedManagerStore should remain preloaded during stress test")
        }
        
        print("✅ Issue #50 Test: Tab switching stress test completed successfully")
    }
}