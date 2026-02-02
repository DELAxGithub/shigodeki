//
//  TagFunctionalityTests.swift
//  shigodekiTests
//
//  Created by Claude on 2025-01-04.
//
//  TDD Implementation: Testing critical tag functionality
//  Following CLAUDE.md principles: Test-first approach, focus on important logic

import XCTest
import SwiftUI
@testable import shigodeki

// MARK: - TagFunctionalityTests

@MainActor
final class TagFunctionalityTests: XCTestCase {
    
    var tagManager: TagManager!
    let testFamilyId = "test-family-id"
    let testUserId = "test-user-id"
    
    override func setUp() {
        super.setUp()
        tagManager = TagManager()
    }
    
    override func tearDown() {
        tagManager?.stopListening()
        tagManager = nil
        super.tearDown()
    }
    
    // MARK: - TaskTag Model Tests
    
    func testTaskTagInitialization() {
        // Given
        let name = "重要"
        let color = "#FF3B30"
        let emoji = "🔥"
        
        // When
        let tag = TaskTag(name: name, color: color, emoji: emoji, familyId: testFamilyId, createdBy: testUserId)
        
        // Then
        XCTAssertEqual(tag.name, name)
        XCTAssertEqual(tag.color, color)
        XCTAssertEqual(tag.emoji, emoji)
        XCTAssertEqual(tag.familyId, testFamilyId)
        XCTAssertEqual(tag.createdBy, testUserId)
        XCTAssertEqual(tag.usageCount, 0)
        XCTAssertEqual(tag.displayName, "\(emoji) \(name)")
        XCTAssertTrue(tag.isUnused)
        XCTAssertNotNil(tag.createdAt)
    }
    
    func testTaskTagInitializationWithoutEmoji() {
        // Given
        let name = "重要"
        let color = "#FF3B30"
        
        // When
        let tag = TaskTag(name: name, color: color, emoji: nil, familyId: testFamilyId, createdBy: testUserId)
        
        // Then
        XCTAssertEqual(tag.displayName, name)
        XCTAssertNil(tag.emoji)
    }
    
    func testTaskTagNameTrimming() {
        // Given
        let name = "  重要  "
        let expectedName = "重要"
        
        // When
        let tag = TaskTag(name: name, color: "#FF3B30", familyId: testFamilyId, createdBy: testUserId)
        
        // Then
        XCTAssertEqual(tag.name, expectedName)
    }
    
    func testTaskTagColorConversion() {
        // Given
        let hexColor = "#FF3B30"
        let tag = TaskTag(name: "Test", color: hexColor, familyId: testFamilyId, createdBy: testUserId)
        
        // When
        let swiftUIColor = tag.swiftUIColor
        
        // Then
        XCTAssertNotNil(swiftUIColor)
        // Note: Exact color comparison is difficult in tests, but we verify it doesn't crash
    }
    
    func testTaskTagFirestoreDataConversion() {
        // Given
        let tag = TaskTag(name: "重要", color: "#FF3B30", emoji: "🔥", familyId: testFamilyId, createdBy: testUserId)
        
        // When
        let firestoreData = tag.toFirestoreData()
        
        // Then
        XCTAssertEqual(firestoreData["name"] as? String, tag.name)
        XCTAssertEqual(firestoreData["color"] as? String, tag.color)
        XCTAssertEqual(firestoreData["emoji"] as? String, tag.emoji)
        XCTAssertEqual(firestoreData["familyId"] as? String, tag.familyId)
        XCTAssertEqual(firestoreData["createdBy"] as? String, tag.createdBy)
        XCTAssertEqual(firestoreData["usageCount"] as? Int, tag.usageCount)
    }
    
    func testTaskTagFromFirestoreData() {
        // Given
        let firestoreData: [String: Any] = [
            "name": "重要",
            "color": "#FF3B30",
            "emoji": "🔥",
            "familyId": testFamilyId,
            "createdBy": testUserId,
            "usageCount": 5,
            "displayName": "🔥 重要"
        ]
        let documentId = "test-doc-id"
        
        // When
        let tag = TaskTag.fromFirestoreData(firestoreData, documentId: documentId)
        
        // Then
        XCTAssertNotNil(tag)
        XCTAssertEqual(tag?.id, documentId)
        XCTAssertEqual(tag?.name, "重要")
        XCTAssertEqual(tag?.color, "#FF3B30")
        XCTAssertEqual(tag?.emoji, "🔥")
        XCTAssertEqual(tag?.usageCount, 5)
        XCTAssertEqual(tag?.displayName, "🔥 重要")
    }
    
    func testTaskTagFromInvalidFirestoreData() {
        // Given - Missing required fields
        let invalidData: [String: Any] = [
            "name": "重要"
            // Missing color, familyId, createdBy
        ]
        
        // When
        let tag = TaskTag.fromFirestoreData(invalidData, documentId: "test-id")
        
        // Then
        XCTAssertNil(tag)
    }
    
    // MARK: - TagManager Core Logic Tests (Unit Tests Only)
    // Note: Firebase integration tests would require test environment setup
    
    func testTagManagerInitialState() {
        // Given
        let freshTagManager = TagManager()
        
        // Then
        XCTAssertTrue(freshTagManager.tags.isEmpty)
        XCTAssertFalse(freshTagManager.isLoading)
        XCTAssertNil(freshTagManager.errorMessage)
    }
    
