//
//  SubtaskManagerMemoryTests.swift
//  shigodekiTests
//
//  Created by Claude on 2025-08-29.
//

import XCTest
import Combine
@testable import shigodeki

/// Comprehensive memory leak tests for SubtaskManager
@MainActor
final class SubtaskManagerMemoryTests: XCTestCase {
    
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
    
    /// Test that SubtaskManager properly deallocates without retain cycles
    func testSubtaskManagerDeallocation() async {
        var manager: SubtaskManager? = SubtaskManager()
        weak var weakManager = manager
        
        // Track the manager for memory leak
        trackForMemoryLeak(manager!)
        
        // Simulate typical usage
        do {
            _ = try await manager?.createSubtask(
                title: "Test Subtask",
                description: "Test Description",
                createdBy: "test-user",
                taskId: "test-task",
                listId: "test-list",
                phaseId: "test-phase",
                projectId: "test-project"
            )
        } catch {
            // Expected to fail due to mock Firestore
        }
        
        // Release strong reference
        manager = nil
        
        // Wait for deallocation
        await waitForMemoryStabilization()
        
        // Verify deallocation
        XCTAssertNil(weakManager, "SubtaskManager should be deallocated")
    }
    
    /// Test that deinit properly cleans up listeners without Task memory leak
    func testDeinitListenerCleanup() async {
        var manager: SubtaskManager? = SubtaskManager()
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
            SubtaskManager()
        }
        
        await waitForMemoryStabilization()
    }
    
    // MARK: - Combine Publisher Memory Tests
    
    /// Test that Combine subscriptions don't create retain cycles
    func testCombineSubscriptionCleanup() async {
        let manager = SubtaskManager()
        var cancellables: Set<AnyCancellable> = []
        
        trackForMemoryLeak(manager)
        
        // Subscribe to various published properties
        manager.$subtasks
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
            let manager = SubtaskManager()
            self?.trackForMemoryLeak(manager)
            
            // This will fail but shouldn't leak memory
            do {
                return try await manager.createSubtask(
                    title: "Memory Test",
                    createdBy: "test",
                    taskId: "test",
                    listId: "test",
                    phaseId: "test",
                    projectId: "test"
                )
            } catch {
                return Subtask(
                    title: "Test",
                    createdBy: "test",
                    taskId: "test",
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
        let manager = SubtaskManager()
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
    
    /// Test multiple SubtaskManager instances don't accumulate memory
    func testMultipleInstancesMemoryAccumulation() async {
        let initialMemory = getCurrentMemoryUsage()
        let instanceCount = 10
        var managers: [SubtaskManager] = []
        
        // Create multiple instances
        for i in 0..<instanceCount {
            let manager = SubtaskManager()
            trackForMemoryLeak(manager)
            managers.append(manager)
            
            // Mock usage
            do {
                _ = try await manager.getSubtasks(
                    taskId: "test-\(i)",
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
    func testDeinitTaskMemoryLeakRegression() async {
        // This test ensures the fix for the deinit { Task { @MainActor in } } issue
        var managers: [SubtaskManager] = []
        
        // Create managers that would have leaked with the old deinit pattern
        for _ in 0..<5 {
            let manager = SubtaskManager()
            
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

// MARK: - Mock Classes for Testing

class MockFirestore {
    // Mock Firestore implementation for testing
}

class MockListenerRegistration: NSObject {
    private(set) var wasRemoved = false
    
    func remove() {
        wasRemoved = true
    }
}

// Extension to make MockListenerRegistration conform to expected protocol
extension MockListenerRegistration {
    override func isEqual(_ object: Any?) -> Bool {
        return self === object as AnyObject
    }
}

// MARK: - Test Extensions

extension SubtaskManager {
    /// Test helper to access internal listeners array
    var listenersCount: Int {
        return listeners.count
    }
}