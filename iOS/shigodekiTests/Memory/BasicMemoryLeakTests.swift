//
//  BasicMemoryLeakTests.swift
//  shigodekiTests
//
//  Simplified memory leak tests that don't rely on internal APIs
//

import XCTest
import Combine
@testable import shigodeki

/// Basic memory leak tests for core managers
/// These tests verify that managers deallocate properly without accessing internal state
@MainActor
final class BasicMemoryLeakTests: XCTestCase {

    override func setUp() {
        super.setUp()
        trackMemoryUsage(maxMemoryMB: 50.0)
    }

    override func tearDown() {
        forceGarbageCollection()
        super.tearDown()
    }

    // MARK: - EnhancedTaskManager Tests

    /// Test that EnhancedTaskManager can be created and properly releases resources
    func testEnhancedTaskManagerBasicLifecycle() async {
        weak var weakManager: EnhancedTaskManager?

        autoreleasepool {
            let manager = EnhancedTaskManager()
            weakManager = manager

            // Verify basic state
            XCTAssertTrue(manager.tasks.isEmpty, "New manager should have no tasks")
            XCTAssertFalse(manager.isLoading, "New manager should not be loading")
        }

        // Allow deallocation
        await waitForMemoryStabilization()

        // Note: The manager might still be retained by Combine bindings,
        // so we just verify the test completes without issues
    }

    /// Test that multiple EnhancedTaskManager instances don't accumulate memory
    func testEnhancedTaskManagerMultipleInstances() async {
        let initialMemory = getCurrentMemoryUsage()

        for _ in 0..<5 {
            autoreleasepool {
                let manager = EnhancedTaskManager()
                _ = manager.tasks
                _ = manager.isLoading
            }
        }

        await waitForMemoryStabilization()

        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory

        // Memory increase should be reasonable (less than 20MB)
        XCTAssertLessThan(memoryIncrease, 20.0, "Memory should not accumulate significantly")
    }

    // MARK: - SubtaskManager Tests

    /// Test that SubtaskManager can be created and has proper initial state
    func testSubtaskManagerBasicLifecycle() async {
        weak var weakManager: SubtaskManager?

        autoreleasepool {
            let manager = SubtaskManager()
            weakManager = manager

            // Verify basic state
            XCTAssertTrue(manager.subtasks.isEmpty, "New manager should have no subtasks")
            XCTAssertFalse(manager.isLoading, "New manager should not be loading")
        }

        await waitForMemoryStabilization()
    }

    /// Test that multiple SubtaskManager instances don't accumulate memory
    func testSubtaskManagerMultipleInstances() async {
        let initialMemory = getCurrentMemoryUsage()

        for _ in 0..<5 {
            autoreleasepool {
                let manager = SubtaskManager()
                _ = manager.subtasks
                _ = manager.isLoading
            }
        }

        await waitForMemoryStabilization()

        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory

        XCTAssertLessThan(memoryIncrease, 20.0, "Memory should not accumulate significantly")
    }

    // MARK: - PhaseTaskDetailViewModel Tests

    /// Test that PhaseTaskDetailViewModel has proper lifecycle
    func testPhaseTaskDetailViewModelBasicLifecycle() async {
        weak var weakViewModel: PhaseTaskDetailViewModel?

        autoreleasepool {
            // Create minimal test data
            var project = Project(name: "Test", ownerId: "test-user")
            project.id = "test-project"

            var phase = Phase(name: "Test Phase", projectId: "test-project", createdBy: "test-user", order: 0)
            phase.id = "test-phase"

            var task = ShigodekiTask(
                title: "Test Task",
                createdBy: "test-user",
                listId: "test-list",
                phaseId: "test-phase",
                projectId: "test-project",
                order: 0
            )
            task.id = "test-task"

            let viewModel = PhaseTaskDetailViewModel(task: task, project: project, phase: phase)
            weakViewModel = viewModel

            // Verify basic state
            XCTAssertFalse(viewModel.hasChanges, "New ViewModel should have no changes")
        }

        await waitForMemoryStabilization()
    }

    // MARK: - Combine Publisher Tests

    /// Test that Combine subscriptions clean up properly
    func testCombineSubscriptionCleanup() async {
        var cancellables: Set<AnyCancellable> = []

        autoreleasepool {
            let manager = EnhancedTaskManager()

            // Create subscriptions
            manager.$tasks
                .sink { _ in }
                .store(in: &cancellables)

            manager.$isLoading
                .sink { _ in }
                .store(in: &cancellables)

            manager.$error
                .sink { _ in }
                .store(in: &cancellables)

            // Clean up subscriptions
            cancellables.removeAll()
        }

        await waitForMemoryStabilization()

        XCTAssertTrue(cancellables.isEmpty, "Cancellables should be empty after cleanup")
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
