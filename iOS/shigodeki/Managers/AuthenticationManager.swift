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
import UIKit

@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var currentUserId: String? {
        return currentUser?.id ?? auth.currentUser?.uid
    }
    
    private let auth = Auth.auth()
    private let userDataService = UserDataService()
    
    nonisolated private override init() {
        super.init()
        
        Task { @MainActor in
            setupAuthStateListener()
            setupAppLifecycleObservers()
            AppleSignInService.clearAppleSignInState()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupAuthStateListener() {
        _ = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }
                if let user = user {
                    print("🔐 AuthManager: Firebase user authenticated: \(user.uid)")
                    self.isAuthenticated = true
                    await self.handleUserAuthenticated(user)
                    AppleSignInService.clearAppleSignInState()
                } else {
                    print("🔐 AuthManager: User signed out")
                    self.handleUserSignedOut()
                }
            }
        }
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        print("🔐 App entering background, auth in progress: \(AppleSignInService.authInProgress)")
    }
    
    @objc private func appWillEnterForeground() {
        print("🔐 App entering foreground, auth in progress: \(AppleSignInService.authInProgress)")
        handleForegroundAuthRecovery()
    }
    
    // MARK: - Authentication Methods
    
    func signInWithApple() {
        guard !AppleSignInService.authInProgress else {
            print("🔐 Apple Sign In already in progress, ignoring request")
            return
        }
        
        guard let request = AppleSignInService.createAppleSignInRequest() else {
            errorMessage = "Apple Sign In request creation failed"
            return
        }
        
        startAuthenticationFlow()
        
        print("🔐 Starting Apple Sign In flow")
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func signInAnonymously() async {
        startAuthenticationFlow()
        
        do {
            let result = try await DemoAuthService.signInAnonymously()
            let (name, email) = DemoAuthService.getDemoUserInfo()
            await saveUserData(uid: result.user.uid, name: name, email: email)
        } catch {
            print("Anonymous sign in error: \(error)")
            handleAuthenticationError(error.localizedDescription)
        }
    }
    
    func updateUserName(_ newName: String) async {
        guard let uid = currentUserId, !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Invalid name or user not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let success = await userDataService.updateUserName(uid: uid, newName: newName)
        if success {
            updateCurrentUserName(newName)
        } else {
            errorMessage = "名前の更新に失敗しました"
        }
        
        isLoading = false
    }
    
    func signOut() async {
        do {
            try auth.signOut()
            handleUserSignedOut()
        } catch {
            print("Error signing out: \(error)")
            errorMessage = "Failed to sign out"
        }
    }
    
    // MARK: - Helper Methods
    
    private func startAuthenticationFlow() {
        isLoading = true
        errorMessage = nil
        AppleSignInService.authInProgress = true
    }
    
    private func handleUserAuthenticated(_ user: FirebaseAuth.User) async {
        if let userData = await userDataService.loadUserData(uid: user.uid) {
            currentUser = userData
        } else {
            // Create missing user document
            currentUser = await userDataService.createMissingUserDocument(authUser: user)
        }
        print("👤 AuthManager: User data loaded, currentUserId: \(currentUserId ?? "nil")")
    }
    
    private func handleUserSignedOut() {
        currentUser = nil
        isAuthenticated = false
        AppleSignInService.clearAppleSignInState()
    }
    
    private func saveUserData(uid: String, name: String, email: String) async {
        if let user = await userDataService.saveUserToFirestore(uid: uid, name: name, email: email) {
            currentUser = user
        }
        isLoading = false
    }
    
    private func handleAuthenticationError(_ message: String) {
        errorMessage = message
        isLoading = false
        AppleSignInService.authInProgress = false
    }
    
    private func handleForegroundAuthRecovery() {
        if AppleSignInService.authInProgress {
            print("🔐 Recovering from background during Apple Sign In")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if AppleSignInService.authInProgress && !self.isLoading {
                    print("🔐 Clearing stale authentication state")
                    AppleSignInService.clearAppleSignInState()
                    self.errorMessage = "サインインがタイムアウトしました。もう一度お試しください。"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func updateCurrentUserName(_ newName: String) {
        guard let user = currentUser else { return }
        
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
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
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("🔐 Apple Sign In authorization received")
        
        Task { @MainActor in
            defer {
                isLoading = false
                AppleSignInService.authInProgress = false
            }
            
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                print("❌ Invalid Apple ID credential")
                errorMessage = "Apple Sign In credential processing failed"
                AppleSignInService.clearAppleSignInState()
                return
            }
            
            guard let nonce = AppleSignInService.currentNonce else {
                print("❌ No nonce found - this is the TestFlight bug!")
                errorMessage = "認証エラーが発生しました。アプリを再起動してもう一度お試しください。"
                AppleSignInService.clearAppleSignInState()
                return
            }
            
            do {
                let result = try await AppleSignInService.processAppleIDCredential(appleIDCredential, nonce: nonce)
                let (name, email) = AppleSignInService.extractUserInfo(from: appleIDCredential, firebaseUser: result.user)
                
                print("✅ Apple Sign In successful for user: \(result.user.uid)")
                await saveUserData(uid: result.user.uid, name: name, email: email)
                
            } catch {
                errorMessage = AppleSignInService.handleFirebaseAuthError(error)
                AppleSignInService.clearAppleSignInState()
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Apple Sign In error: \(error)")
        
        Task { @MainActor in
            defer {
                isLoading = false
                AppleSignInService.authInProgress = false
                AppleSignInService.clearAppleSignInState()
            }
            
            errorMessage = AppleSignInService.handleAppleSignInError(error)
        }
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