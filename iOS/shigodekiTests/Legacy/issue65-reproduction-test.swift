#!/usr/bin/env swift

//
// Issue #65 Reproduction Test: プロジェクト設定画面で変更後に保存ボタンが活性化しない
//
// TDD RED Phase: 保存ボタン活性化機能のバグを検証
// Expected: FAIL (save button doesn't activate after changes)
//

import Foundation

print("🔴 RED Phase: Issue #65 保存ボタン活性化問題の検証")
print("========================================================")

// Mock Project data structure
struct MockProject {
    var id: String?
    var name: String
    var description: String?
    var isCompleted: Bool
    
    init(name: String, description: String? = nil, isCompleted: Bool = false) {
        self.id = UUID().uuidString
        self.name = name
        self.description = description
        self.isCompleted = isCompleted
    }
}

// Mock Project Settings View State
class MockProjectSettingsViewState {
    let originalProject: MockProject
    var projectName: String
    var projectDescription: String
    var isCompleted: Bool
    var isUpdating: Bool = false
    
    init(project: MockProject) {
        self.originalProject = project
        self.projectName = project.name
        self.projectDescription = project.description ?? ""
        self.isCompleted = project.isCompleted
    }
    
    // Mock hasChanges computed property logic from ProjectSettingsView.swift:339
    var hasChanges: Bool {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = projectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalDescription = originalProject.description ?? ""
        
        return trimmedName != originalProject.name ||
               trimmedDescription != originalDescription ||
               isCompleted != originalProject.isCompleted
    }
    
    // Mock save button enabled logic
    var isSaveButtonEnabled: Bool {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && !isUpdating && hasChanges
    }
}

// Test Case: Save Button Activation Logic
struct Issue65ReproductionTest {
    
    func testSaveButtonActivationOnNameChange() {
        print("🧪 Test Case: Save Button Activation on Name Change")
        
        // Arrange
        let originalProject = MockProject(name: "元のプロジェクト", description: "元の説明")
        let viewState = MockProjectSettingsViewState(project: originalProject)
        
        print("  初期状態:")
        print("    プロジェクト名: \(viewState.projectName)")
        print("    hasChanges: \(viewState.hasChanges)")
        print("    保存ボタン有効: \(viewState.isSaveButtonEnabled)")
        
        // Act: Change project name
        viewState.projectName = "変更されたプロジェクト"
        
        // Assert
        print("  名前変更後:")
        print("    プロジェクト名: \(viewState.projectName)")
        print("    hasChanges: \(viewState.hasChanges)")
        print("    保存ボタン有効: \(viewState.isSaveButtonEnabled)")
        
        let changesDetected = viewState.hasChanges
        let saveButtonEnabled = viewState.isSaveButtonEnabled
        
        print("  Changes detected: \(changesDetected ? "✅" : "❌")")
        print("  Save button enabled: \(saveButtonEnabled ? "✅" : "❌")")
        
        if changesDetected && saveButtonEnabled {
            print("  ✅ PASS: Save button activates correctly on name change")
        } else {
            print("  ❌ FAIL: Save button activation is broken")
        }
    }
    
    func testSaveButtonActivationOnDescriptionChange() {
        print("\n🧪 Test Case: Save Button Activation on Description Change")
        
        // Arrange
        let originalProject = MockProject(name: "テストプロジェクト", description: "元の説明")
        let viewState = MockProjectSettingsViewState(project: originalProject)
        
        print("  初期状態:")
        print("    説明: \(viewState.projectDescription)")
        print("    hasChanges: \(viewState.hasChanges)")
        print("    保存ボタン有効: \(viewState.isSaveButtonEnabled)")
        
        // Act: Change project description
        viewState.projectDescription = "変更された説明文"
        
        // Assert
        print("  説明変更後:")
        print("    説明: \(viewState.projectDescription)")
        print("    hasChanges: \(viewState.hasChanges)")
        print("    保存ボタン有効: \(viewState.isSaveButtonEnabled)")
        
        let changesDetected = viewState.hasChanges
        let saveButtonEnabled = viewState.isSaveButtonEnabled
        
        print("  Changes detected: \(changesDetected ? "✅" : "❌")")
        print("  Save button enabled: \(saveButtonEnabled ? "✅" : "❌")")
        
        if changesDetected && saveButtonEnabled {
            print("  ✅ PASS: Save button activates correctly on description change")
        } else {
            print("  ❌ FAIL: Save button activation is broken")
        }
    }
    
