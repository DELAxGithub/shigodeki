import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class SimpleAuthenticationManager: ObservableObject {
    static let shared = SimpleAuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    private init() {
        // Listen for authentication state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = user != nil
                if let user = user {
                    await self?.loadUserData(uid: user.uid)
                } else {
                    self?.currentUser = nil
                }
            }
        }
    }
    
    func signInAnonymously() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await auth.signInAnonymously()
            let user = result.user
            await saveUserToFirestore(uid: user.uid, name: "Demo User", email: "")
            isLoading = false
        } catch {
            print("Anonymous sign in error: \(error)")
            // Fallback to demo email sign in
            await signInWithDemoEmail()
        }
    }
    
    private func signInWithDemoEmail() async {
        let email = "demo@shigodeki.com"
        let password = "demo123456"
        
        do {
            // Try to sign in first
            let result = try await auth.signIn(withEmail: email, password: password)
            let user = result.user
            await saveUserToFirestore(uid: user.uid, name: "Demo User", email: email)
            isLoading = false
            print("Demo email sign in successful")
        } catch {
            // If sign in fails, try to create account
            do {
                let result = try await auth.createUser(withEmail: email, password: password)
                let user = result.user
                await saveUserToFirestore(uid: user.uid, name: "Demo User", email: email)
                isLoading = false
                print("Demo account created successfully")
            } catch {
                print("Demo email sign in/create failed: \(error)")
                errorMessage = "Demo sign in failed: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func signOut() async {
        do {
            try auth.signOut()
        } catch {
            print("Sign out error: \(error)")
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }
    
    private func loadUserData(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            if document.exists, let data = document.data() {
                currentUser = User(
                    name: data["name"] as? String ?? "",
                    email: data["email"] as? String ?? "",
                    familyIds: data["familyIds"] as? [String] ?? []
                )
                currentUser?.id = uid
                currentUser?.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
            }
        } catch {
            print("Error loading user data: \(error)")
            errorMessage = "Failed to load user data"
        }
    }
    
    private func saveUserToFirestore(uid: String, name: String, email: String) async {
        var user = User(name: name, email: email)
        user.id = uid
        user.createdAt = Date()
        
        let userData: [String: Any] = [
            "name": name,
            "email": email,
            "familyIds": user.familyIds,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("users").document(uid).setData(userData)
            currentUser = user
            print("User saved to Firestore successfully")
        } catch {
            print("Error saving user to Firestore: \(error)")
            errorMessage = "Failed to save user data"
        }
    }
}