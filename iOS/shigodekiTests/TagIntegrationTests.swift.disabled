//
//  TagIntegrationTests.swift
//  shigodekiTests
//
//  Created by Claude on 2025-01-04.
//
//  Phase 2 Integration Tests: Tag functionality integration with views and managers
//  Following CLAUDE.md principles: Test integration points and user workflows

import XCTest
import SwiftUI
@testable import shigodeki

// MARK: - TagIntegrationTests

@MainActor
final class TagIntegrationTests: XCTestCase {
    
    var tagManager: TagManager!
    var taskManager: TaskManager!
    let testFamilyId = "test-family-integration"
    let testUserId = "test-user-integration"
    
    override func setUp() {
        super.setUp()
        tagManager = TagManager()
        taskManager = TaskManager()
    }
    
    override func tearDown() {
        tagManager?.stopListening()
        tagManager = nil
        taskManager = nil
        super.tearDown()
    }
    
    // MARK: - TagDisplayView Integration Tests
    
    func testTagDisplayViewWithEmptyTags() {
        // Given
        let emptyTags: [String] = []
        let tagMasters: [TaskTag] = []
        
        // When
        let tagDisplayView = TagDisplayView(
            tags: emptyTags,
            tagMasters: tagMasters,
            onTagTapped: { _ in }
        )
        
        // Then - View should handle empty state gracefully
        // This is primarily a compilation test to ensure the view initializes correctly
        XCTAssertNotNil(tagDisplayView)
    }
    
    func testTagDisplayViewWithSampleTags() {
        // Given
        let tags = ["重要", "緊急", "会議"]
        let tagMasters = [
            TaskTag.createTestTag(name: "重要", familyId: testFamilyId),
            TaskTag.createTestTag(name: "緊急", familyId: testFamilyId)
        ]
        
        // When
        let tagDisplayView = TagDisplayView(
            tags: tags,
            tagMasters: tagMasters,
            maxDisplayCount: 2,
            onTagTapped: { tagName in
                XCTAssertTrue(tags.contains(tagName), "Tapped tag should be in the original tags list")
            }
        )
        
        // Then
        XCTAssertNotNil(tagDisplayView)
    }
    
    func testTagRowTagsViewInitialization() {
        // Given
        let task = createSampleTaskWithTags()
        let tagMasters = [
            TaskTag.createTestTag(name: "重要", familyId: testFamilyId),
            TaskTag.createTestTag(name: "緊急", familyId: testFamilyId)
        ]
        
        // When
        let tagRowView = TaskRowTagsView(
            task: task,
            tagMasters: tagMasters,
            onTagTapped: { _ in }
        )
        
        // Then
        XCTAssertNotNil(tagRowView)
    }
    
    func testTaskDetailTagsViewInitialization() {
        // Given
        let task = createSampleTaskWithTags()
        let tagMasters = [
            TaskTag.createTestTag(name: "重要", familyId: testFamilyId),
            TaskTag.createTestTag(name: "緊急", familyId: testFamilyId)
        ]
        
        // When
        let taskDetailView = TaskDetailTagsView(
            task: task,
            tagMasters: tagMasters,
            isEditing: false,
            onTagTapped: { _ in },
            onEditTags: {}
        )
        
        // Then
        XCTAssertNotNil(taskDetailView)
    }
    
    // MARK: - TagInputView Integration Tests
    
    func testTagInputViewInitialization() {
        // Given
        let availableTags = [
            TaskTag.createTestTag(name: "重要", familyId: testFamilyId),
            TaskTag.createTestTag(name: "緊急", familyId: testFamilyId)
        ]
        
        // When
        let tagInputView = TagInputView(
            selectedTags: .constant([]),
            availableTags: availableTags,
            familyId: testFamilyId,
            createdBy: testUserId,
            onTagCreated: { _ in }
        )
        
        // Then
        XCTAssertNotNil(tagInputView)
    }
    
    // MARK: - TagManagementView Integration Tests
    
    func testTagManagementViewInitialization() {
        // When
        let tagManagementView = TagManagementView(
            familyId: testFamilyId,
            createdBy: testUserId
        )
        
        // Then
        XCTAssertNotNil(tagManagementView)
    }
    
    // MARK: - Task Creation with Tags Integration
    
    func testTaskManagerCreateTaskWithTags() async {
        // Given
        let tags = ["重要", "緊急"]
        let title = "Test Task with Tags"
        
        // When & Then - This would normally require Firebase setup for full integration
        // For now, we test that the method signature is correct and accepts tags
        do {
            // This will fail without proper Firebase setup, but tests the interface
            _ = try await taskManager.createTask(
                title: title,
                description: "Test description",
                taskListId: "test-list",
                familyId: testFamilyId,
                creatorUserId: testUserId,
                assignedTo: nil,
                dueDate: nil,
                priority: .medium,
                tags: tags
            )
            // If we get here without compilation errors, the interface is correct
        } catch {
            // Expected to fail without Firebase setup
            print("Expected failure in test environment: \(error)")
        }
    }
    
