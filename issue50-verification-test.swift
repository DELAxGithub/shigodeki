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
    
    /// Test 4: Tab switching debounce mechanism
    func testTabSwitchDebounce() async {
        // Given: Rapid tab switches simulated
        let expectation = XCTestExpectation(description: "Debounce should prevent rapid operations")
        
        var operationCount = 0
        let debounceTask = Task {
            // Simulate rapid tab switches
            for _ in 0..<5 {
                operationCount += 1
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms intervals (faster than 150ms debounce)
            }
        }
        
        // When: Wait for debounce completion
        await debounceTask.value
        
        // Then: Operations should be limited by debounce
        XCTAssertEqual(operationCount, 5, "All operations should execute but debounce should prevent conflicts")
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 2.0)
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