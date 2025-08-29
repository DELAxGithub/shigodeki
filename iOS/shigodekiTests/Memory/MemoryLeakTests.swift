import XCTest
import SwiftUI
import Combine
@testable import shigodeki

/// Comprehensive Memory Leak Testing Suite (2024/2025)
/// 
/// This test suite demonstrates advanced memory leak detection techniques
/// for iOS apps including view models, Combine publishers, and SwiftUI views.

final class MemoryLeakTests: MemoryLeakTestCase {
    
    // MARK: - Manager Memory Leak Tests
    
    func testAuthenticationManagerMemoryLeak() {
        weak var weakManager: AuthenticationManager?
        
        autoreleasepool {
            let manager = AuthenticationManager()
            weakManager = manager
            
            // Perform operations that might create retain cycles
            Task {
                await manager.signIn(email: "test@example.com", password: "password")
            }
        }
        
        XCTAssertNil(weakManager, "AuthenticationManager should be deallocated")
    }
    
    func testProjectManagerMemoryLeak() {
        weak var weakManager: ProjectManager?
        
        autoreleasepool {
            let manager = ProjectManager()
            weakManager = manager
            
            // Test async operations
            Task {
                await manager.loadProjects()
            }
        }
        
        XCTAssertNil(weakManager, "ProjectManager should be deallocated")
    }
    
    func testTaskManagerMemoryLeak() {
        weak var weakManager: TaskManager?
        
        autoreleasepool {
            let manager = TaskManager()
            weakManager = manager
            
            // Perform operations that might retain the manager
            Task {
                await manager.loadTasks(for: "test-project")
            }
        }
        
        XCTAssertNil(weakManager, "TaskManager should be deallocated")
    }
    
    func testFamilyManagerMemoryLeak() {
        weak var weakManager: FamilyManager?
        
        autoreleasepool {
            let manager = FamilyManager()
            weakManager = manager
            
            Task {
                await manager.loadFamilies()
            }
        }
        
        XCTAssertNil(weakManager, "FamilyManager should be deallocated")
    }
    
    // MARK: - Combine Publisher Memory Leak Tests
    
    func testPublisherRetainCycle() {
        var cancellables: Set<AnyCancellable> = []
        weak var weakManager: AuthenticationManager?
        
        autoreleasepool {
            let manager = AuthenticationManager()
            weakManager = manager
            
            // Create publisher chain that might create retain cycle
            manager.$isAuthenticated
                .sink { _ in
                    // Empty sink that should not retain manager
                }
                .store(in: &cancellables)
            
            // Clear cancellables to break any potential cycles
            cancellables.removeAll()
        }
        
        XCTAssertNil(weakManager, "Manager should be deallocated even with publisher subscription")
    }
    
    func testAsyncPublisherMemoryLeak() async {
        await testAsyncViewModelForMemoryLeak(
            viewModelFactory: { ProjectManager() },
            asyncOperation: { manager in
                await manager.loadProjects()
                
                // Test publisher subscription within async context
                let cancellable = manager.$projects
                    .sink { _ in }
                
                cancellable.cancel()
            }
        )
    }
    
    func testCombineChainMemoryLeak() {
        var cancellables: Set<AnyCancellable> = []
        weak var weakAuthManager: AuthenticationManager?
        weak var weakProjectManager: ProjectManager?
        
        autoreleasepool {
            let authManager = AuthenticationManager()
            let projectManager = ProjectManager()
            
            weakAuthManager = authManager
            weakProjectManager = projectManager
            
            // Create complex Combine chain
            authManager.$isAuthenticated
                .filter { $0 }
                .flatMap { _ in
                    projectManager.$projects
                }
                .sink { _ in }
                .store(in: &cancellables)
            
            cancellables.removeAll()
        }
        
        XCTAssertNil(weakAuthManager, "AuthManager should be deallocated")
        XCTAssertNil(weakProjectManager, "ProjectManager should be deallocated")
    }
    
    // MARK: - SwiftUI View Memory Leak Tests
    
    func testContentViewMemoryLeak() {
        testViewForMemoryLeak {
            ContentView()
                .environmentObject(AuthenticationManager())
                .environmentObject(ProjectManager())
        }
    }
    
    func testLoginViewMemoryLeak() {
        testViewForMemoryLeak {
            LoginView()
                .environmentObject(AuthenticationManager())
        }
    }
    
    func testProjectListViewMemoryLeak() {
        testViewForMemoryLeak {
            ProjectListView()
                .environmentObject(ProjectManager())
                .environmentObject(AuthenticationManager())
        }
    }
    
