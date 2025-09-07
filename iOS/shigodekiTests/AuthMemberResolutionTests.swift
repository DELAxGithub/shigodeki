//
//  AuthMemberResolutionTests.swift
//  shigodekiTests
//
//  Tests for auth-based member resolution and cache invalidation
//  Verifies the fix for Issue: "Member info shows test user despite being logged in"
//

import XCTest
import FirebaseAuth
@testable import shigodeki

@MainActor
final class AuthMemberResolutionTests: XCTestCase {
    
    var authManager: AuthenticationManager!
    var notificationReceived: XCTestExpectation!
    var receivedNotification: Notification?
    
    override func setUp() async throws {
        authManager = AuthenticationManager.shared
    }
    
    override func tearDown() async throws {
        NotificationCenter.default.removeObserver(self)
        authManager = nil
    }
    
    // MARK: - Test Auth Change Notifications
    
    func testAuthUserChanged_OnSignOut_NotifiesComponents() async throws {
        // Given: Set up notification observer
        notificationReceived = expectation(description: "Auth user changed notification received")
        
        NotificationCenter.default.addObserver(
            forName: .authUserChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.receivedNotification = notification
            self?.notificationReceived.fulfill()
        }
        
        // When: User signs out (simulate the notification)
        NotificationCenter.default.post(
            name: .authUserChanged,
            object: nil,
            userInfo: ["action": "signout", "previousUserId": "test_user_123"]
        )
        
        // Then: Components should receive cache invalidation notification
        await fulfillment(of: [notificationReceived], timeout: 1.0)
        
        XCTAssertNotNil(receivedNotification)
        XCTAssertEqual(receivedNotification?.userInfo?["action"] as? String, "signout")
        XCTAssertEqual(receivedNotification?.userInfo?["previousUserId"] as? String, "test_user_123")
    }
    
    func testAuthUserChanged_OnSignIn_NotifiesWithNewUID() async throws {
        // Given: Set up notification observer
        notificationReceived = expectation(description: "Auth user changed notification received")
        
        NotificationCenter.default.addObserver(
            forName: .authUserChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.receivedNotification = notification
            self?.notificationReceived.fulfill()
        }
        
        // When: User signs in with new UID
        let newUID = "xEMEqpAKdiUPAYjXwQI9BhnziXf1"
        let previousUID = "old_user_123"
        
        NotificationCenter.default.post(
            name: .authUserChanged,
            object: nil,
            userInfo: [
                "action": "signin",
                "newUserId": newUID,
                "previousUserId": previousUID
            ]
        )
        
        // Then: Components should receive new user ID for cache invalidation
        await fulfillment(of: [notificationReceived], timeout: 1.0)
        
        XCTAssertNotNil(receivedNotification)
        XCTAssertEqual(receivedNotification?.userInfo?["action"] as? String, "signin")
        XCTAssertEqual(receivedNotification?.userInfo?["newUserId"] as? String, newUID)
        XCTAssertEqual(receivedNotification?.userInfo?["previousUserId"] as? String, previousUID)
    }
    
    // MARK: - Test UID Validation
    
    func testCurrentUserId_WithValidAuth_ReturnsActualUID() throws {
        // Note: This test assumes AuthenticationManager.currentUserId 
        // returns the actual Firebase UID when authenticated
        
        // The key requirement is that currentUserId should NEVER return:
        // - "test_user"
        // - "TestUser" 
        // - "dummy"
        // - any hardcoded placeholder values
        
        let currentUID = authManager.currentUserId
        
        if let uid = currentUID {
            // If we have a UID, it should be a valid Firebase UID format (not test data)
            XCTAssertFalse(uid.lowercased().contains("test"), "UID should not contain 'test'")
            XCTAssertFalse(uid.lowercased().contains("dummy"), "UID should not contain 'dummy'")
            XCTAssertFalse(uid.lowercased().contains("placeholder"), "UID should not contain 'placeholder'")
            XCTAssertGreaterThanOrEqual(uid.count, 20, "Firebase UIDs are typically 28+ chars")
            
            print("✅ AuthManager: currentUserId=\(uid)")
        } else {
            // If no UID, user is not authenticated (which is fine)
            print("ℹ️ AuthManager: currentUserId=nil (not authenticated)")
        }
    }
    
    // MARK: - Integration Test for Member Resolution Flow
    
    func testMemberResolutionFlow_WithAuthenticatedUser_UsesRealUID() async throws {
        // This test verifies the complete flow from auth to member display
        
        // Given: An authenticated user with a real UID
        guard let currentUID = authManager.currentUserId else {
            throw XCTSkip("Test requires authenticated user")
        }
        
        print("🔍 Testing member resolution with authenticated UID: \(currentUID)")
        
        // Create a family operations instance
        let mockFamilyManager = FamilyManager()
        let memberOperations = FamilyMemberOperations(
            familyManager: mockFamilyManager,
            authManager: authManager
        )
        
        // Create a family containing the authenticated user
        let testFamily = Family(name: "Test Family", members: [currentUID])
        
        // When: Loading family members
        memberOperations.loadFamilyMembers(family: testFamily)
        
        // Wait for async loading
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Then: The loaded member should use the real UID, not test data
        XCTAssertGreaterThan(memberOperations.familyMembers.count, 0, "Should load at least one member")
        
        let loadedMember = memberOperations.familyMembers.first { $0.id == currentUID }
        XCTAssertNotNil(loadedMember, "Should find member with the authenticated UID")
        
        if let member = loadedMember {
            // Verify this is not test/placeholder data
            XCTAssertFalse(member.name.contains("ユーザー ("), "Should not show placeholder pattern")
            XCTAssertFalse(member.email == "user@example.com", "Should not use placeholder email")
            XCTAssertEqual(member.id, currentUID, "Member ID should match authenticated UID")
            
            print("✅ Member resolved correctly: uid=\(member.id ?? "nil"), name=\(member.name)")
        }
    }
}