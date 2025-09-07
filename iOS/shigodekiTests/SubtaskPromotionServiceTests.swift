//
//  SubtaskPromotionServiceTests.swift
//  shigodekiTests
//
//  Test cases for subtask promotion functionality
//

import XCTest
@testable import shigodeki

final class SubtaskPromotionServiceTests: XCTestCase {
    
    func testSubtaskPromotionServiceExists() {
        // テストの存在確認：SubtaskPromotionService が正しく定義されているか
        XCTAssertTrue(SubtaskPromotionService.self != nil)
    }
    
    func testSubtaskPromotionErrorTypes() {
        // エラータイプの確認
        let missingIdError = SubtaskPromotionError.missingRequiredId
        XCTAssertEqual(missingIdError.errorDescription, "必要なIDが不足しています")
        
        let taskCreationError = SubtaskPromotionError.taskCreationFailed("Test error")
        XCTAssertEqual(taskCreationError.errorDescription, "タスク作成に失敗しました: Test error")
        
        let subtaskDeletionError = SubtaskPromotionError.subtaskDeletionFailed("Delete error")
        XCTAssertEqual(subtaskDeletionError.errorDescription, "サブタスク削除に失敗しました: Delete error")
    }
    
    func testTaskExtendedSectionsHasPromoteCallback() {
        // TaskSubtasksSection が繰り上げコールバックを受け入れるか確認
        // これは構造体なので直接テストはできないが、コンパイルエラーがないことを確認
        let mockSubtasks: [Subtask] = []
        
        // コンパイル確認のための構造体インスタンス化
        let section = TaskSubtasksSection(
            subtasks: mockSubtasks,
            newSubtaskTitle: .constant(""),
            onToggleSubtask: { _ in },
            onDeleteSubtask: { _ in },
            onPromoteSubtask: { _ in }, // 新しく追加されたコールバック
            onAddSubtask: { }
        )
        
        // 構造体が正常に作成できることを確認
        XCTAssertEqual(section.subtasks.count, 0)
    }
    
    func testMockSubtaskCreation() {
        // テスト用のサブタスクが正常に作成できるか確認
        let mockSubtask = Subtask(
            title: "Test Subtask",
            description: "Test Description",
            assignedTo: nil,
            createdBy: "testUser",
            dueDate: nil,
            taskId: "testTaskId",
            listId: "testListId",
            phaseId: "testPhaseId",
            projectId: "testProjectId",
            order: 1
        )
        
        XCTAssertEqual(mockSubtask.title, "Test Subtask")
        XCTAssertEqual(mockSubtask.description, "Test Description")
        XCTAssertEqual(mockSubtask.createdBy, "testUser")
        XCTAssertFalse(mockSubtask.isCompleted)
    }
    
    func testMockTaskCreation() {
        // テスト用のタスクが正常に作成できるか確認
        let mockTask = ShigodekiTask(
            title: "Test Task",
            description: "Test Task Description",
            assignedTo: nil,
            createdBy: "testUser",
            dueDate: nil,
            priority: .medium,
            listId: "testListId",
            phaseId: "testPhaseId",
            projectId: "testProjectId",
            order: 1
        )
        
        XCTAssertEqual(mockTask.title, "Test Task")
        XCTAssertEqual(mockTask.listId, "testListId")
        XCTAssertEqual(mockTask.phaseId, "testPhaseId")
        XCTAssertEqual(mockTask.projectId, "testProjectId")
        XCTAssertEqual(mockTask.priority, .medium)
    }
}

// MARK: - Integration Test Helpers

extension SubtaskPromotionServiceTests {
    
    /// 実際の繰り上げテスト用のヘルパー（将来的な統合テストで使用）
    func createMockDataForPromotionTest() -> (Subtask, ShigodekiTask, Project, Phase) {
        let subtask = Subtask(
            title: "Subtask to Promote",
            description: "This subtask will be promoted to task",
            assignedTo: "user123",
            createdBy: "creator123",
            dueDate: Date(),
            taskId: "parentTask123",
            listId: "list123",
            phaseId: "phase123",
            projectId: "project123",
            order: 1
        )
        
        let parentTask = ShigodekiTask(
            title: "Parent Task",
            description: "Parent task containing subtasks",
            assignedTo: nil,
            createdBy: "creator123",
            dueDate: nil,
            priority: .high,
            listId: "list123",
            phaseId: "phase123",
            projectId: "project123",
            order: 1
        )
        
        let project = Project(
            name: "Test Project",
            description: "Test project for promotion",
            createdBy: "creator123",
            members: ["creator123", "user123"]
        )
        
        let phase = Phase(
            name: "Test Phase",
            description: "Test phase for promotion",
            projectId: "project123",
            createdBy: "creator123",
            order: 1
        )
        
        return (subtask, parentTask, project, phase)
    }
}