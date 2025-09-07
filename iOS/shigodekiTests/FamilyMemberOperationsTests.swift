//
//  FamilyMemberOperationsTests.swift
//  shigodekiTests
//
//  Unit tests for FamilyMemberOperations uid-scoped member resolution
//  Tests the fix for Issue: "Member info shows test user despite being logged in"
//

import XCTest
import FirebaseAuth
import FirebaseFirestore
@testable import shigodeki

@MainActor
final class FamilyMemberOperationsTests: XCTestCase {
    
    var familyMemberOperations: FamilyMemberOperations!
    var mockFamilyManager: FamilyManager!
    var mockAuthManager: AuthenticationManager!
    
    override func setUp() async throws {
        // Set up mock dependencies
        mockFamilyManager = FamilyManager()
        mockAuthManager = AuthenticationManager.shared
        
        // Initialize the component under test
        familyMemberOperations = FamilyMemberOperations(
            familyManager: mockFamilyManager,
            authManager: mockAuthManager
        )
    }
    
    override func tearDown() async throws {
        familyMemberOperations = nil
        mockFamilyManager = nil
        mockAuthManager = nil
    }
    
    // MARK: - Test Member Resolution with Real UIDs
    
    func testLoadFamilyMembers_WithValidUIDs_LoadsFromFirestore() async throws {
        // Given: A family with valid member UIDs
        let testUid1 = "xEMEqpAKdiUPAYjXwQI9BhnziXf1" // Real Firebase UID format
        let testUid2 = "aBcDeFgHiJkLmNoPqRsTuVwXyZ12"
        let family = Family(name: "Test Family", members: [testUid1, testUid2])
        
        // When: Loading family members
        familyMemberOperations.loadFamilyMembers(family: family)
        
        // Wait for async loading to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then: Members should be loaded based on actual UIDs, not test data
        XCTAssertEqual(familyMemberOperations.familyMembers.count, 2)
        
        // Verify no test user placeholders
        for member in familyMemberOperations.familyMembers {
            XCTAssertFalse(member.name.contains("ユーザー ("), "Should not contain placeholder test user patterns")
            XCTAssertFalse(member.email == "user@example.com", "Should not use placeholder email")
            XCTAssertNotNil(member.id, "Member ID should be properly set")
            XCTAssertTrue(member.id == testUid1 || member.id == testUid2, "Member ID should match input UIDs")
        }
    }
    
    func testMemberCache_KeyedByUID_PreventsCrossPollination() async throws {
        // Given: Two different families with different UIDs
        let uid1 = "user1_12345"
        let uid2 = "user2_67890" 
        let family1 = Family(name: "Family 1", members: [uid1])
        let family2 = Family(name: "Family 2", members: [uid2])
        
        // When: Loading members for family 1
        familyMemberOperations.loadFamilyMembers(family: family1)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        let family1Members = familyMemberOperations.familyMembers
        
        // And: Loading members for family 2 (different FamilyMemberOperations instance)
        let operations2 = FamilyMemberOperations(
            familyManager: mockFamilyManager,
            authManager: mockAuthManager
        )
        operations2.loadFamilyMembers(family: family2)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        let family2Members = operations2.familyMembers
        
        // Then: Each family should have distinct members keyed by UID
        XCTAssertEqual(family1Members.count, 1)
        XCTAssertEqual(family2Members.count, 1)
        XCTAssertNotEqual(family1Members.first?.id, family2Members.first?.id)
    }
    
    // MARK: - Test Cache Invalidation on Auth Changes
    
