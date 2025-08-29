//
//  EnhancedTaskManagerMemoryTests.swift
//  shigodekiTests
//
//  Created by Claude on 2025-08-29.
//

import XCTest
import Combine
@testable import shigodeki

/// Comprehensive memory leak tests for EnhancedTaskManager
/// Prevents regression of the "retain count 2 deallocated" issue fixed on 2025-08-29
@MainActor
final class EnhancedTaskManagerMemoryTests: XCTestCase {
    
    var mockFirestore: MockFirestore!
    
    override func setUp() {
        super.setUp()
        mockFirestore = MockFirestore()
        
        // Track memory usage at test start
        trackMemoryUsage(maxMemoryMB: 25.0)
    }
    
    override func tearDown() {
        mockFirestore = nil
        forceGarbageCollection()
        super.tearDown()
    }
    
    // MARK: - Core Memory Leak Tests
    
    /// Test that EnhancedTaskManager properly deallocates without retain cycles
    func testEnhancedTaskManagerDeallocation() async {
        var manager: EnhancedTaskManager? = EnhancedTaskManager()
        weak var weakManager = manager
        
        // Track the manager for memory leak
        trackForMemoryLeak(manager!)
        
        // Simulate typical usage
        do {
            _ = try await manager?.createTask(
                title: "Test Task",
                description: "Test Description", 
                createdBy: "test-user",
                listId: "test-list",
                phaseId: "test-phase",
                projectId: "test-project"
            )
        } catch {
            // Expected to fail due to mock Firestore, but shouldn't leak memory
        }
        
        // Release strong reference
        manager = nil
        
        // Wait for deallocation
        await waitForMemoryStabilization()
        
        // Verify deallocation
        XCTAssertNil(weakManager, "EnhancedTaskManager should be deallocated")
    }
    
    /// Test that deinit properly cleans up listeners without Task memory leak
    /// This is the specific regression test for the retain count 2 issue
    func testDeinitListenerCleanupWithoutTask() async {
        var manager: EnhancedTaskManager? = EnhancedTaskManager()
        let expectation = expectation(description: "Deinit completes synchronously")
        
        // Mock some listeners
        let mockListener = MockListenerRegistration()
        manager?.listeners.append(mockListener)
        
        trackForMemoryLeak(mockListener)
        trackForMemoryLeak(manager!)
        
        // Track that deinit happens synchronously without Task memory leak
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            manager = nil
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
        await waitForMemoryStabilization()
        
        // Verify listener was removed and manager deallocated
        XCTAssertTrue(mockListener.wasRemoved, "Listener should have been removed in deinit")
    }
    
    /// Test ObservableObject publisher subscription cleanup
    func testObservableObjectMemoryLeak() async {
        testObservableObjectForMemoryLeak {
            EnhancedTaskManager()
        }
        
        await waitForMemoryStabilization()
    }
    
    // MARK: - Combine Publisher Memory Tests
    
    /// Test that Combine subscriptions don't create retain cycles
    func testCombineSubscriptionCleanup() async {
        let manager = EnhancedTaskManager()
        var cancellables: Set<AnyCancellable> = []
        
        trackForMemoryLeak(manager)
        
        // Subscribe to various published properties
        manager.$tasks
            .sink { _ in }
            .store(in: &cancellables)
        
        manager.$currentTask
            .sink { _ in }
            .store(in: &cancellables)
        
        manager.$isLoading
            .sink { _ in }
            .store(in: &cancellables)
        
        manager.$error
            .sink { _ in }
            .store(in: &cancellables)
        
        // Test publisher memory leak
        testPublisherForMemoryLeak(manager.objectWillChange)
        
        // Clean up subscriptions
        cancellables.removeAll()
        
        await waitForMemoryStabilization()
    }
    
    // MARK: - Async Operation Memory Tests
    