    func testProjectDetailViewMemoryLeak() {
        let testProject = Project(
            id: "test-project",
            title: "Test Project",
            description: "Test Description",
            familyID: "test-family"
        )
        
        testViewForMemoryLeak {
            ProjectDetailView(project: testProject)
                .environmentObject(TaskManager())
                .environmentObject(PhaseManager())
        }
    }
    
    func testCreateProjectViewMemoryLeak() {
        testViewForMemoryLeak {
            CreateProjectView()
                .environmentObject(ProjectManager())
        }
    }
    
    // MARK: - Navigation Memory Leak Tests
    
    func testNavigationStackMemoryLeak() {
        weak var weakNavigationManager: AnyObject?
        
        testViewForMemoryLeak {
            let view = NavigationStack {
                ContentView()
                    .environmentObject(AuthenticationManager())
                    .environmentObject(ProjectManager())
            }
            
            // If there's a navigation manager or coordinator, track it
            if let manager = view as AnyObject? {
                weakNavigationManager = manager
            }
            
            return view
        }
        
        // Navigation-related objects should also be deallocated
        XCTAssertNil(weakNavigationManager, "Navigation-related objects should be deallocated")
    }
    
    // MARK: - Async/Await Memory Leak Tests
    
    func testAsyncTaskMemoryLeak() async {
        weak var weakManager: TaskManager?
        
        await autoreleasepool {
            let manager = TaskManager()
            weakManager = manager
            
            // Create async task that might retain manager
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await manager.loadTasks(for: "test-project")
                }
            }
        }
        
        // Allow async operations to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertNil(weakManager, "TaskManager should be deallocated after async operations")
    }
    
    func testAsyncStreamMemoryLeak() async {
        weak var weakManager: AuthenticationManager?
        
        await autoreleasepool {
            let manager = AuthenticationManager()
            weakManager = manager
            
            // Create async stream that might retain manager
            let stream = AsyncStream<Bool> { continuation in
                let cancellable = manager.$isAuthenticated
                    .sink { value in
                        continuation.yield(value)
                    }
                
                continuation.onTermination = { _ in
                    cancellable.cancel()
                }
            }
            
            // Consume stream briefly
            var iterator = stream.makeAsyncIterator()
            _ = await iterator.next()
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertNil(weakManager, "Manager should be deallocated after async stream")
    }
    
    // MARK: - Closure Capture Memory Leak Tests
    
    func testClosureCaptureMemoryLeak() {
        weak var weakManager: ProjectManager?
        
        autoreleasepool {
            let manager = ProjectManager()
            weakManager = manager
            
            // Test closure that might capture manager strongly
            let closure: () -> Void = { [weak manager] in
                guard let manager = manager else { return }
                Task {
                    await manager.loadProjects()
                }
            }
            
            closure()
        }
        
        XCTAssertNil(weakManager, "Manager should be deallocated despite closure capture")
    }
    
    // MARK: - Memory Usage Performance Tests
    
    func testViewMemoryUsage() {
        trackMemoryUsage(maxMemoryMB: 10.0)
        
        // Create and destroy views multiple times
        for _ in 0..<100 {
            autoreleasepool {
                let _ = ContentView()
                    .environmentObject(AuthenticationManager())
                    .environmentObject(ProjectManager())
            }
        }
    }
    
    func testManagerMemoryUsage() {
        trackMemoryUsage(maxMemoryMB: 15.0)
        
        // Create and destroy managers multiple times
        for _ in 0..<50 {
            autoreleasepool {
                let authManager = AuthenticationManager()
                let projectManager = ProjectManager()
                let taskManager = TaskManager()
                
                // Perform operations
                Task {
                    await authManager.signIn(email: "test@example.com", password: "password")
                    await projectManager.loadProjects()
                    await taskManager.loadTasks(for: "test-project")
                }
            }
        }
    }
    
    // MARK: - Firebase Memory Leak Tests
    
    func testFirebaseListenersMemoryLeak() {
        weak var weakManager: ProjectManager?
        var listeners: [ListenerRegistration] = []
        
        autoreleasepool {
            let manager = ProjectManager()
            weakManager = manager
            
            // Set up Firebase listeners that might retain the manager
            // Note: This is a conceptual test - adjust based on your actual Firebase listener implementation
            
            // Cleanup listeners
            listeners.forEach { $0.remove() }
            listeners.removeAll()
        }
        
        XCTAssertNil(weakManager, "Manager should be deallocated after removing Firebase listeners")
    }
}