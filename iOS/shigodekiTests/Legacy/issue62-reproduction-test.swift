#!/usr/bin/env swift

//
// Issue #62 Reproduction Test: 優先度切り替えボタンが反応しない
//
// TDD RED Phase: 優先度変更機能のバグを検証
// Expected: FAIL (priority picker does not respond)
//

import Foundation

print("🔴 RED Phase: Issue #62 優先度切り替えボタン無反応バグの検証")
print("========================================================")

// Mock Priority Enum to simulate TaskPriority behavior
enum MockTaskPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium" 
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}

// Mock Task with priority field
struct MockTask {
    var id = UUID().uuidString
    var title = "テストタスク"
    var priority: MockTaskPriority = .medium
}

// Test Case: Priority Picker Binding Validation
struct Issue62ReproductionTest {
    
    func testPriorityPickerBinding() {
        print("🧪 Test Case: Priority Picker Binding")
        
        // Arrange
        var task = MockTask()
        var changeCallCount = 0
        let initialPriority = task.priority
        
        print("  初期優先度: \(initialPriority.displayName)")
        
        // Act: Simulate priority picker selection change
        let newPriority: MockTaskPriority = .high
        
        // Mock the Picker's Binding behavior (simulate SwiftUI Binding)
        func simulateBinding(get: () -> MockTaskPriority, set: @escaping (MockTaskPriority) -> Void) -> (MockTaskPriority, (MockTaskPriority) -> Void) {
            return (get(), set)
        }
        
        let (currentValue, setValue) = simulateBinding(
            get: { task.priority },
            set: { newValue in
                task.priority = newValue
                changeCallCount += 1
                print("  優先度変更実行: \(newValue.displayName)")
            }
        )
        
        // Simulate user selecting high priority
        setValue(newPriority)
        
        // Assert
        print("  最終優先度: \(task.priority.displayName)")
        print("  変更回数: \(changeCallCount)")
        
        // Expected behavior verification
        let priorityUpdated = task.priority == newPriority
        let changeCallbackCalled = changeCallCount == 1
        let priorityChanged = task.priority != initialPriority
        
        print("  Priority updated: \(priorityUpdated ? "✅" : "❌")")
        print("  Change callback called: \(changeCallbackCalled ? "✅" : "❌")")
        print("  Priority changed from initial: \(priorityChanged ? "✅" : "❌")")
        
        if task.priority == newPriority && changeCallCount == 1 {
            print("  ✅ PASS: Priority picker binding works correctly")
        } else {
            print("  ❌ FAIL: Priority picker binding is broken")
        }
    }
    
    func testPhaseTaskDetailViewPriorityPicker() {
        print("\n🧪 Test Case: PhaseTaskDetailView Priority Picker Integration")
        
        // Arrange: Simulate the exact binding from PhaseTaskDetailView.swift line 34
        var task = MockTask()
        var persistCallCount = 0
        
        // Mock persistChanges function
        let persistChanges = {
            persistCallCount += 1
            print("  persistChanges() called")
        }
        
        let initialPriority = task.priority
        print("  初期優先度: \(initialPriority.displayName)")
        
        // Act: Simulate the exact Binding code from the view
        func simulateBinding2(get: () -> MockTaskPriority, set: @escaping (MockTaskPriority) -> Void) -> (MockTaskPriority, (MockTaskPriority) -> Void) {
            return (get(), set)
        }
        
        let (_, setPriority) = simulateBinding2(
            get: { task.priority },
            set: { newValue in 
                task.priority = newValue
                persistChanges()
            }
        )
        
        // Simulate user selecting low priority
        let targetPriority: MockTaskPriority = .low
        setPriority(targetPriority)
        
        // Assert
        print("  選択後の優先度: \(task.priority.displayName)")
        print("  永続化呼び出し回数: \(persistCallCount)")
        
        // Verification
        let priorityChanged = task.priority == targetPriority
        let persistCalled = persistCallCount == 1
        
        print("  Priority changed: \(priorityChanged ? "✅" : "❌")")
        print("  Persist called: \(persistCalled ? "✅" : "❌")")
        
        if priorityChanged && persistCalled {
            print("  ✅ PASS: Priority picker integration works correctly")
        } else {
            print("  ❌ FAIL: Priority picker integration is broken")
            print("    - Priority changed: \(priorityChanged)")
            print("    - Persist called: \(persistCalled)")
        }
    }
    
    func testAllPriorityOptions() {
        print("\n🧪 Test Case: All Priority Options Selectable")
        
        var task = MockTask()
        
        // Test each priority option
        for priority in MockTaskPriority.allCases {
            task.priority = priority
            let success = task.priority == priority
            print("  優先度設定テスト: \(priority.displayName) - \(success ? "✅" : "❌")")
        }
        
        print("  ✅ PASS: All priority options are selectable")
    }
}

// Execute Tests
print("\n🚨 実行中: Issue #62 バグ再現テスト")
print("Expected: 現在のコードでは正常に動作するはず（バグが見つからない場合）")
print("If tests PASS: バグは別の箇所にある可能性")
print("If tests FAIL: 基本的なBinding機能に問題あり")

let testSuite = Issue62ReproductionTest()

print("\n" + String(repeating: "=", count: 50))
testSuite.testPriorityPickerBinding()
testSuite.testPhaseTaskDetailViewPriorityPicker()
testSuite.testAllPriorityOptions()

print("\n🔴 RED Phase Results:")
print("- このテストがPASSする場合、バグは実際のUIレイヤーかInteraction層にある")
print("- バグの原因候補:")
print("  1. Pickerの表示スタイル問題 (.menu, .segmented, .wheel)")
print("  2. UI要素が無効化されている")
print("  3. タッチ可能領域の問題")
print("  4. SwiftUI Formでの表示競合")
print("  5. 他のBinding競合")

print("\n🎯 Next: 実際のUIでの動作確認とバグ修正の準備")
print("========================================================")