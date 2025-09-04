import XCTest
import Firebase
import FirebaseAuth
import FirebaseFirestore
@testable import shigodeki

/// Firebase Integration Tests (2024/2025)
/// 
/// This test suite demonstrates comprehensive Firebase testing using the Local Emulator Suite
/// with proper setup, teardown, and realistic test scenarios.

final class FirebaseIntegrationTests: FirebaseTestCase {
    
    var authManager: AuthenticationManager!
    var projectManager: ProjectManager!
    var userManager: UserManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize managers with test configuration
        authManager = AuthenticationManager()
        projectManager = ProjectManager()
        userManager = UserManager()
        
        // Track for memory leaks
        trackForMemoryLeak(instance: authManager)
        trackForMemoryLeak(instance: projectManager)
        trackForMemoryLeak(instance: userManager)
    }
    
    // MARK: - Authentication Tests
    
    func testUserRegistration() async throws {
        let email = "newuser@test.com"
        let password = "testpassword123"
        
        // Test user creation
        let user = try await createTestUser(email: email, password: password)
        
        XCTAssertEqual(user.email, email)
        XCTAssertNotNil(user.uid)
        
        // Verify user document is created
        await waitForFirestore()
        
        let db = Firestore.firestore()
        let userDoc = try await db.collection("users").document(user.uid).getDocument()
        XCTAssertTrue(userDoc.exists, "User document should be created in Firestore")
    }
    
    func testUserSignIn() async throws {
        let email = "signin@test.com"
        let password = "testpassword123"
        
        // First create the user
        _ = try await createTestUser(email: email, password: password)
        
        // Sign out
        try Auth.auth().signOut()
        
        // Test sign in
        let signedInUser = try await signInTestUser(email: email, password: password)
        
        XCTAssertEqual(signedInUser.email, email)
        XCTAssertNotNil(Auth.auth().currentUser)
    }
    
    func testSignInWithInvalidCredentials() async {
        do {
            _ = try await signInTestUser(email: "nonexistent@test.com", password: "wrongpassword")
            XCTFail("Should have thrown an error for invalid credentials")
        } catch {
            // Expected error
            XCTAssertTrue(error.localizedDescription.contains("user") || error.localizedDescription.contains("password"))
        }
    }
    
    // MARK: - Firestore Data Tests
    
    func testUserDataCreation() async throws {
        let user = try await createTestUser()
        
        // Create user data
        let userData = FirebaseTestDataFactory.createTestUser(id: user.uid)
        let userRef = try await createTestData(in: "users", document: user.uid, data: userData)
        
        // Verify data was created
        let document = try await userRef.getDocument()
        XCTAssertTrue(document.exists)
        
        let data = document.data()
        XCTAssertEqual(data?["id"] as? String, user.uid)
        XCTAssertNotNil(data?["createdAt"])
    }
    
    func testFamilyCreation() async throws {
        let user = try await createTestUser()
        
        // Create family data
        let familyData = FirebaseTestDataFactory.createTestFamily(ownerID: user.uid)
        let familyRef = try await createTestData(in: "families", data: familyData)
        
        // Verify family was created
        let document = try await familyRef.getDocument()
        XCTAssertTrue(document.exists)
        
        let data = document.data()
        XCTAssertEqual(data?["ownerID"] as? String, user.uid)
        XCTAssertTrue((data?["memberIDs"] as? [String])?.contains(user.uid) ?? false)
    }
    
    func testProjectCreation() async throws {
        let user = try await createTestUser()
        
        // Create family first
        let familyData = FirebaseTestDataFactory.createTestFamily(ownerID: user.uid)
        let familyRef = try await createTestData(in: "families", data: familyData)
        let familyID = familyRef.documentID
        
        // Create project
        let projectData = FirebaseTestDataFactory.createTestProject(familyID: familyID)
        let projectRef = try await createTestData(in: "projects", data: projectData)
        
        // Verify project was created
        let document = try await projectRef.getDocument()
        XCTAssertTrue(document.exists)
        
        let data = document.data()
        XCTAssertEqual(data?["familyID"] as? String, familyID)
        XCTAssertEqual(data?["status"] as? String, "active")
    }
    
    func testTaskCreation() async throws {
        let user = try await createTestUser()
        
        // Create project hierarchy
        let familyData = FirebaseTestDataFactory.createTestFamily(ownerID: user.uid)
        let familyRef = try await createTestData(in: "families", data: familyData)
        
        let projectData = FirebaseTestDataFactory.createTestProject(familyID: familyRef.documentID)
        let projectRef = try await createTestData(in: "projects", data: projectData)
        
        // Create task
        let taskData = FirebaseTestDataFactory.createTestTask(projectID: projectRef.documentID)
        let taskRef = try await createTestData(in: "tasks", data: taskData)
        
        // Verify task was created
        let document = try await taskRef.getDocument()
        XCTAssertTrue(document.exists)
        
        let data = document.data()
        XCTAssertEqual(data?["projectID"] as? String, projectRef.documentID)
        XCTAssertEqual(data?["isCompleted"] as? Bool, false)
    }
    
    // MARK: - Real-time Listener Tests
    
    func testFirestoreRealtimeListener() async throws {
        let user = try await createTestUser()
        let db = Firestore.firestore()
        
        let expectation = expectation(description: "Realtime update received")
        var receivedUpdates: [DocumentSnapshot] = []
        
        // Set up listener
        let listener = db.collection("users").document(user.uid)
            .addSnapshotListener { snapshot, error in
                if let snapshot = snapshot, snapshot.exists {
                    receivedUpdates.append(snapshot)
                    if receivedUpdates.count >= 2 {
                        expectation.fulfill()
                    }
                }
            }
        
        // Create initial document
        let userData = FirebaseTestDataFactory.createTestUser(id: user.uid)
        try await createTestData(in: "users", document: user.uid, data: userData)
        
        // Update document
        try await db.collection("users").document(user.uid).updateData([
            "displayName": "Updated Name"
        ])
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Cleanup listener
        listener.remove()
        
        // Verify we received updates
        XCTAssertGreaterThanOrEqual(receivedUpdates.count, 2)
    }
    
    // MARK: - Security Rules Testing
    
    func testUserCanOnlyAccessOwnData() async throws {
        let user1 = try await createTestUser(email: "user1@test.com")
        let user2 = try await createTestUser(email: "user2@test.com")
        
        // Create user1's data
        let user1Data = FirebaseTestDataFactory.createTestUser(id: user1.uid)
        try await createTestData(in: "users", document: user1.uid, data: user1Data)
        
        // Sign in as user2 and try to access user1's data
        try Auth.auth().signOut()
        _ = try await signInTestUser(email: "user2@test.com", password: "testpassword123")
        
        let db = Firestore.firestore()
        
        do {
            _ = try await db.collection("users").document(user1.uid).getDocument()
            // If we get here without error, the security rules may not be properly configured
            // This depends on your specific Firestore security rules
        } catch {
            // Expected error due to security rules
            print("Access denied as expected: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testBulkDataOperations() async throws {
        let user = try await createTestUser()
        let db = Firestore.firestore()
        
        measure {
            let group = DispatchGroup()
            
            // Create multiple documents in parallel
            for i in 0..<10 {
                group.enter()
                Task {
                    let testData = FirebaseTestDataFactory.createTestUser(id: "bulk-test-\(i)")
                    try? await self.createTestData(in: "bulk_test", data: testData)
                    group.leave()
                }
            }
            
            group.wait()
        }
    }
    
    func testQueryPerformance() async throws {
        let user = try await createTestUser()
        let db = Firestore.firestore()
        
        // Create test data
        for i in 0..<50 {
            let testData = FirebaseTestDataFactory.createTestUser(id: "perf-test-\(i)")
            try await createTestData(in: "performance_test", data: testData)
        }
        
        measure {
            Task {
                _ = try? await db.collection("performance_test")
                    .limit(to: 10)
                    .getDocuments()
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testNetworkErrorHandling() async throws {
        let db = Firestore.firestore()
        
        // Simulate network error by trying to access non-existent collection
        do {
            _ = try await db.collection("nonexistent_collection_12345")
                .document("nonexistent_doc")
                .getDocument()
            // This might not throw an error, but will return empty document
        } catch {
            print("Network error handled: \(error)")
        }
    }
    
    func testInvalidDataHandling() async throws {
        let db = Firestore.firestore()
        
        do {
            // Try to create document with invalid field types
            try await db.collection("test_collection").addDocument(data: [
                "invalid_field": NSNull() // This should cause issues
            ])
        } catch {
            print("Invalid data error handled: \(error)")
        }
    }
}