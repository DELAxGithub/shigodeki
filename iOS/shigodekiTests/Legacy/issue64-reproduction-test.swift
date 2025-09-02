#!/usr/bin/env swift

//
// Issue #64 Reproduction Test: プロジェクト設定画面で作成者がID文字列ではなく表示名で表示されない
//
// TDD RED Phase: 作成者表示名取得機能のバグを検証
// Expected: FAIL (creator shows as ID instead of display name)
//

import Foundation

print("🔴 RED Phase: Issue #64 作成者表示名問題の検証")
print("========================================================")

// Mock User data structure
struct MockUser {
    let id: String
    let displayName: String
    let email: String
}

// Mock Project with creator ID
struct MockProject {
    let id: String
    let name: String
    let createdBy: String  // User ID
    let createdAt: Date
}

// Mock User Manager to simulate user data fetching
class MockUserManager {
    private let users: [String: MockUser] = [
        "user_abc123def456": MockUser(id: "user_abc123def456", displayName: "田中太郎", email: "tanaka@example.com"),
        "user_xyz789ghi012": MockUser(id: "user_xyz789ghi012", displayName: "佐藤花子", email: "sato@example.com"),
        "user_missing": MockUser(id: "user_missing", displayName: "存在しないユーザー", email: "missing@example.com")
    ]
    
    var fetchCallCount = 0
    
    func getUserById(_ userId: String) async throws -> MockUser? {
        fetchCallCount += 1
        print("  📡 UserManager.getUserById(\"\(userId)\") called")
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let user = users[userId]
        if let user = user {
            print("    ✅ Found user: \"\(user.displayName)\"")
        } else {
            print("    ❌ User not found")
        }
        return user
    }
}

// Test Case: Creator Display Name Resolution
struct Issue64ReproductionTest {
    
    func testCreatorDisplayNameFetching() async {
        print("🧪 Test Case: Creator Display Name Fetching")
        
        // Arrange
        let project = MockProject(
            id: "project_123",
            name: "テストプロジェクト",
            createdBy: "user_abc123def456",
            createdAt: Date()
        )
        let userManager = MockUserManager()
        
        print("  プロジェクト名: \(project.name)")
        print("  作成者ID: \(project.createdBy)")
        print("  期待する表示名: 田中太郎")
        
        // Act: Fetch creator's display name
        do {
            let creator = try await userManager.getUserById(project.createdBy)
            
            // Assert
            if let creator = creator {
                print("  取得した表示名: \(creator.displayName)")
                print("  UserManager呼び出し回数: \(userManager.fetchCallCount)")
                
                let correctDisplayName = creator.displayName == "田中太郎"
                let fetchCalled = userManager.fetchCallCount == 1
                
                print("  Correct display name: \(correctDisplayName ? "✅" : "❌")")
                print("  Fetch called once: \(fetchCalled ? "✅" : "❌")")
                
                if correctDisplayName && fetchCalled {
                    print("  ✅ PASS: Creator display name fetching works correctly")
                } else {
                    print("  ❌ FAIL: Creator display name fetching is broken")
                }
            } else {
                print("  ❌ FAIL: Creator not found")
            }
        } catch {
            print("  ❌ FAIL: Error fetching creator: \(error)")
        }
    }
    
