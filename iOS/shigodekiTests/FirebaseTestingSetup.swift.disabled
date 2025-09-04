import XCTest
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

/// Firebase Testing Setup (2024/2025)
/// 
/// This class provides comprehensive Firebase testing infrastructure
/// using the Firebase Local Emulator Suite for safe, isolated testing.

class FirebaseTestingSetup {
    
    static let shared = FirebaseTestingSetup()
    private var isConfigured = false
    
    // MARK: - Emulator Configuration
    
    /// Firebase Local Emulator Suite default ports
    struct EmulatorPorts {
        static let auth = 9099
        static let firestore = 8080
        static let storage = 9199
        static let functions = 5001
    }
    
    private init() {}
    
    /// Configures Firebase for testing with Local Emulator Suite
    ///
    /// Call this method in your test setUp() method:
    /// ```swift
    /// override func setUp() {
    ///     super.setUp()
    ///     FirebaseTestingSetup.shared.configureForTesting()
    /// }
    /// ```
    func configureForTesting() {
        guard !isConfigured else { return }
        
        // Configure Firebase app for testing
        if FirebaseApp.app() == nil {
            configureFirebaseApp()
        }
        
        // Connect to emulators
        connectToEmulators()
        
        isConfigured = true
        print("🔥 Firebase configured for testing with Local Emulator Suite")
    }
    
    /// Resets Firebase state between tests
    ///
    /// Call this in your test tearDown() method:
    /// ```swift
    /// override func tearDown() {
    ///     FirebaseTestingSetup.shared.resetForTesting()
    ///     super.tearDown()
    /// }
    /// ```
    func resetForTesting() async {
        // Clear Firestore data
        await clearFirestoreData()
        
        // Sign out current user
        try? Auth.auth().signOut()
        
        print("🧹 Firebase state reset for next test")
    }
    
    // MARK: - Private Configuration Methods
    
    private func configureFirebaseApp() {
        // Use test configuration
        guard let path = Bundle(for: FirebaseTestingSetup.self).path(forResource: "GoogleService-Info-Test", ofType: "plist") else {
            // Fallback to dev configuration for testing
            FirebaseApp.configure()
            return
        }
        
        guard let options = FirebaseOptions(contentsOfFile: path) else {
            fatalError("Failed to load Firebase options from test configuration")
        }
        
        FirebaseApp.configure(options: options)
    }
    
    private func connectToEmulators() {
        // Connect Auth to emulator
        Auth.auth().useEmulator(withHost: "localhost", port: EmulatorPorts.auth)
        
        // Connect Firestore to emulator
        let db = Firestore.firestore()
        db.useEmulator(withHost: "localhost", port: EmulatorPorts.firestore)
        
        // Disable SSL for emulator
        let settings = db.settings
        settings.isSSLEnabled = false
        settings.host = "localhost:\(EmulatorPorts.firestore)"
        db.settings = settings
    }
    
    private func clearFirestoreData() async {
        let db = Firestore.firestore()
        
        // Clear all test collections
        let collections = ["users", "families", "projects", "phases", "tasks", "taskLists"]
        
        await withTaskGroup(of: Void.self) { group in
            for collectionName in collections {
                group.addTask {
                    await self.deleteCollection(db.collection(collectionName))
                }
            }
        }
    }
    
    private func deleteCollection(_ collection: CollectionReference) async {
        do {
            let snapshot = try await collection.limit(to: 100).getDocuments()
            
            // Delete documents in batches
            let batch = collection.firestore.batch()
            snapshot.documents.forEach { document in
                batch.deleteDocument(document.reference)
            }
            
            try await batch.commit()
            
            // Recursively delete if more documents exist
            if !snapshot.documents.isEmpty {
                await deleteCollection(collection)
            }
        } catch {
            print("⚠️ Error clearing collection \(collection.path): \(error)")
        }
    }
}

/// Base test case for Firebase integration tests
///
/// Inherit from this class for tests that need Firebase functionality:
/// ```swift
/// class MyFirebaseTests: FirebaseTestCase {
///     func testUserCreation() async throws {
///         // Test Firebase functionality here
///     }
/// }
/// ```
class FirebaseTestCase: XCTestCase {
    
    override func setUp() async throws {
        try await super.setUp()
        FirebaseTestingSetup.shared.configureForTesting()
    }
    
    override func tearDown() async throws {
        await FirebaseTestingSetup.shared.resetForTesting()
        try await super.tearDown()
    }
    
    /// Creates a test user for authentication testing
    func createTestUser(email: String = "test@example.com", password: String = "testpassword123") async throws -> User {
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        return authResult.user
    }
    
    /// Signs in a test user
    func signInTestUser(email: String = "test@example.com", password: String = "testpassword123") async throws -> User {
        let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
        return authResult.user
    }
    
    /// Creates test data in Firestore
    func createTestData<T: Codable>(in collection: String, document: String? = nil, data: T) async throws -> DocumentReference {
        let db = Firestore.firestore()
        let collectionRef = db.collection(collection)
        
        if let document = document {
            let docRef = collectionRef.document(document)
            try docRef.setData(from: data)
            return docRef
        } else {
            return try collectionRef.addDocument(from: data)
        }
    }
    
    /// Waits for Firestore operations to complete
    func waitForFirestore(timeout: TimeInterval = 5.0) async {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }
}

/// Mock data factory for testing
struct FirebaseTestDataFactory {
    
    static func createTestUser(id: String = UUID().uuidString) -> [String: Any] {
        return [
            "id": id,
            "email": "test-\(id)@example.com",
            "displayName": "Test User \(id.prefix(8))",
            "createdAt": Timestamp(),
            "updatedAt": Timestamp()
        ]
    }
    
    static func createTestFamily(id: String = UUID().uuidString, ownerID: String) -> [String: Any] {
        return [
            "id": id,
            "name": "Test Family \(id.prefix(8))",
            "ownerID": ownerID,
            "memberIDs": [ownerID],
            "createdAt": Timestamp(),
            "updatedAt": Timestamp()
        ]
    }
    
    static func createTestProject(id: String = UUID().uuidString, familyID: String) -> [String: Any] {
        return [
            "id": id,
            "title": "Test Project \(id.prefix(8))",
            "description": "A test project for unit testing",
            "familyID": familyID,
            "status": "active",
            "createdAt": Timestamp(),
            "updatedAt": Timestamp()
        ]
    }
    
    static func createTestTask(id: String = UUID().uuidString, projectID: String) -> [String: Any] {
        return [
            "id": id,
            "title": "Test Task \(id.prefix(8))",
            "description": "A test task for unit testing",
            "projectID": projectID,
            "isCompleted": false,
            "priority": "medium",
            "createdAt": Timestamp(),
            "updatedAt": Timestamp()
        ]
    }
}