    /// Test async operations don't leak memory
    func testAsyncOperationsMemoryLeak() async {
        await testAsyncOperationForMemoryLeak { [weak self] in
            let manager = EnhancedTaskManager()
            self?.trackForMemoryLeak(manager)
            
            // This will fail but shouldn't leak memory
            do {
                return try await manager.createTask(
                    title: "Memory Test",
                    createdBy: "test",
                    listId: "test",
                    phaseId: "test",
                    projectId: "test"
                )
            } catch {
                return ShigodekiTask(
                    title: "Test",
                    createdBy: "test",
                    listId: "test",
                    phaseId: "test",
                    projectId: "test",
                    order: 0
                )
            }
        }
    }
    
    // MARK: - Firestore Listener Memory Tests
    
    /// Test Firestore listener cleanup prevents memory leaks
    func testFirestoreListenerMemoryLeak() {
        let manager = EnhancedTaskManager()
        trackForMemoryLeak(manager)
        
        // Mock a Firestore listener
        let mockListener = MockListenerRegistration()
        manager.listeners.append(mockListener)
        
        testFirestoreListenerCleanup {
            mockListener
        }
        
        // Verify cleanup
        manager.removeAllListeners()
        XCTAssertTrue(mockListener.wasRemoved, "Listener should be removed")
        XCTAssertTrue(manager.listeners.isEmpty, "Listeners array should be empty")
    }
    
    // MARK: - Stress Testing
    
    /// Test multiple EnhancedTaskManager instances don't accumulate memory
    func testMultipleInstancesMemoryAccumulation() async {
        let initialMemory = getCurrentMemoryUsage()
        let instanceCount = 10
        var managers: [EnhancedTaskManager] = []
        
        // Create multiple instances
        for i in 0..<instanceCount {
            let manager = EnhancedTaskManager()
            trackForMemoryLeak(manager)
            managers.append(manager)
            
            // Mock usage
            do {
                _ = try await manager.getTasks(
                    listId: "test-\(i)",
                    phaseId: "test-\(i)",
                    projectId: "test-\(i)"
                )
            } catch {
                // Expected to fail
            }
        }
        
        // Release all instances
        managers.removeAll()
        
        await waitForMemoryStabilization(timeout: 2.0)
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        assertMemoryWithinBounds(actual: memoryIncrease, maximum: 10.0)
    }
    
    // MARK: - Regression Tests for Fixed Issues
    
    /// Regression test for the specific deinit Task memory leak fix
    /// This test ensures the fix for the deinit { Task { @MainActor in } } issue
    func testDeinitTaskMemoryLeakRegression() async {
        // This test ensures the fix for the deinit { Task { @MainActor in } } issue
        var managers: [EnhancedTaskManager] = []
        
        // Create managers that would have leaked with the old deinit pattern
        for _ in 0..<5 {
            let manager = EnhancedTaskManager()
            
            // Add mock listeners that need cleanup
            manager.listeners.append(MockListenerRegistration())
            
            trackForMemoryLeak(manager)
            managers.append(manager)
        }
        
        // Clear all managers (triggers deinit)
        managers.removeAll()
        
        // With the fix, these should all deallocate properly
        await waitForMemoryStabilization(timeout: 1.0)
        
        // Memory should not have accumulated significantly
        let currentMemory = getCurrentMemoryUsage()
        assertMemoryWithinBounds(actual: currentMemory, maximum: 100.0)
    }
    
    /// Test SubtaskManager creation within EnhancedTaskManager doesn't leak
    func testSubtaskManagerCreationMemoryLeak() async {
        let manager = EnhancedTaskManager()
        trackForMemoryLeak(manager)
        
        // This simulates the deleteTask method which creates a SubtaskManager
        do {
            _ = try await manager.deleteTask(
                id: "test-task",
                listId: "test-list", 
                phaseId: "test-phase",
                projectId: "test-project"
            )
        } catch {
            // Expected to fail with mock Firestore
        }
        
        await waitForMemoryStabilization()
        
        // Verify no memory accumulation from SubtaskManager creation
        let currentMemory = getCurrentMemoryUsage()
        assertMemoryWithinBounds(actual: currentMemory, maximum: 50.0)
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Double(info.resident_size) / 1024.0 / 1024.0 : 0.0
    }
}

// MARK: - Test Extensions

extension EnhancedTaskManager {
    /// Test helper to access internal listeners array
    var listenersCount: Int {
        return listeners.count
    }
}