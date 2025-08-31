//
//  AuthenticationManager.swift
//  shigodeki
//
//  Created by Claude on 2025-08-27.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    /// Convenience property to get current user ID
    /// Falls back to Firebase Auth if User model isn't loaded yet
    var currentUserId: String? {
        if let userId = currentUser?.id {
            return userId
        }
        // Fallback to Firebase Auth user if User model not loaded yet
        return auth.currentUser?.uid
    }
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    // Unhashed nonce for Apple Sign In
    fileprivate var currentNonce: String?
    
    override init() {
        super.init()
        
        // Listen for authentication state changes
        _ = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }
                if let user = user {
                    print("🔐 AuthManager: Firebase user authenticated: \(user.uid)")
                    // Set authenticated immediately for faster UI response
                    self.isAuthenticated = true
                    // Load user data asynchronously
                    await self.loadUserData(uid: user.uid)
                    print("👤 AuthManager: User data loaded, currentUserId: \(self.currentUserId ?? "nil")")
                } else {
                    print("🔐 AuthManager: User signed out")
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
            }
        }
    }
    
    // MARK: - Sign in with Apple
    
    func signInWithApple() async {
        guard let request = createAppleSignInRequest() else {
            errorMessage = "Apple Sign In request creation failed"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func handleSignInWithApple(result: Result<ASAuthorization, Error>) {
        isLoading = true
        errorMessage = nil
        
        switch result {
        case .success(let authorization):
            Task {
                await processAppleSignInAuthorization(authorization)
            }
        case .failure(let error):
            print("Apple Sign In error: \(error)")
            errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func createAppleSignInRequest() -> ASAuthorizationAppleIDRequest? {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        return request
    }
    
    private func processAppleSignInAuthorization(_ authorization: ASAuthorization) async {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Invalid Apple ID credential"
            isLoading = false
            return
        }
        
        guard let nonce = currentNonce else {
            errorMessage = "Invalid state: A login callback was received, but no login request was sent."
            isLoading = false
            return
        }
        
        guard let appleIDToken = appleIDCredential.identityToken else {
            errorMessage = "Unable to fetch identity token"
            isLoading = false
            return
        }
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            errorMessage = "Unable to serialize token string from data"
            isLoading = false
            return
        }
        
        // Initialize Firebase Auth credential  
        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString, 
                                                      rawNonce: nonce, 
                                                      fullName: appleIDCredential.fullName)
        
        do {
            let authResult = try await auth.signIn(with: credential)
            let user = authResult.user
            
            // Extract user info
            let displayName = appleIDCredential.fullName?.givenName ?? user.displayName ?? "User"
            let email = appleIDCredential.email ?? user.email ?? ""
            
            // Save user to Firestore
            await saveUserToFirestore(uid: user.uid, name: displayName, email: email)
            
            isLoading = false
            print("Successfully signed in with Apple")
            
        } catch {
            print("Error signing in with Apple: \(error)")
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - User Data Management
    
    private func loadUserData(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            if document.exists, let data = document.data() {
                // Manual parsing from Firestore data
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
            "familyIds": user.familyIds ?? [],
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
    
    // MARK: - Anonymous Sign In (Demo)
    
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
    
    // MARK: - User Profile Updates
    
    func updateUserName(_ newName: String) async {
        guard let uid = currentUserId, !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Invalid name or user not authenticated"
            return
        }
        
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        isLoading = true
        errorMessage = nil
        
        do {
            // Update in Firestore
            try await db.collection("users").document(uid).updateData([
                "name": trimmedName
            ])
            
            // Update local user object by creating new instance
            if let user = currentUser {
                let updatedUser = User(
                    name: trimmedName,
                    email: user.email,
                    projectIds: user.projectIds,
                    roleAssignments: user.roleAssignments
                )
                var newUser = updatedUser
                newUser.id = user.id
                newUser.createdAt = user.createdAt
                newUser.lastActiveAt = user.lastActiveAt
                newUser.preferences = user.preferences
                currentUser = newUser
            }
            
            print("✅ User name updated successfully to: \(trimmedName)")
            isLoading = false
        } catch {
            print("❌ Failed to update user name: \(error)")
            errorMessage = "名前の更新に失敗しました"
            isLoading = false
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        do {
            try auth.signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            print("Error signing out: \(error)")
            errorMessage = "Failed to sign out"
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationManager: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        
        Task { @MainActor in
            defer { isLoading = false }
            
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                errorMessage = "Apple Sign In credential processing failed"
                return
            }
            
            let credential = OAuthProvider.appleCredential(withIDToken: idTokenString, 
                                                          rawNonce: nonce, 
                                                          fullName: appleIDCredential.fullName)
            
            do {
                let result = try await auth.signIn(with: credential)
                let user = result.user
                
                // Extract user info from Apple ID credential
                let fullName = appleIDCredential.fullName
                let displayName = [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                let name = displayName.isEmpty ? user.displayName ?? "Unknown User" : displayName
                let email = appleIDCredential.email ?? user.email ?? ""
                
                // Save user data to Firestore
                await saveUserToFirestore(uid: user.uid, name: name, email: email)
                
            } catch {
                print("Firebase authentication error: \(error)")
                errorMessage = "Authentication failed: \(error.localizedDescription)"
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            isLoading = false
            print("Apple Sign In error: \(error)")
            
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    errorMessage = nil // User cancelled, don't show error
                case .failed:
                    errorMessage = "Apple Sign In failed"
                case .invalidResponse:
                    errorMessage = "Invalid response from Apple"
                case .notHandled:
                    errorMessage = "Apple Sign In not handled"
                case .unknown:
                    errorMessage = "Unknown Apple Sign In error"
                case .notInteractive:
                    errorMessage = "Apple Sign In not interactive"
                case .matchedExcludedCredential:
                    errorMessage = "Excluded credential matched"
                case .credentialImport:
                    errorMessage = "Credential import error"
                case .credentialExport:
                    errorMessage = "Credential export error"
                @unknown default:
                    errorMessage = "Apple Sign In error occurred"
                }
            } else {
                errorMessage = "Apple Sign In error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).compactMap { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    // Log error and return nil instead of crashing
                    print("⚠️ Crypto: Failed to generate secure random byte (OSStatus: \(errorCode))")
                    return nil
                }
                return random
            }
            
            // If we couldn't generate any random bytes, use fallback
            guard !randoms.isEmpty else {
                print("❌ Crypto: Critical - Unable to generate secure random bytes, using fallback")
                // Use UUID as fallback for nonce generation
                let fallbackNonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
                return String(fallbackNonce.prefix(length))
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}