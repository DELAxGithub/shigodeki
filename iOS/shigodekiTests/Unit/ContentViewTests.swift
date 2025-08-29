import XCTest
import SwiftUI
import ViewInspector
@testable import shigodeki

/// Comprehensive SwiftUI View Testing Examples (2024/2025)
/// 
/// This test suite demonstrates modern SwiftUI testing patterns using ViewInspector
/// with memory leak detection and comprehensive view state validation.

final class ContentViewTests: SwiftUITestCase {
    
    var mockAuthManager: MockAuthenticationManager!
    var mockProjectManager: MockProjectManager!
    
    override func setUp() {
        super.setUp()
        mockAuthManager = MockAuthenticationManager()
        mockProjectManager = MockProjectManager()
        
        // Track managers for memory leaks
        trackForMemoryLeak(instance: mockAuthManager)
        trackForMemoryLeak(instance: mockProjectManager)
    }
    
    // MARK: - Basic View Rendering Tests
    
    func testContentViewRendersWithoutErrors() throws {
        let view = ContentView()
            .environmentObject(mockAuthManager)
            .environmentObject(mockProjectManager)
        
        try assertViewCanBeInspected(view)
    }
    
    func testContentViewShowsLoginWhenNotAuthenticated() throws {
        mockAuthManager.isAuthenticated = false
        
        let view = ContentView()
            .environmentObject(mockAuthManager)
            .environmentObject(mockProjectManager)
        
        let inspectedView = try view.inspect()
        
        // Should show LoginView when not authenticated
        XCTAssertNoThrow(try inspectedView.find(LoginView.self))
    }
    
    func testContentViewShowsMainTabViewWhenAuthenticated() throws {
        mockAuthManager.isAuthenticated = true
        
        let view = ContentView()
            .environmentObject(mockAuthManager)
            .environmentObject(mockProjectManager)
        
        let inspectedView = try view.inspect()
        
        // Should show MainTabView when authenticated
        XCTAssertNoThrow(try inspectedView.find(MainTabView.self))
    }
    
    // MARK: - State Change Testing
    
    func testAuthenticationStateChanges() async throws {
        let view = ContentView()
            .environmentObject(mockAuthManager)
            .environmentObject(mockProjectManager)
        
        // Initially should show login
        mockAuthManager.isAuthenticated = false
        try assertViewCanBeInspected(view)
        
        // Test async state change
        await testAsyncViewStateChange(
            view: view,
            asyncAction: {
                await self.mockAuthManager.signIn(email: "test@example.com", password: "password")
            },
            stateValidation: { updatedView in
                let inspected = try updatedView.inspect()
                // After sign in, should show main tab view
                XCTAssertNoThrow(try inspected.find(MainTabView.self))
            }
        )
    }
    
    // MARK: - Loading State Testing
    
    func testContentViewShowsLoadingState() throws {
        mockAuthManager.isLoading = true
        
        let view = ContentView()
            .environmentObject(mockAuthManager)
            .environmentObject(mockProjectManager)
        
        // Test that loading indicator is shown
        try testViewLoadingState(view: view)
    }
    
    // MARK: - Memory Leak Testing
    
    func testContentViewMemoryLeak() {
        testViewForMemoryLeak {
            ContentView()
                .environmentObject(MockAuthenticationManager())
                .environmentObject(MockProjectManager())
        }
    }
    
    func testEnvironmentObjectsMemoryLeak() async {
        await testAsyncViewModelForMemoryLeak(
            viewModelFactory: { MockAuthenticationManager() },
            asyncOperation: { authManager in
                await authManager.signIn(email: "test@example.com", password: "password")
            }
        )
    }
    
    // MARK: - Error State Testing
    
    func testContentViewShowsErrorState() throws {
        mockAuthManager.errorMessage = "Authentication failed"
        
        let view = ContentView()
            .environmentObject(mockAuthManager)
            .environmentObject(mockProjectManager)
        
        try testViewErrorState(view: view, expectedErrorText: "Authentication failed")
    }
    
    // MARK: - Performance Testing
    
    func testContentViewPerformance() {
        measure {
            let view = ContentView()
                .environmentObject(MockAuthenticationManager())
                .environmentObject(MockProjectManager())
            
            _ = try? view.inspect()
        }
    }
    
    func testContentViewMemoryUsage() {
        trackMemoryUsage(maxMemoryMB: 25.0)
        
        let view = ContentView()
            .environmentObject(mockAuthManager)
            .environmentObject(mockProjectManager)
        
        // Perform multiple operations that might consume memory
        for _ in 0..<100 {
            _ = try? view.inspect()
        }
    }
}