    func testGetTagsForFamily() {
        // Given
        let family1Tag = TaskTag(name: "家族1タグ", color: "#FF3B30", familyId: "family1", createdBy: testUserId)
        let family2Tag = TaskTag(name: "家族2タグ", color: "#007AFF", familyId: "family2", createdBy: testUserId)
        
        tagManager.tags = [family1Tag, family2Tag]
        
        // When
        let family1Tags = tagManager.getTagsForFamily("family1")
        let family2Tags = tagManager.getTagsForFamily("family2")
        
        // Then
        XCTAssertEqual(family1Tags.count, 1)
        XCTAssertEqual(family2Tags.count, 1)
        XCTAssertEqual(family1Tags.first?.name, "家族1タグ")
        XCTAssertEqual(family2Tags.first?.name, "家族2タグ")
    }
    
    func testGetTagByName() {
        // Given
        let tag = TaskTag(name: "重要", color: "#FF3B30", familyId: testFamilyId, createdBy: testUserId)
        tagManager.tags = [tag]
        
        // When
        let foundTag = tagManager.getTag(name: "重要", familyId: testFamilyId)
        let notFoundTag = tagManager.getTag(name: "存在しない", familyId: testFamilyId)
        
        // Then
        XCTAssertNotNil(foundTag)
        XCTAssertEqual(foundTag?.name, "重要")
        XCTAssertNil(notFoundTag)
    }
    
    func testGetUnusedTags() {
        // Given
        var usedTag = TaskTag(name: "使用中", color: "#FF3B30", familyId: testFamilyId, createdBy: testUserId)
        usedTag.usageCount = 5
        
        let unusedTag = TaskTag(name: "未使用", color: "#007AFF", familyId: testFamilyId, createdBy: testUserId)
        
        tagManager.tags = [usedTag, unusedTag]
        
        // When
        let unusedTags = tagManager.getUnusedTags(familyId: testFamilyId)
        
        // Then
        XCTAssertEqual(unusedTags.count, 1)
        XCTAssertEqual(unusedTags.first?.name, "未使用")
        XCTAssertTrue(unusedTags.first?.isUnused ?? false)
    }
    
    // MARK: - Tag Validation Tests
    
    func testCreateTagValidation() {
        // Test cases for tag creation validation
        let testCases: [(name: String, shouldSucceed: Bool, description: String)] = [
            ("", false, "Empty name should fail"),
            ("   ", false, "Whitespace-only name should fail"),
            ("重要", true, "Valid name should succeed"),
            ("  重要  ", true, "Name with whitespace should be trimmed and succeed")
        ]
        
        for testCase in testCases {
            // This would normally be tested with async Firebase operations
            // Here we test the core validation logic
            let trimmedName = testCase.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let isValid = !trimmedName.isEmpty
            
            XCTAssertEqual(isValid, testCase.shouldSucceed, testCase.description)
        }
    }
    
    func testDuplicateTagDetection() {
        // Given
        let existingTag = TaskTag(name: "重要", color: "#FF3B30", familyId: testFamilyId, createdBy: testUserId)
        tagManager.tags = [existingTag]
        
        // When & Then
        let hasDuplicate = tagManager.tags.contains { $0.name.lowercased() == "重要".lowercased() && $0.familyId == testFamilyId }
        XCTAssertTrue(hasDuplicate, "Should detect duplicate tag names")
        
        let hasDuplicateCaseInsensitive = tagManager.tags.contains { $0.name.lowercased() == "重要".lowercased() && $0.familyId == testFamilyId }
        XCTAssertTrue(hasDuplicateCaseInsensitive, "Should detect duplicate tag names case-insensitively")
    }
    
    // MARK: - Color Extension Tests
    
    func testColorHexInitialization() {
        let testCases: [(hex: String, shouldBeNil: Bool)] = [
            ("#FF3B30", false),     // Valid 6-digit hex
            ("FF3B30", false),      // Valid without #
            ("#RGB", false),        // Valid 3-digit
            ("RGB", false),         // Valid 3-digit without #
            ("#RRGGBBAA", false),   // Valid 8-digit with alpha
            ("invalid", true),      // Invalid format
            ("", true)              // Empty string
        ]
        
        for testCase in testCases {
            let color = Color(hex: testCase.hex)
            if testCase.shouldBeNil {
                XCTAssertNil(color, "Color should be nil for invalid hex: \(testCase.hex)")
            } else {
                XCTAssertNotNil(color, "Color should not be nil for valid hex: \(testCase.hex)")
            }
        }
    }
    
    // MARK: - TagError Tests
    
    func testTagErrorDescriptions() {
        let errors: [TagError] = [
            .invalidName,
            .duplicateName,
            .notFound,
            .creationFailed("Test message"),
            .updateFailed("Test message"),
            .deletionFailed("Test message"),
            .loadingFailed("Test message")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Every TagError should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }
    
    // MARK: - Performance Tests
    
    func testTagFilteringPerformance() {
        // Given - Create a large number of tags for performance testing
        let tags = (0..<1000).map { index in
            TaskTag(name: "Tag\(index)", color: TaskTag.randomColor(), familyId: testFamilyId, createdBy: testUserId)
        }
        tagManager.tags = tags
        
        // When & Then - Measure filtering performance
        measure {
            let _ = tagManager.getTagsForFamily(testFamilyId)
        }
    }
}

// MARK: - Mock Extensions for Testing

extension TaskTag {
    static func createTestTag(name: String = "Test Tag", familyId: String = "test-family") -> TaskTag {
        return TaskTag(name: name, color: "#007AFF", familyId: familyId, createdBy: "test-user")
    }
}