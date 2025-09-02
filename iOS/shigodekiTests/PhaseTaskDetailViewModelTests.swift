//
//  PhaseTaskDetailViewModelTests.swift
//  shigodeki
//
//  Operation: Decoupling - Strategic Tests
//  Created by Claude on 2025-09-02.
//

import XCTest
@testable import shigodeki

// MARK: - Operation: Decoupling Tests
// These tests define the expected behavior for a properly decoupled TaskDetailView

class PhaseTaskDetailViewModelTests: XCTestCase {
    
    var viewModel: PhaseTaskDetailViewModel!
    var mockTask: ShigodekiTask!
    var mockProject: Project!
    var mockPhase: Phase!
    
    override func setUp() {
        super.setUp()
        
        // Create mock data
        mockProject = Project(
            id: "test-project-id",
            name: "Test Project",
            description: "Test Description",
            createdBy: "test-user",
            ownerId: "test-user",
            ownerType: .individual,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        mockPhase = Phase(
            id: "test-phase-id",
            name: "Test Phase",
            description: "Test Phase Description",
            projectId: "test-project-id",
            createdBy: "test-user",
            createdAt: Date(),
            order: 0
        )
        
        mockTask = ShigodekiTask(
            id: "test-task-id",
            title: "Test Task",
            description: "Test Description",
            isCompleted: false,
            priority: .medium,
            dueDate: nil,
            createdBy: "test-user",
            assignedTo: nil,
            projectId: "test-project-id",
            phaseId: "test-phase-id",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Initialize ViewModel (will fail until we create it)
        viewModel = PhaseTaskDetailViewModel(
            task: mockTask,
            project: mockProject,
            phase: mockPhase
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockTask = nil
        mockProject = nil
        mockPhase = nil
        super.tearDown()
    }
    
    // MARK: - Strategic Tests for Operation: Decoupling
    
    func test_初期状態では保存ボタンは非活性である() {
        // Given: 初期状態のViewModel
        
        // When: ViewModelが初期化された直後
        
        // Then: 保存ボタンは非活性である
        XCTAssertFalse(viewModel.shouldEnableSaveButton, "初期状態では保存ボタンは非活性でなければならない")
        XCTAssertFalse(viewModel.hasChanges, "初期状態では変更がないはず")
    }
    
    func test_完了トグルをONにするとViewModelが変更済み状態になり保存ボタンが活性化する() {
        // Given: 初期状態のViewModel（完了=false）
        XCTAssertFalse(viewModel.isCompleted, "初期状態では未完了")
        XCTAssertFalse(viewModel.hasChanges, "初期状態では変更なし")
        
        // When: 完了状態をtrueに変更
        viewModel.setCompleted(true)
        
        // Then: ViewModelが「変更済み」状態になり、保存ボタンが活性化する
        XCTAssertTrue(viewModel.isCompleted, "完了状態がtrueになる")
        XCTAssertTrue(viewModel.hasChanges, "変更ありの状態になる")
        XCTAssertTrue(viewModel.shouldEnableSaveButton, "保存ボタンが活性化される")
    }
    
    func test_優先度を変更するとViewModelが変更済み状態になり保存ボタンが活性化する() {
        // Given: 初期状態のViewModel（優先度=medium）
        XCTAssertEqual(viewModel.priority, .medium, "初期状態では中優先度")
        XCTAssertFalse(viewModel.hasChanges, "初期状態では変更なし")
        
        // When: 優先度をhighに変更
        viewModel.setPriority(.high)
        
        // Then: ViewModelが「変更済み」状態になり、保存ボタンが活性化する
        XCTAssertEqual(viewModel.priority, .high, "優先度がhighになる")
        XCTAssertTrue(viewModel.hasChanges, "変更ありの状態になる")
        XCTAssertTrue(viewModel.shouldEnableSaveButton, "保存ボタンが活性化される")
    }
    
    func test_トグルをONにしてからOFFに戻すとViewModelが初期状態に戻り保存ボタンが非活性になる() {
        // Given: 初期状態のViewModel（完了=false）
        XCTAssertFalse(viewModel.isCompleted, "初期状態では未完了")
        XCTAssertFalse(viewModel.hasChanges, "初期状態では変更なし")
        
        // When: 完了状態をtrue→falseに変更
        viewModel.setCompleted(true)
        XCTAssertTrue(viewModel.hasChanges, "一度変更すると変更ありの状態")
        
        viewModel.setCompleted(false) // 元の値に戻す
        
        // Then: ViewModelが「初期状態」に戻り、保存ボタンが非活性になる
        XCTAssertFalse(viewModel.isCompleted, "完了状態がfalseに戻る")
        XCTAssertFalse(viewModel.hasChanges, "初期状態に戻ったので変更なしになる")
        XCTAssertFalse(viewModel.shouldEnableSaveButton, "保存ボタンが非活性になる")
    }
    
    // MARK: - Additional Strategic Tests
    
    func test_複数項目を変更してから全て元に戻すと初期状態になる() {
        // Given: 初期状態
        let originalCompleted = viewModel.isCompleted
        let originalPriority = viewModel.priority
        
        // When: 複数項目を変更
        viewModel.setCompleted(!originalCompleted)
        viewModel.setPriority(.high)
        XCTAssertTrue(viewModel.hasChanges, "変更後は変更ありの状態")
        
        // そして全て元に戻す
        viewModel.setCompleted(originalCompleted)
        viewModel.setPriority(originalPriority)
        
        // Then: 初期状態に戻る
        XCTAssertFalse(viewModel.hasChanges, "全て元に戻したら変更なしの状態")
        XCTAssertFalse(viewModel.shouldEnableSaveButton, "保存ボタンが非活性")
    }
    
    func test_タイトル変更でも変更状態が反映される() {
        // Given: 初期状態
        let originalTitle = viewModel.title
        
        // When: タイトルを変更
        viewModel.setTitle("新しいタイトル")
        
        // Then: 変更状態になる
        XCTAssertNotEqual(viewModel.title, originalTitle, "タイトルが変更される")
        XCTAssertTrue(viewModel.hasChanges, "変更ありの状態になる")
        XCTAssertTrue(viewModel.shouldEnableSaveButton, "保存ボタンが活性化される")
    }
}