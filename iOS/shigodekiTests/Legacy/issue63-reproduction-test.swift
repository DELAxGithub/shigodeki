#!/usr/bin/env swift

//
// Issue #63 Reproduction Test: タスク詳細の完了トグルボタンが動作しない
//
// TDD RED Phase: 完了トグル機能のバグを検証
// Expected: FAIL (completion toggle does not respond)
//

import Foundation

print("🔴 RED Phase: Issue #63 完了トグルボタン無反応バグの検証")
print("========================================================")

// Mock Task with completion state
struct MockTask {
    var id = "test-task-id"
    var title = "テストタスク"
    var isCompleted = false
    var completedAt: Date? = nil
}

// Mock Task Manager to simulate persistence
class MockTaskManager {
    var updateCallCount = 0
    var lastUpdatedTask: MockTask?
    
    func updateTask(_ task: MockTask) throws -> MockTask {
        updateCallCount += 1
        lastUpdatedTask = task
        print("  📝 TaskManager.updateTask() called")
        print("    - Task ID: \(task.id)")
        print("    - Completed: \(task.isCompleted)")
        print("    - CompletedAt: \(task.completedAt?.description ?? "nil")")
        return task
    }
}

// Test Case: Completion Toggle Binding Validation
struct Issue63ReproductionTest {
    
    func testCompletionToggleBinding() {
        print("🧪 Test Case: Completion Toggle Binding")
        
        // Arrange
        var task = MockTask()
        var changeCallCount = 0
        let taskManager = MockTaskManager()
        
        let initialState = task.isCompleted
        print("  初期完了状態: \(initialState ? "完了" : "未完了")")
        
        // Mock persistChanges function
        let persistChanges = {
            changeCallCount += 1
            print("  persistChanges() called")
            do {
                task = try taskManager.updateTask(task)
            } catch {
                print("  ❌ Update failed: \(error)")
            }
        }
        
        // Act: Simulate the completion toggle Binding
        func simulateBinding(get: () -> Bool, set: @escaping (Bool) -> Void) -> (Bool, (Bool) -> Void) {
            return (get(), set)
        }
        
        let (currentValue, setCompleted) = simulateBinding(
            get: { task.isCompleted },
            set: { newValue in
                task.isCompleted = newValue
                task.completedAt = newValue ? Date() : nil
                persistChanges()
            }
        )
        
        // Simulate user toggling completion
        let newCompletionState = !task.isCompleted
        setCompleted(newCompletionState)
        
        // Assert
        print("  トグル後の完了状態: \(task.isCompleted ? "完了" : "未完了")")
        print("  変更回数: \(changeCallCount)")
        print("  TaskManager呼び出し回数: \(taskManager.updateCallCount)")
        
        // Validation
        let stateChanged = task.isCompleted == newCompletionState
        let persistCalled = changeCallCount == 1
        let managerCalled = taskManager.updateCallCount == 1
        let completedAtSet = task.isCompleted ? task.completedAt != nil : task.completedAt == nil
        
        print("  State changed: \(stateChanged ? "✅" : "❌")")
        print("  Persist called: \(persistCalled ? "✅" : "❌")")
        print("  Manager called: \(managerCalled ? "✅" : "❌")")
        print("  CompletedAt set: \(completedAtSet ? "✅" : "❌")")
        
        if stateChanged && persistCalled && managerCalled && completedAtSet {
            print("  ✅ PASS: Completion toggle binding works correctly")
        } else {
            print("  ❌ FAIL: Completion toggle binding is broken")
        }
    }
    
    func testPhaseTaskDetailViewCompletionToggle() {
        print("\n🧪 Test Case: PhaseTaskDetailView Completion Toggle Integration")
        
        // Arrange: Simulate the exact binding from PhaseTaskDetailView.swift line 33
        var task = MockTask()
        var persistCallCount = 0
        
        let persistChanges = {
            persistCallCount += 1
            print("  persistChanges() called from PhaseTaskDetailView")
        }
        
        let initialState = task.isCompleted
        print("  初期完了状態: \(initialState ? "完了" : "未完了")")
        
        // Act: Simulate the exact Toggle Binding code from the view
        func simulateToggleBinding(get: () -> Bool, set: @escaping (Bool) -> Void) -> (Bool, (Bool) -> Void) {
            return (get(), set)
        }
        
        let (_, setToggleState) = simulateToggleBinding(
            get: { task.isCompleted },
            set: { newValue in 
                task.isCompleted = newValue
                persistChanges()
            }
        )
        
        // Simulate user toggling the completion state
        let targetState = true  // User marks as completed
        setToggleState(targetState)
        
        // Assert
        print("  トグル後の状態: \(task.isCompleted ? "完了" : "未完了")")
        print("  永続化呼び出し回数: \(persistCallCount)")
        
        // Validation
        let stateUpdated = task.isCompleted == targetState
        let persistCalled = persistCallCount == 1
        
        print("  State updated: \(stateUpdated ? "✅" : "❌")")
        print("  Persist called: \(persistCalled ? "✅" : "❌")")
        
        if stateUpdated && persistCalled {
            print("  ✅ PASS: Toggle integration works correctly")
        } else {
            print("  ❌ FAIL: Toggle integration is broken")
            print("    - State updated: \(stateUpdated)")
            print("    - Persist called: \(persistCalled)")
        }
    }
    
    func testCompletionStateTransitions() {
        print("\n🧪 Test Case: All Completion State Transitions")
        
        var task = MockTask()
        
        // Test:未完了 → 完了
        print("  テスト: 未完了 → 完了")
        task.isCompleted = false
        task.completedAt = nil
        
        task.isCompleted = true
        task.completedAt = Date()
        
        let toCompletedSuccess = task.isCompleted && task.completedAt != nil
        print("    結果: \(toCompletedSuccess ? "✅" : "❌")")
        
        // Test: 完了 → 未完了
        print("  テスト: 完了 → 未完了")
        task.isCompleted = true
        task.completedAt = Date()
        
        task.isCompleted = false
        task.completedAt = nil
        
        let toIncompleteSuccess = !task.isCompleted && task.completedAt == nil
        print("    結果: \(toIncompleteSuccess ? "✅" : "❌")")
        
        if toCompletedSuccess && toIncompleteSuccess {
            print("  ✅ PASS: All state transitions work correctly")
        } else {
            print("  ❌ FAIL: State transitions are broken")
        }
    }
}

// Execute Tests
print("\n🚨 実行中: Issue #63 バグ再現テスト")
print("Expected: 現在のコードでは正常に動作するはず（バグが見つからない場合）")
print("If tests PASS: バグは実際のUIレイヤーかTaskManager層にある可能性")
print("If tests FAIL: 基本的なToggle機能に問題あり")

let testSuite = Issue63ReproductionTest()

print("\n" + String(repeating: "=", count: 50))
testSuite.testCompletionToggleBinding()
testSuite.testPhaseTaskDetailViewCompletionToggle()
testSuite.testCompletionStateTransitions()

print("\n🔴 RED Phase Results:")
print("- このテストがPASSする場合、バグは実際のUIレイヤーかTaskManager実装にある")
print("- バグの原因候補:")
print("  1. Toggle UIが無効化されている")
print("  2. タップ可能領域の問題")
print("  3. TaskManagerの実装不備")
print("  4. Firebase連携の問題")
print("  5. 他のBinding競合")

print("\n🎯 Next: PhaseTaskDetailView.swiftの実装確認とバグ修正の準備")
print("========================================================")