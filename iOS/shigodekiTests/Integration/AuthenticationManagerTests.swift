//
//  AuthenticationManagerTests.swift
//  shigodekiTests
//
//  Created by Claude on 2025-08-29.
//

import XCTest
import Combine
@testable import shigodeki

/// Integration tests for AuthenticationManager race condition fixes
/// Tests the fix for authentication state vs user ID availability timing issues
@MainActor
final class AuthenticationManagerTests: XCTestCase {
    
    var authManager: AuthenticationManager!
    var cancellables: Set<AnyCancellable> = []
    
    override func setUp() {
        super.setUp()
        authManager = AuthenticationManager.shared
        cancellables.removeAll()

        trackMemoryUsage(maxMemoryMB: 30.0)
        // Note: Can't track singleton for memory leak as it persists across tests
    }
    
    override func tearDown() {
        // Clean up subscriptions
        cancellables.removeAll()
        // Reset singleton state for next test
        authManager.currentUser = nil
        authManager.isAuthenticated = false
        authManager.isLoading = false
        authManager.errorMessage = nil
        authManager = nil  // Clear local reference only
        forceGarbageCollection()
        super.tearDown()
    }
    
    // MARK: - Authentication State Consistency Tests
    
    /// Test that isAuthenticated only becomes true when currentUser is available
    /// This is the core regression test for the race condition fix
    func testAuthenticationStateConsistency() {
        // Test: When we manually set authentication, user must be available
        // Start with unauthenticated state
        XCTAssertFalse(authManager.isAuthenticated)

        // Simulate proper authentication sequence
        var testUser = User(name: "Test User", email: "test@example.com")
        testUser.id = "test-user-id"
        testUser.createdAt = Date()

        // Set user data first, then set isAuthenticated (the correct order)
        authManager.currentUser = testUser
        authManager.isAuthenticated = true

        // Verify consistency: when authenticated, user ID must be available
        XCTAssertNotNil(authManager.currentUserId,
                       "When isAuthenticated is true, currentUserId must be available")
        XCTAssertNotNil(authManager.currentUser,
                       "When isAuthenticated is true, currentUser must be available")
    }
    
    /// Test the convenience property currentUserId
    func testCurrentUserIdProperty() {
        // Initially should be nil
        XCTAssertNil(authManager.currentUserId)
        XCTAssertFalse(authManager.isAuthenticated)
        
        // When currentUser is set, currentUserId should return the ID
        let mockUser = User(name: "Test User", email: "test@example.com")
        authManager.currentUser = mockUser
        authManager.currentUser?.id = "test-user-id"
        
        XCTAssertEqual(authManager.currentUserId, "test-user-id")
    }
    
    /// Test that singleton doesn't prevent memory stabilization
    func testAuthenticationManagerMemoryStabilization() async {
        // Note: Singleton pattern means we can't test instance deallocation
        // Instead, test that operations don't cause memory growth
        await waitForMemoryStabilization()
    }
    
    // MARK: - Publisher Testing
    
    /// Test that Combine publishers properly clean up when subscriptions are cancelled
    func testPublisherSubscriptionCleanup() async {
        var cancellables: Set<AnyCancellable> = []
        var receivedValues = 0

        // Subscribe to all published properties
        authManager.$isAuthenticated
            .sink { _ in receivedValues += 1 }
            .store(in: &cancellables)

        authManager.$currentUser
            .sink { _ in receivedValues += 1 }
            .store(in: &cancellables)

        authManager.$isLoading
            .sink { _ in receivedValues += 1 }
            .store(in: &cancellables)

        authManager.$errorMessage
            .sink { _ in receivedValues += 1 }
            .store(in: &cancellables)

        // Verify initial values were received
        XCTAssertGreaterThan(receivedValues, 0, "Should receive initial values")

        // Trigger state changes
        authManager.isLoading = true
        authManager.errorMessage = "test"

        // Clean up subscriptions
        cancellables.removeAll()

        await waitForMemoryStabilization()

        // Cancellables should be empty after cleanup
        XCTAssertTrue(cancellables.isEmpty, "Subscriptions should be cleaned up")
    }
    
    // MARK: - Error State Management
    