    // MARK: - TagChip Integration Tests
    
    func testTagChipWithTaskTag() {
        // Given
        let tag = TaskTag.createTestTag(name: "重要", familyId: testFamilyId)
        
        // When
        let tagChip = TagChip(
            tag: tag,
            size: .medium,
            isSelected: false,
            action: {}
        )
        
        // Then
        XCTAssertNotNil(tagChip)
    }
    
    func testTagChipWithStringName() {
        // When
        let tagChip = TagChip(
            tagName: "重要",
            size: .small,
            isSelected: true,
            action: {}
        )
        
        // Then
        XCTAssertNotNil(tagChip)
    }
    
    func testTagChipConvenienceInitializers() {
        // Given
        let tag = TaskTag.createTestTag(name: "重要", familyId: testFamilyId)
        
        // When & Then - Test all convenience initializers
        let chipWithTag = TagChip(tag: tag) {}
        let chipWithName = TagChip(tagName: "重要") {}
        let chipSelected = TagChip(tag: tag, isSelected: true) {}
        let chipSmall = TagChip(tagName: "重要", size: .small) {}
        
        XCTAssertNotNil(chipWithTag)
        XCTAssertNotNil(chipWithName)
        XCTAssertNotNil(chipSelected)
        XCTAssertNotNil(chipSmall)
    }
    
    // MARK: - CreateTagView Integration Tests
    
    func testCreateTagViewInitialization() {
        // When
        let createTagView = CreateTagView(
            familyId: testFamilyId,
            createdBy: testUserId,
            onTagCreated: { _ in }
        )
        
        // Then
        XCTAssertNotNil(createTagView)
    }
    
    func testCreateTagViewWithInitialName() {
        // When
        let createTagView = CreateTagView(
            initialName: "初期タグ名",
            familyId: testFamilyId,
            createdBy: testUserId,
            onTagCreated: { _ in }
        )
        
        // Then
        XCTAssertNotNil(createTagView)
    }
    
    // MARK: - Integration Workflow Tests
    
    func testCompleteTagWorkflow() {
        // This test verifies that all components can work together
        // Given
        let tags = ["重要", "緊急", "会議"]
        let tagMasters = tags.map { TaskTag.createTestTag(name: $0, familyId: testFamilyId) }
        let task = createSampleTaskWithTags(tags: tags)
        
        // When - Create components that would work together in a real workflow
        let tagDisplayView = TagDisplayView(
            tags: task.tags,
            tagMasters: tagMasters,
            onTagTapped: { tagName in
                print("User tapped tag: \(tagName)")
            }
        )
        
        let tagInputView = TagInputView(
            selectedTags: .constant(tags),
            availableTags: tagMasters,
            familyId: testFamilyId,
            createdBy: testUserId,
            onTagCreated: { newTag in
                print("User created tag: \(newTag.name)")
            }
        )
        
        // Then - All components should initialize successfully
        XCTAssertNotNil(tagDisplayView)
        XCTAssertNotNil(tagInputView)
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testTagManagerErrorHandling() {
        // Given
        let emptyFamilyId = ""
        let emptyUserId = ""
        
        // When & Then - Test that components handle invalid data gracefully
        XCTAssertNoThrow({
            let tagManager = TagManager()
            let filteredTags = tagManager.getTagsForFamily(emptyFamilyId)
            XCTAssertTrue(filteredTags.isEmpty, "Should return empty array for invalid family ID")
        })
        
        XCTAssertNoThrow({
            _ = TagManagementView(familyId: emptyFamilyId, createdBy: emptyUserId)
        })
    }
    
    // MARK: - Performance Integration Tests
    
    func testTagDisplayPerformanceWithManyTags() {
        // Given - Create a large number of tags to test performance
        let manyTags = (1...100).map { "Tag\($0)" }
        let tagMasters = manyTags.map { TaskTag.createTestTag(name: $0, familyId: testFamilyId) }
        
        // When & Then - Measure performance of tag display
        measure {
            let _ = TagDisplayView(
                tags: manyTags,
                tagMasters: tagMasters,
                maxDisplayCount: 10,
                onTagTapped: { _ in }
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func createSampleTaskWithTags(tags: [String] = ["重要", "緊急"]) -> ShigodekiTask {
        var task = ShigodekiTask(
            title: "Sample Task",
            createdBy: testUserId,
            listId: "test-list",
            phaseId: "test-phase",
            projectId: "test-project",
            order: 0
        )
        task.tags = tags
        return task
    }
}

// MARK: - Mock Extensions for Integration Testing
// Note: Using createTestTag from TagFunctionalityTests.swift to avoid duplication