    func testSaveButtonActivationOnCompletionToggle() {
        print("\n🧪 Test Case: Save Button Activation on Completion Toggle")
        
        // Arrange
        let originalProject = MockProject(name: "完了テストプロジェクト", isCompleted: false)
        let viewState = MockProjectSettingsViewState(project: originalProject)
        
        print("  初期状態:")
        print("    完了状態: \(viewState.isCompleted)")
        print("    hasChanges: \(viewState.hasChanges)")
        print("    保存ボタン有効: \(viewState.isSaveButtonEnabled)")
        
        // Act: Toggle completion status
        viewState.isCompleted = true
        
        // Assert
        print("  完了状態変更後:")
        print("    完了状態: \(viewState.isCompleted)")
        print("    hasChanges: \(viewState.hasChanges)")
        print("    保存ボタン有効: \(viewState.isSaveButtonEnabled)")
        
        let changesDetected = viewState.hasChanges
        let saveButtonEnabled = viewState.isSaveButtonEnabled
        
        print("  Changes detected: \(changesDetected ? "✅" : "❌")")
        print("  Save button enabled: \(saveButtonEnabled ? "✅" : "❌")")
        
        if changesDetected && saveButtonEnabled {
            print("  ✅ PASS: Save button activates correctly on completion toggle")
        } else {
            print("  ❌ FAIL: Save button activation is broken")
        }
    }
    
    func testSaveButtonDisabledWhenNoChanges() {
        print("\n🧪 Test Case: Save Button Disabled When No Changes")
        
        // Arrange
        let originalProject = MockProject(name: "変更なしプロジェクト", description: "変更なし")
        let viewState = MockProjectSettingsViewState(project: originalProject)
        
        print("  初期状態（変更なし）:")
        print("    hasChanges: \(viewState.hasChanges)")
        print("    保存ボタン有効: \(viewState.isSaveButtonEnabled)")
        
        // Act: Make change then revert
        viewState.projectName = "一時変更"
        print("  一時変更後:")
        print("    hasChanges: \(viewState.hasChanges)")
        print("    保存ボタン有効: \(viewState.isSaveButtonEnabled)")
        
        // Revert change
        viewState.projectName = originalProject.name
        
        // Assert
        print("  変更を戻した後:")
        print("    hasChanges: \(viewState.hasChanges)")
        print("    保存ボタン有効: \(viewState.isSaveButtonEnabled)")
        
        let noChanges = !viewState.hasChanges
        let saveButtonDisabled = !viewState.isSaveButtonEnabled
        
        print("  No changes: \(noChanges ? "✅" : "❌")")
        print("  Save button disabled: \(saveButtonDisabled ? "✅" : "❌")")
        
        if noChanges && saveButtonDisabled {
            print("  ✅ PASS: Save button correctly disabled when no changes")
        } else {
            print("  ❌ FAIL: Save button state management is broken")
        }
    }
    
    func testSaveButtonDisabledWithEmptyName() {
        print("\n🧪 Test Case: Save Button Disabled With Empty Name")
        
        // Arrange
        let originalProject = MockProject(name: "有効なプロジェクト名")
        let viewState = MockProjectSettingsViewState(project: originalProject)
        
        // Act: Set empty name
        viewState.projectName = ""
        
        // Assert
        print("  空の名前設定後:")
        print("    プロジェクト名: '\(viewState.projectName)'")
        print("    hasChanges: \(viewState.hasChanges)")
        print("    保存ボタン有効: \(viewState.isSaveButtonEnabled)")
        
        let changesDetected = viewState.hasChanges
        let saveButtonDisabled = !viewState.isSaveButtonEnabled
        
        print("  Changes detected: \(changesDetected ? "✅" : "❌")")
        print("  Save button disabled: \(saveButtonDisabled ? "✅" : "❌")")
        
        if changesDetected && saveButtonDisabled {
            print("  ✅ PASS: Save button correctly disabled with empty name")
        } else {
            print("  ❌ FAIL: Validation logic is broken")
        }
    }
}

// Execute Tests
print("\n🚨 実行中: Issue #65 バグ再現テスト")
print("Expected: 変更検知ロジック自体は正常だが、UI側で正しく反映されていない可能性")
print("If tests PASS: バグはView層でのバインディング問題")
print("If tests FAIL: hasChanges計算ロジックの問題")

let testSuite = Issue65ReproductionTest()

print("\n" + String(repeating: "=", count: 50))
testSuite.testSaveButtonActivationOnNameChange()
testSuite.testSaveButtonActivationOnDescriptionChange()
testSuite.testSaveButtonActivationOnCompletionToggle()
testSuite.testSaveButtonDisabledWhenNoChanges()
testSuite.testSaveButtonDisabledWithEmptyName()

print("\n🔴 RED Phase Results:")
print("- このテストがPASSする場合、バグはView層のバインディングにある")
print("- バグの原因候補:")
print("  1. SwiftUI @StateとComputed Propertyの更新タイミング")
print("  2. toolbarボタンのdisabled条件が正しく評価されない")
print("  3. hasChangesの計算が実行時に正しく動作しない")
print("  4. ViewStateの更新がUI更新をトリガーしない")
print("  5. バリデーション条件の複雑さによる予期しない無効化")

print("\n🎯 Next: ProjectSettingsView.swiftのツールバー実装確認とバグ修正")
print("========================================================")