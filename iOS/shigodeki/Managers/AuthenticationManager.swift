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
    // Singleton instance - accessible from any context
    static let shared = AuthenticationManager()
    
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
    
    // State management for Apple Sign In
    private var currentNonce: String? {
        get {
            // Use UserDefaults for TestFlight reliability
            return UserDefaults.standard.string(forKey: "apple_signin_nonce")
        }
        set {
            if let nonce = newValue {
                UserDefaults.standard.set(nonce, forKey: "apple_signin_nonce")
                print("🔐 Nonce stored: \(nonce.prefix(8))...")
            } else {
                UserDefaults.standard.removeObject(forKey: "apple_signin_nonce")
                print("🔐 Nonce cleared")
            }
        }
    }
    
    private var authInProgress: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "apple_signin_in_progress")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "apple_signin_in_progress")
            print("🔐 Auth in progress: \(newValue)")
        }
    }
    
    nonisolated private override init() {
        super.init()
        
        // Schedule main actor work for initialization that requires it
        Task { @MainActor in
            // Clear any stale authentication state on app launch
            self.clearAppleSignInState()
            
            // Listen for authentication state changes
            _ = self.auth.addStateDidChangeListener { [weak self] _, user in
                Task { @MainActor in
                    guard let self = self else { return }
                    if let user = user {
                        print("🔐 AuthManager: Firebase user authenticated: \(user.uid)")
                        // Set authenticated immediately for faster UI response
                        self.isAuthenticated = true
                        // Load user data asynchronously
                        await self.loadUserData(uid: user.uid)
                        print("👤 AuthManager: User data loaded, currentUserId: \(self.currentUserId ?? "nil")")
                        // Clear Apple Sign In state after successful authentication
                        self.clearAppleSignInState()
                    } else {
                        print("🔐 AuthManager: User signed out")
                        self.currentUser = nil
                        self.isAuthenticated = false
                        self.clearAppleSignInState()
                    }
                }
            }
            
            // Set up app lifecycle observers for TestFlight reliability
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.appDidEnterBackground),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.appWillEnterForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appDidEnterBackground() {
        print("🔐 App entering background, auth in progress: \(authInProgress)")
    }
    
    @objc private func appWillEnterForeground() {
        print("🔐 App entering foreground, auth in progress: \(authInProgress)")
        // Check for stale authentication state when returning from background
        if authInProgress {
            print("🔐 Recovering from background during Apple Sign In")
            // Reset state after a delay to allow for completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.authInProgress && !self.isLoading {
                    print("🔐 Clearing stale authentication state")
                    self.clearAppleSignInState()
                    self.errorMessage = "サインインがタイムアウトしました。もう一度お試しください。"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func clearAppleSignInState() {
        currentNonce = nil
        authInProgress = false
    }
    
    // MARK: - Sign in with Apple
    
    func signInWithApple() {
        // Prevent multiple simultaneous requests
        guard !authInProgress else {
            print("🔐 Apple Sign In already in progress, ignoring request")
            return
        }
        
        guard let request = createAppleSignInRequest() else {
            errorMessage = "Apple Sign In request creation failed"
            return
        }
        
        isLoading = true
        errorMessage = nil
        authInProgress = true
        
        print("🔐 Starting Apple Sign In flow")
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    // Remove the handleSignInWithApple method as we'll use the delegate pattern exclusively
    
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
                // Check if migration is needed and perform it
                await migrateUserDataIfNeeded(uid: uid, data: data)
                
                // Manual parsing from Firestore data with new User structure
                currentUser = User(
                    name: data["name"] as? String ?? "",
                    email: data["email"] as? String ?? "",
                    projectIds: data["projectIds"] as? [String] ?? [],
                    roleAssignments: data["roleAssignments"] as? [String: Role] ?? [:]
                )
                currentUser?.id = uid
                currentUser?.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                print("👤 User data loaded: \(currentUser?.name ?? "nil"), projectIds: \(currentUser?.projectIds.count ?? 0)")
            } else {
                print("⚠️ No user document found for UID: \(uid)")
                // Create user document for authenticated user without Firestore record
                if let authUser = auth.currentUser {
                    let name = authUser.displayName ?? "Unknown User"
                    let email = authUser.email ?? ""
                    print("🔄 Creating missing user document for: \(name)")
                    await saveUserToFirestore(uid: uid, name: name, email: email)
                }
            }
        } catch {
            print("Error loading user data: \(error)")
            errorMessage = "Failed to load user data"
        }
    }
    
    private func saveUserToFirestore(uid: String, name: String, email: String) async {
        var user = User(name: name, email: email, projectIds: [], roleAssignments: [:])
        user.id = uid
        user.createdAt = Date()
        
        let userData: [String: Any] = [
            "name": name,
            "email": email,
            "projectIds": user.projectIds,
            "roleAssignments": user.roleAssignments,
            "familyIds": user.familyIds ?? [],
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("users").document(uid).setData(userData)
            currentUser = user
            print("✅ User saved to Firestore successfully with new structure")
            print("👤 User details: name=\(name), email=\(email), uid=\(uid)")
        } catch {
            print("❌ Error saving user to Firestore: \(error)")
            errorMessage = "Failed to save user data"
        }
    }
    
    // MARK: - User Data Migration
    
    private func migrateUserDataIfNeeded(uid: String, data: [String: Any]) async {
        // Check if migration is needed (missing projectIds or roleAssignments)
        let hasProjectIds = data["projectIds"] != nil
        let hasRoleAssignments = data["roleAssignments"] != nil
        
        if !hasProjectIds || !hasRoleAssignments {
            print("🔄 Migrating user data to new structure for UID: \(uid)")
            
            let migratedData: [String: Any] = [
                "name": data["name"] as? String ?? "",
                "email": data["email"] as? String ?? "",
                "projectIds": data["projectIds"] as? [String] ?? [],
                "roleAssignments": data["roleAssignments"] as? [String: Any] ?? [:],
                "familyIds": data["familyIds"] as? [String] ?? [],
                "createdAt": data["createdAt"] ?? FieldValue.serverTimestamp()
            ]
            
            do {
                try await db.collection("users").document(uid).setData(migratedData, merge: true)
                print("✅ User data migrated successfully")
            } catch {
                print("❌ User data migration failed: \(error)")
            }
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
        print("🔐 Apple Sign In authorization received")
        
        Task { @MainActor in
            defer { 
                isLoading = false 
                authInProgress = false
            }
            
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                print("❌ Invalid Apple ID credential")
                errorMessage = "Apple Sign In credential processing failed"
                clearAppleSignInState()
                return
            }
            
            guard let nonce = currentNonce else {
                print("❌ No nonce found - this is the TestFlight bug!")
                print("📊 Debug info - Auth in progress: \(authInProgress)")
                print("📊 Debug info - UserDefaults nonce: \(UserDefaults.standard.string(forKey: "apple_signin_nonce") ?? "nil")")
                
                // Enhanced error message for TestFlight
                errorMessage = "認証エラーが発生しました。アプリを再起動してもう一度お試しください。"
                clearAppleSignInState()
                return
            }
            
            guard let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("❌ Failed to process Apple ID token")
                errorMessage = "Apple ID トークンの処理に失敗しました"
                clearAppleSignInState()
                return
            }
            
            print("🔐 Processing Apple Sign In with nonce: \(nonce.prefix(8))...")
            
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString, 
                rawNonce: nonce, 
                fullName: appleIDCredential.fullName
            )
            
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
                
                print("✅ Apple Sign In successful for user: \(user.uid)")
                
                // Save user data to Firestore
                await saveUserToFirestore(uid: user.uid, name: name, email: email)
                
                // Clear Apple Sign In state will be done in the auth state listener
                
            } catch {
                print("❌ Firebase authentication error: \(error)")
                if let authError = error as? AuthErrorCode {
                    switch authError.code {
                    case .invalidCredential:
                        errorMessage = "認証情報が無効です。もう一度お試しください。"
                    case .networkError:
                        errorMessage = "ネットワークエラーです。接続を確認してください。"
                    case .tooManyRequests:
                        errorMessage = "リクエストが多すぎます。しばらく時間をおいてください。"
                    default:
                        errorMessage = "認証に失敗しました: \(error.localizedDescription)"
                    }
                } else {
                    errorMessage = "認証に失敗しました: \(error.localizedDescription)"
                }
                clearAppleSignInState()
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Apple Sign In error: \(error)")
        
        Task { @MainActor in
            defer {
                isLoading = false
                authInProgress = false
                clearAppleSignInState()
            }
            
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    print("🔐 Apple Sign In cancelled by user")
                    errorMessage = nil // User cancelled, don't show error
                case .failed:
                    print("❌ Apple Sign In failed")
                    errorMessage = "Apple Sign Inに失敗しました"
                case .invalidResponse:
                    print("❌ Invalid response from Apple")
                    errorMessage = "Appleからの応答が無効です"
                case .notHandled:
                    print("❌ Apple Sign In not handled")
                    errorMessage = "Apple Sign Inが処理されませんでした"
                case .unknown:
                    print("❌ Unknown Apple Sign In error")
                    errorMessage = "不明なエラーが発生しました"
                case .notInteractive:
                    print("❌ Apple Sign In not interactive")
                    errorMessage = "インタラクティブでないApple Sign Inエラー"
                case .matchedExcludedCredential:
                    print("❌ Excluded credential matched")
                    errorMessage = "除外された認証情報がマッチしました"
                case .credentialImport:
                    print("❌ Credential import error")
                    errorMessage = "認証情報のインポートエラー"
                case .credentialExport:
                    print("❌ Credential export error")
                    errorMessage = "認証情報のエクスポートエラー"
                @unknown default:
                    print("❌ Unknown Apple Sign In error case")
                    errorMessage = "Apple Sign Inでエラーが発生しました"
                }
            } else {
                print("❌ General Apple Sign In error: \(error.localizedDescription)")
                errorMessage = "Apple Sign Inエラー: \(error.localizedDescription)"
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