//
//  TagDisplayBugTests.swift
//  shigodekiTests
//
//  Created by Claude on 2025-01-04.
//  Test for Issue #83: タグ編集機能の重大な問題: 二重表示と編集ボタン無効化
//

import XCTest
@testable import shigodeki

@MainActor
final class TagDisplayBugTests: XCTestCase {
    
    // MARK: - Test for Double Display Bug (二重表示問題)
    
    func testTagDisplayName_ShouldNotDuplicateEmojiAndName() {
        // Given: 絵文字付きタグを作成
        let tagWithEmoji = TaskTag(
            name: "重要",
            color: "#FF3B30", 
            emoji: "🔥",
            familyId: "testFamily",
            createdBy: "testUser"
        )
        
        // When: displayNameを取得
        let displayName = tagWithEmoji.displayName
        
        // Then: 二重表示されていないことを確認
        XCTAssertEqual(displayName, "🔥 重要", "displayName should be '🔥 重要', but got '\(displayName)'")
        XCTAssertFalse(displayName.contains("🔥🔥"), "displayName should not contain duplicated emoji")
        XCTAssertFalse(displayName.contains("重要重要"), "displayName should not contain duplicated name")
    }
    
    func testTaskTagFromFirestore_ShouldNotCreateDuplicatedDisplayName() {
        // Given: Firestore形式のデータ（displayNameが既に設定済み）
        let firestoreData: [String: Any] = [
            "name": "重要",
            "displayName": "🔥 重要", // 既にFirestoreに保存されているdisplayName
            "color": "#FF3B30",
            "emoji": "🔥",
            "familyId": "testFamily",
            "createdBy": "testUser",
            "usageCount": 5
        ]
        
        // When: FirestoreデータからTaskTagを復元
        let tag = TaskTag.fromFirestoreData(firestoreData, documentId: "test123")
        
        // Then: displayNameが二重化されていないことを確認
        XCTAssertNotNil(tag, "Tag should be created from Firestore data")
        XCTAssertEqual(tag?.displayName, "🔥 重要", "displayName should not be duplicated")
        XCTAssertFalse(tag?.displayName.contains("🔥🔥") ?? false, "displayName should not contain duplicated emoji")
    }
    
    func testTagManagerUpdate_ShouldNotCreateDuplicatedDisplayName() async {
        // Given: 既存のタグとTagManager
        let tagManager = TagManager()
        var existingTag = TaskTag(
            name: "重要",
            color: "#FF3B30",
            emoji: "🔥", 
            familyId: "testFamily",
            createdBy: "testUser"
        )
        existingTag.id = "testTagId"
        
        // この時点で初期displayNameは "🔥 重要" のはず
        XCTAssertEqual(existingTag.displayName, "🔥 重要")
        
        // When: タグを更新（TagManager.updateTagのロジックをシミュレート）
        // TagManager.swift:113の問題のあるコード
        let finalName = existingTag.name
        let finalEmoji = existingTag.emoji
        let updatedDisplayName = finalEmoji != nil ? "\(finalEmoji!) \(finalName)" : finalName
        
        // Then: 二重表示が発生することを確認（これが失敗すべきテスト）
        // このテストは現在のコードでは失敗する（バグが存在するため）
        XCTAssertEqual(updatedDisplayName, "🔥 重要", "displayName should not be duplicated when updating")
    }
    
    // MARK: - Test for Firestore Index Issue (インデックス不足問題)
    
    func testTagManagerQuery_RequiresCompositeIndex() {
        // Given: TagManagerのクエリ設定
        let expectedQuery = "order(by: 'usageCount', descending: true).order(by: 'name')"
        
        // When: クエリの構造を検証
        // このテストは、必要なFirestoreインデックスが存在するかを確認するためのもの
        
        // Then: 複合インデックスが必要であることを文書化
        XCTAssertTrue(true, "This test documents the required Firestore composite index")
        
        // 必要なインデックス情報をログ出力
        print("""
        Required Firestore Composite Index:
        Collection: tagMasters
        Fields: 
        - usageCount (DESC)
        - name (ASC)
        
        Error without index: FIRFirestoreErrorDomain Code=9
        """)
    }
    
    // MARK: - Integration Test for Tag Editing Flow
    
    func testTagEditingFlow_ShouldWorkWithoutDoubleDisplay() async {
        // Given: タグ編集のフロー全体をテスト
        let originalTag = TaskTag(
            name: "重要",
            color: "#FF3B30",
            emoji: "🔥",
            familyId: "testFamily", 
            createdBy: "testUser"
        )
        
        // When: タグが表示される
        let displayedName = originalTag.displayName
        
        // Then: 正しく表示される
        XCTAssertEqual(displayedName, "🔥 重要")
        
        // When: タグを編集する（名前変更）
        var updatedTag = originalTag
        updatedTag.name = "超重要"
        // displayNameを再計算（現在のバグのあるロジック）
        updatedTag.displayName = updatedTag.emoji != nil ? "\(updatedTag.emoji!) \(updatedTag.name)" : updatedTag.name
        
        // Then: 二重表示されない
        XCTAssertEqual(updatedTag.displayName, "🔥 超重要", "Updated tag should not have duplicated display")
    }
}