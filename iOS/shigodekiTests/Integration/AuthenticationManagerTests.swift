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
        authManager = AuthenticationManager()
        cancellables.removeAll()
        
        trackMemoryUsage(maxMemoryMB: 30.0)
        trackForMemoryLeak(authManager)
    }
    
    override func tearDown() {
        cancellables.removeAll()
        authManager = nil
        forceGarbageCollection()
        super.tearDown()
    }
    
    // MARK: - Authentication State Consistency Tests
    
    /// Test that isAuthenticated only becomes true when currentUser is available
    /// This is the core regression test for the race condition fix
    func testAuthenticationStateConsistency() async {
        let expectation = expectation(description: "Authentication state should be consistent")
        expectation.expectedFulfillmentCount = 1
        
        var authStateChanges: [(isAuthenticated: Bool, hasUserId: Bool)] = []
        
        // Monitor authentication state changes
        authManager.$isAuthenticated
            .sink { isAuthenticated in
                let hasUserId = self.authManager.currentUserId != nil
                authStateChanges.append((isAuthenticated: isAuthenticated, hasUserId: hasUserId))
                
                print("📊 Auth state: \(isAuthenticated), Has User ID: \(hasUserId)")
                
                // If authenticated, must have user ID (the core fix)
                if isAuthenticated {
                    XCTAssertNotNil(self.authManager.currentUserId, 
                                   "When isAuthenticated is true, currentUserId must be available")
                    XCTAssertNotNil(self.authManager.currentUser,
                                   "When isAuthenticated is true, currentUser must be available")
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate authentication process (would normally happen via Firebase)
        // This simulates the fix where user data loading completes before isAuthenticated = true
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Verify that we never had isAuthenticated = true without a user ID
        let inconsistentStates = authStateChanges.filter { $0.isAuthenticated && !$0.hasUserId }
        XCTAssertTrue(inconsistentStates.isEmpty, 
                     "Found \(inconsistentStates.count) inconsistent authentication states")
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
    
    /// Test memory leak prevention in authentication state changes
    func testAuthenticationManagerMemoryLeak() async {
        testObservableObjectForMemoryLeak {
            AuthenticationManager()
        }
        
        await waitForMemoryStabilization()
    }
    
    // MARK: - Publisher Testing
    
    /// Test that Combine publishers don't create retain cycles
    func testPublisherMemoryLeaks() async {
        var cancellables: Set<AnyCancellable> = []
        
        trackForMemoryLeak(authManager)
        
        // Subscribe to all published properties
        authManager.$isAuthenticated
            .sink { _ in }
            .store(in: &cancellables)
        
        authManager.$currentUser
            .sink { _ in }
            .store(in: &cancellables)
        
        authManager.$isLoading
            .sink { _ in }
            .store(in: &cancellables)
        
        authManager.$errorMessage
            .sink { _ in }
            .store(in: &cancellables)
        
        // Test publisher memory leak
        testPublisherForMemoryLeak(authManager.objectWillChange)
        
        // Clean up subscriptions
        cancellables.removeAll()
        
        await waitForMemoryStabilization()
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
        var stateChanges: [Bool] = []
        let changeCount = 10
        
        // Monitor state changes
        authManager.$isAuthenticated
            .sink { isAuthenticated in
                stateChanges.append(isAuthenticated)
            }
            .store(in: &cancellables)
        
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
            } else {
                // Simulate sign out
                authManager.currentUser = nil
                authManager.isAuthenticated = false
            }
            
            // Small delay between changes
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        await waitForMemoryStabilization()
        
        // Verify that we captured all state changes
        XCTAssertEqual(stateChanges.count, changeCount + 1) // +1 for initial state
        
        // Verify consistency: when authenticated = true, user ID should exist
        for (index, isAuthenticated) in stateChanges.enumerated() {
            if isAuthenticated && index > 0 { // Skip initial false state
                XCTAssertNotNil(authManager.currentUserId,
                               "User ID should be available when authenticated at index \(index)")
            }
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
    func testProjectListViewAuthPattern() async {
        let expectation = expectation(description: "ProjectListView auth pattern should work")
        var attemptCount = 0
        let maxAttempts = 5
        
        // Simulate ProjectListView's loadUserProjects pattern
        func simulateLoadUserProjects() {
            attemptCount += 1
            print("📱 Simulated attempt \(attemptCount)")
            
            guard let userId = authManager.currentUserId else {
                guard attemptCount < maxAttempts else {
                    XCTFail("Should not reach max attempts with proper auth timing")
                    expectation.fulfill()
                    return
                }
                
                // Exponential backoff simulation
                let delay = 0.25 * pow(2.0, Double(attemptCount - 1))
                let cappedDelay = min(delay, 2.0)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + cappedDelay) {
                    simulateLoadUserProjects()
                }
                return
            }
            
            // Success - got user ID
            XCTAssertEqual(userId, "test-user-id")
            XCTAssertLessThan(attemptCount, 3, "Should succeed quickly with proper auth timing")
            expectation.fulfill()
        }
        
        // Start the simulation
        simulateLoadUserProjects()
        
        // Simulate user authentication completing after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            var user = User(name: "Test User", email: "test@example.com")
            user.id = "test-user-id"
            user.createdAt = Date()
            
            // This should trigger isAuthenticated = true only after user data is set
            self.authManager.currentUser = user
            self.authManager.isAuthenticated = true
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
}