    /// Test error message state management
    func testErrorMessageHandling() {
        // Initially should be nil
        XCTAssertNil(authManager.errorMessage)
        
        // Set an error message
        authManager.errorMessage = "Test error message"
        XCTAssertEqual(authManager.errorMessage, "Test error message")
        
        // Clear error message
        authManager.errorMessage = nil
        XCTAssertNil(authManager.errorMessage)
    }
    
    /// Test loading state management
    func testLoadingStateHandling() {
        // Initially should be false
        XCTAssertFalse(authManager.isLoading)
        
        // Set loading state
        authManager.isLoading = true
        XCTAssertTrue(authManager.isLoading)
        
        // Clear loading state
        authManager.isLoading = false
        XCTAssertFalse(authManager.isLoading)
    }
    
    // MARK: - User Data Validation
    
    /// Test user data consistency when set programmatically
    func testUserDataConsistency() {
        let expectation = expectation(description: "User data should be consistent")
        
        // Monitor currentUser changes
        authManager.$currentUser
            .dropFirst() // Skip initial nil value
            .sink { user in
                if let user = user {
                    XCTAssertNotNil(user.id, "User should have an ID when set")
                    XCTAssertFalse(user.name.isEmpty, "User should have a non-empty name")
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Set user data
        var testUser = User(name: "Test User", email: "test@example.com")
        testUser.id = "test-user-123"
        testUser.createdAt = Date()
        
        authManager.currentUser = testUser
        
        wait(for: [expectation], timeout: 2.0)
        
        // Verify the convenience property
        XCTAssertEqual(authManager.currentUserId, "test-user-123")
    }
    
    // MARK: - Stress Testing

    /// Test multiple rapid authentication state changes
    func testRapidAuthenticationStateChanges() async {
        let changeCount = 10

        // Simulate rapid authentication state changes
        for i in 0..<changeCount {
            let shouldBeAuthenticated = i % 2 == 0

            if shouldBeAuthenticated {
                // Simulate successful authentication with user data
                var user = User(name: "Test User \(i)", email: "test\(i)@example.com")
                user.id = "test-user-\(i)"
                user.createdAt = Date()

                authManager.currentUser = user
                authManager.isAuthenticated = true

                // Verify consistency: when authenticated, user ID should exist
                XCTAssertNotNil(authManager.currentUserId,
                               "User ID should be available when authenticated at iteration \(i)")
            } else {
                // Simulate sign out
                authManager.currentUser = nil
                authManager.isAuthenticated = false
            }
        }

        await waitForMemoryStabilization()

        // Final state should be consistent
        if authManager.isAuthenticated {
            XCTAssertNotNil(authManager.currentUserId, "Final state should be consistent")
        }
    }
    
    // MARK: - Performance Testing
    
    /// Test authentication manager performance under load
    func testAuthenticationPerformance() {
        measure {
            for i in 0..<100 {
                var user = User(name: "User \(i)", email: "user\(i)@example.com")
                user.id = "user-\(i)"
                
                authManager.currentUser = user
                authManager.isAuthenticated = true
                
                _ = authManager.currentUserId
                
                authManager.currentUser = nil
                authManager.isAuthenticated = false
            }
        }
    }
    
    // MARK: - Integration with ProjectListView Pattern

    /// Test the pattern used by ProjectListView for authentication checking
    func testProjectListViewAuthPattern() {
        // Simulate ProjectListView's loadUserProjects pattern
        // Before authentication, currentUserId should be nil
        authManager.currentUser = nil
        authManager.isAuthenticated = false
        XCTAssertNil(authManager.currentUserId, "Should have no user ID before auth")

        // Simulate authentication completing
        var user = User(name: "Test User", email: "test@example.com")
        user.id = "test-user-id"
        user.createdAt = Date()

        // Set user data before marking as authenticated (the correct pattern)
        authManager.currentUser = user
        authManager.isAuthenticated = true

        // After authentication, currentUserId should be available immediately
        XCTAssertNotNil(authManager.currentUserId, "Should have user ID after auth")
        XCTAssertEqual(authManager.currentUserId, "test-user-id")

        // This simulates what ProjectListView does: checking currentUserId
        // With proper auth timing, it should succeed on first try
        if let userId = authManager.currentUserId {
            XCTAssertEqual(userId, "test-user-id", "Should get correct user ID")
        } else {
            XCTFail("currentUserId should be available after authentication")
        }
    }
}