    func testProjectSettingsViewDisplayLogic() async {
        print("\n🧪 Test Case: Project Settings View Display Logic")
        
        // Arrange
        let project = MockProject(
            id: "project_456",
            name: "設定テストプロジェクト",
            createdBy: "user_xyz789ghi012",
            createdAt: Date()
        )
        let userManager = MockUserManager()
        
        // State variables that would exist in the view
        var creatorDisplayName = project.createdBy  // Initially shows ID (the bug)
        var isLoadingCreator = false
        
        print("  初期表示: \(creatorDisplayName) (これが問題)")
        print("  期待する表示: 佐藤花子")
        
        // Act: Simulate the view loading creator name
        isLoadingCreator = true
        do {
            let creator = try await userManager.getUserById(project.createdBy)
            if let creator = creator {
                creatorDisplayName = creator.displayName
            }
            isLoadingCreator = false
        } catch {
            print("  ❌ Error: \(error)")
            isLoadingCreator = false
        }
        
        // Assert
        print("  最終表示: \(creatorDisplayName)")
        print("  ローディング状態: \(isLoadingCreator)")
        
        let showsDisplayName = creatorDisplayName == "佐藤花子"
        let notLoading = !isLoadingCreator
        let notShowingUserId = !creatorDisplayName.contains("user_")
        
        print("  Shows display name: \(showsDisplayName ? "✅" : "❌")")
        print("  Not loading: \(notLoading ? "✅" : "❌")")
        print("  Not showing user ID: \(notShowingUserId ? "✅" : "❌")")
        
        if showsDisplayName && notLoading && notShowingUserId {
            print("  ✅ PASS: Project settings view logic works correctly")
        } else {
            print("  ❌ FAIL: Project settings view logic is broken")
            print("    - Shows display name: \(showsDisplayName)")
            print("    - Not loading: \(notLoading)")
            print("    - Not showing user ID: \(notShowingUserId)")
        }
    }
    
    func testUserNotFoundHandling() async {
        print("\n🧪 Test Case: User Not Found Error Handling")
        
        // Arrange
        let project = MockProject(
            id: "project_789",
            name: "エラーテストプロジェクト",
            createdBy: "user_nonexistent",
            createdAt: Date()
        )
        let userManager = MockUserManager()
        
        var creatorDisplayName = project.createdBy
        
        print("  存在しないユーザーID: \(project.createdBy)")
        print("  初期表示: \(creatorDisplayName)")
        
        // Act: Try to fetch non-existent user
        do {
            let creator = try await userManager.getUserById(project.createdBy)
            if let creator = creator {
                creatorDisplayName = creator.displayName
            } else {
                // Handle user not found case
                creatorDisplayName = "不明なユーザー"
            }
        } catch {
            creatorDisplayName = "取得エラー"
        }
        
        // Assert
        print("  エラー処理後の表示: \(creatorDisplayName)")
        
        let handlesError = creatorDisplayName != project.createdBy
        let showsUserFriendlyMessage = creatorDisplayName == "不明なユーザー"
        
        print("  Handles error: \(handlesError ? "✅" : "❌")")
        print("  Shows user-friendly message: \(showsUserFriendlyMessage ? "✅" : "❌")")
        
        if handlesError && showsUserFriendlyMessage {
            print("  ✅ PASS: Error handling works correctly")
        } else {
            print("  ❌ FAIL: Error handling needs improvement")
        }
    }
}

// Execute Tests
print("\n🚨 実行中: Issue #64 バグ再現テスト")
print("Expected: ユーザー情報取得機能は正常だが、UI側で実装されていない可能性")
print("If tests PASS: バグはView層での実装不備")
print("If tests FAIL: UserManager層の問題")

let testSuite = Issue64ReproductionTest()

print("\n" + String(repeating: "=", count: 50))

// Execute async tests synchronously
func runAsyncTest() {
    let semaphore = DispatchSemaphore(value: 0)
    
    Task {
        await testSuite.testCreatorDisplayNameFetching()
        await testSuite.testProjectSettingsViewDisplayLogic()
        await testSuite.testUserNotFoundHandling()
        
        print("\n🔴 RED Phase Results:")
        print("- このテストがPASSする場合、バグはUI実装層にある")
        print("- バグの原因候補:")
        print("  1. View側でユーザー名取得処理が未実装")
        print("  2. 非同期データ取得の処理不備")
        print("  3. エラーハンドリングの不備")
        print("  4. ローディング状態の管理不備")
        print("  5. UserManager呼び出しが実装されていない")
        
        print("\n🎯 Next: ProjectSettingsView.swiftの実装確認とバグ修正")
        print("========================================================")
        
        semaphore.signal()
    }
    
    semaphore.wait()
}

runAsyncTest()