    func testCacheClearing_OnAuthUserChanged_ClearsAllData() async throws {
        // Given: Loaded family members with cached data
        let family = Family(name: "Test Family", members: ["test_uid_1", "test_uid_2"])
        familyMemberOperations.loadFamilyMembers(family: family)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Verify data is loaded
        XCTAssertGreaterThan(familyMemberOperations.familyMembers.count, 0)
        
        // When: Auth user changes (sign out)
        NotificationCenter.default.post(
            name: .authUserChanged,
            object: nil,
            userInfo: ["action": "signout", "previousUserId": "test_uid_1"]
        )
        
        // Wait for notification processing
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: All member data should be cleared
        XCTAssertEqual(familyMemberOperations.familyMembers.count, 0, "Members should be cleared on auth change")
    }
    
    func testCacheClearing_OnAuthUserChanged_WithUserSwitch_ClearsStaleData() async throws {
        // Given: Loaded family members for user A
        let userA = "user_a_12345"
        let userB = "user_b_67890"
        let family = Family(name: "Test Family", members: [userA])
        
        familyMemberOperations.loadFamilyMembers(family: family)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        let initialMemberCount = familyMemberOperations.familyMembers.count
        XCTAssertGreaterThan(initialMemberCount, 0)
        
        // When: User switches from A to B
        NotificationCenter.default.post(
            name: .authUserChanged,
            object: nil,
            userInfo: [
                "action": "signin",
                "newUserId": userB,
                "previousUserId": userA
            ]
        )
        
        // Wait for notification processing
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: Stale data should be cleared to prevent user A data showing for user B
        XCTAssertEqual(familyMemberOperations.familyMembers.count, 0, "Stale member data should be cleared on user switch")
    }
    
    // MARK: - Test Error Handling
    
    func testMemberResolution_WithMissingUID_ShowsUnknownInsteadOfTestUser() async throws {
        // Given: A family with a non-existent member UID
        let missingUid = "nonexistent_uid_12345"
        let family = Family(name: "Test Family", members: [missingUid])
        
        // When: Loading family members
        familyMemberOperations.loadFamilyMembers(family: family)
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Then: Should show unknown user, not test user placeholder
        XCTAssertEqual(familyMemberOperations.familyMembers.count, 1)
        let member = familyMemberOperations.familyMembers.first!
        
        XCTAssertTrue(member.name.contains("ユーザー不明"), "Should show unknown user instead of test placeholder")
        XCTAssertEqual(member.id, missingUid, "Should preserve the requested UID")
        XCTAssertEqual(member.email, "unknown@example.com", "Should use unknown email, not test placeholder")
    }
    
    // MARK: - Test Production vs Development Behavior
    
    func testNoTestUserFallback_InProduction_ReturnsNilOrLoading() async throws {
        // Given: Empty member ID (edge case)
        let family = Family(name: "Test Family", members: [""])
        
        // When: Loading family members
        familyMemberOperations.loadFamilyMembers(family: family)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Then: Should not create test user for empty UID
        XCTAssertEqual(familyMemberOperations.familyMembers.count, 0, "Empty UID should be skipped, not create test user")
    }
    
    func testMemberRetry_WithValidUID_UsesRealData() async throws {
        // Given: A member that initially fails to load
        let validUid = "retry_test_uid"
        familyMemberOperations.familyMembers = [
            {
                var errorUser = User(name: "エラー", email: "error@example.com", familyIds: [])
                errorUser.id = validUid
                return errorUser
            }()
        ]
        
        // When: Retrying member load
        familyMemberOperations.retryMemberLoad(memberId: validUid)
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Then: Should attempt to load real user data, not fallback to test user
        let updatedMember = familyMemberOperations.familyMembers.first { $0.id == validUid }
        XCTAssertNotNil(updatedMember)
        
        // Should either succeed with real data or show "unknown" - never test data
        let memberName = updatedMember!.name
        XCTAssertFalse(memberName.contains("テスト"), "Should not fallback to test user on retry")
        XCTAssertFalse(memberName.contains("Test"), "Should not fallback to test user on retry")
    }
}

// MARK: - Test Helper Extensions

extension Notification.Name {
    static let authUserChanged = Notification.Name("authUserChanged")
}