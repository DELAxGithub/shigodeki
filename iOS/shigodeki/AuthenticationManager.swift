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
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    // Unhashed nonce for Apple Sign In
    fileprivate var currentNonce: String?
    
    override init() {
        super.init()
        
        // Listen for authentication state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            Task.detached { @MainActor in
                self?.isAuthenticated = user != nil
                if let user = user {
                    await self?.loadUserData(uid: user.uid)
                } else {
                    self?.currentUser = nil
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
        authorizationController.performRequests()
    }
    
    private func createAppleSignInRequest() -> ASAuthorizationAppleIDRequest? {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        return request
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
    
    // MARK: - Sign Out
    
    func signOut() {
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
        
        Task.detached { @MainActor in
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
        Task.detached { @MainActor in
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
                @unknown default:
                    errorMessage = "Apple Sign In error occurred"
                }
            } else {
                errorMessage = "Apple Sign In error: \(error.localizedDescription)"
            }
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
        let randoms: [UInt8] = (0 ..< 16).map { _ in
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }
            return random
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