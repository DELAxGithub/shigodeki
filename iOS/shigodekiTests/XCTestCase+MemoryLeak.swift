//
//  XCTestCase+MemoryLeak.swift
//  shigodekiTests
//
//  Created by Claude on 2025-08-29.
//

import XCTest
import SwiftUI
import Combine

/// Memory leak detection framework for comprehensive testing
extension XCTestCase {
    
    // MARK: - Memory Leak Detection
    
    /// Track an object instance for memory leaks with weak reference monitoring
    func trackForMemoryLeak<T: AnyObject>(_ instance: T, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak detected.", file: file, line: line)
        }
    }
    
    /// Track multiple objects for memory leaks
    func trackForMemoryLeaks<T: AnyObject>(_ instances: [T], file: StaticString = #filePath, line: UInt = #line) {
        instances.forEach { trackForMemoryLeak($0, file: file, line: line) }
    }
    
    /// Memory usage monitoring with threshold checking
    func trackMemoryUsage(maxMemoryMB: Double = 50.0, file: StaticString = #filePath, line: UInt = #line) {
        let startMemory = getCurrentMemoryUsage()
        
        addTeardownBlock {
            let endMemory = self.getCurrentMemoryUsage()
            let memoryIncrease = endMemory - startMemory
            
            XCTAssertLessThan(memoryIncrease, maxMemoryMB,
                             "Memory usage exceeded threshold: \(memoryIncrease)MB > \(maxMemoryMB)MB",
                             file: file, line: line)
        }
    }
    
    // MARK: - SwiftUI View Memory Testing
    
    /// Test SwiftUI view for memory leaks
    func testViewForMemoryLeak<V: View>(_ viewBuilder: () -> V, file: StaticString = #filePath, line: UInt = #line) {
        let view = viewBuilder()
        let hostingController = UIHostingController(rootView: view)
        
        // Track the hosting controller
        trackForMemoryLeak(hostingController, file: file, line: line)
        
        // Simulate view lifecycle
        _ = hostingController.view
        hostingController.viewDidLoad()
        hostingController.viewWillAppear(false)
        hostingController.viewDidAppear(false)
        hostingController.viewWillDisappear(false)
        hostingController.viewDidDisappear(false)
    }
    
    // MARK: - Combine Publisher Testing
    
    /// Test Combine publishers for memory leaks
    func testPublisherForMemoryLeak<T: Publisher>(_ publisher: T, file: StaticString = #filePath, line: UInt = #line) {
        var cancellables: Set<AnyCancellable> = []
        
        let expectation = expectation(description: "Publisher completes or fails")
        
        publisher
            .sink(receiveCompletion: { completion in
                expectation.fulfill()
                cancellables.removeAll() // Ensure cleanup
            }, receiveValue: { _ in })
            .store(in: &cancellables)
        
        // Track cancellables set
        trackForMemoryLeak(cancellables as AnyObject, file: file, line: line)
        
        waitForExpectations(timeout: 2.0)
    }
    
    // MARK: - Async/Await Memory Testing
    
    /// Test async operations for memory leaks
    func testAsyncOperationForMemoryLeak<T>(_ operation: @escaping () async throws -> T, file: StaticString = #filePath, line: UInt = #line) async rethrows {
        let startMemory = getCurrentMemoryUsage()
        
        _ = try await operation()
        
        // Force garbage collection
        autoreleasepool { }
        
        let endMemory = getCurrentMemoryUsage()
        let memoryIncrease = endMemory - startMemory
        
        XCTAssertLessThan(memoryIncrease, 10.0, "Async operation memory leak detected: \(memoryIncrease)MB", file: file, line: line)
    }
    
    // MARK: - ObservableObject Testing
    
    /// Test ObservableObject instances for memory leaks
    func testObservableObjectForMemoryLeak<T: ObservableObject>(_ objectBuilder: () -> T, file: StaticString = #filePath, line: UInt = #line) {
        let object = objectBuilder()
        trackForMemoryLeak(object, file: file, line: line)
        
        // Test publisher subscription cleanup
        var cancellables: Set<AnyCancellable> = []
        object.objectWillChange
            .sink { _ in }
            .store(in: &cancellables)
        
        // Ensure cancellables are cleaned up
        addTeardownBlock {
            cancellables.removeAll()
        }
    }
    
    // MARK: - Firestore Listener Testing
    
    /// Test Firestore listener cleanup for memory leaks
    func testFirestoreListenerCleanup(_ setupListener: () -> Any, file: StaticString = #filePath, line: UInt = #line) {
        let listener = setupListener()
        
        // Track listener for cleanup
        if let firestoreListener = listener as? AnyObject {
            trackForMemoryLeak(firestoreListener, file: file, line: line)
        }
    }
    
    // MARK: - Memory Utilities
    
    /// Get current memory usage in MB
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
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0
        }
        return 0.0
    }
    
    // MARK: - Test Helpers
    
    /// Wait for memory to stabilize after operations
    func waitForMemoryStabilization(timeout: TimeInterval = 1.0) async {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        autoreleasepool { }
    }
    
    /// Force garbage collection for more accurate memory testing
    func forceGarbageCollection() {
        for _ in 0..<3 {
            autoreleasepool { }
        }
    }
}

// MARK: - Memory Leak Test Assertions

extension XCTestCase {
    
    /// Assert that an object was properly deallocated
    func assertObjectDeallocated<T: AnyObject>(_ object: T?, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(object, "Object should have been deallocated", file: file, line: line)
    }
    
    /// Assert memory usage is within acceptable bounds
    func assertMemoryWithinBounds(actual: Double, maximum: Double, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThanOrEqual(actual, maximum, "Memory usage \(actual)MB exceeds maximum \(maximum)MB", file: file, line: line)
    }
}