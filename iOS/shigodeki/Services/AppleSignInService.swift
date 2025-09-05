//
//  AppleSignInService.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import Foundation
import AuthenticationServices
import FirebaseAuth
import CryptoKit

struct AppleSignInService {
    
    // MARK: - State Management
    
    static var currentNonce: String? {
        get {
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
    
    static var authInProgress: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "apple_signin_in_progress")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "apple_signin_in_progress")
            print("🔐 Auth in progress: \(newValue)")
        }
    }
    
    static func clearAppleSignInState() {
        currentNonce = nil
        authInProgress = false
    }
    
    // MARK: - Apple Sign In Request Creation
    
    static func createAppleSignInRequest() -> ASAuthorizationAppleIDRequest? {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        return request
    }
    
    // MARK: - Credential Processing
    
    static func processAppleIDCredential(
        _ credential: ASAuthorizationAppleIDCredential,
        nonce: String
    ) async throws -> AuthDataResult {
        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AppleSignInError.invalidToken
        }
        
        print("🔐 Processing Apple Sign In with nonce: \(nonce.prefix(8))...")
        
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        
        let result = try await Auth.auth().signIn(with: firebaseCredential)
        return result
    }
    
    static func extractUserInfo(from credential: ASAuthorizationAppleIDCredential, firebaseUser: FirebaseAuth.User) -> (name: String, email: String) {
        let fullName = credential.fullName
        let displayName = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        
        let name = displayName.isEmpty ? firebaseUser.displayName ?? "Unknown User" : displayName
        let email = credential.email ?? firebaseUser.email ?? ""
        
        return (name, email)
    }
    
    // MARK: - Error Handling
    
    static func handleAppleSignInError(_ error: Error) -> String? {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                print("🔐 Apple Sign In cancelled by user")
                return nil // User cancelled, don't show error
            case .failed:
                print("❌ Apple Sign In failed")
                return "Apple Sign Inに失敗しました"
            case .invalidResponse:
                print("❌ Invalid response from Apple")
                return "Appleからの応答が無効です"
            case .notHandled:
                print("❌ Apple Sign In not handled")
                return "Apple Sign Inが処理されませんでした"
            case .unknown:
                print("❌ Unknown Apple Sign In error")
                return "不明なエラーが発生しました"
            case .notInteractive:
                print("❌ Apple Sign In not interactive")
                return "インタラクティブでないApple Sign Inエラー"
            case .matchedExcludedCredential:
                print("❌ Excluded credential matched")
                return "除外された認証情報がマッチしました"
            case .credentialImport:
                print("❌ Credential import error")
                return "認証情報のインポートエラー"
            case .credentialExport:
                print("❌ Credential export error")
                return "認証情報のエクスポートエラー"
            @unknown default:
                print("❌ Unknown Apple Sign In error case")
                return "Apple Sign Inでエラーが発生しました"
            }
        } else {
            print("❌ General Apple Sign In error: \(error.localizedDescription)")
            return "Apple Sign Inエラー: \(error.localizedDescription)"
        }
    }
    
    static func handleFirebaseAuthError(_ error: Error) -> String {
        print("❌ Firebase authentication error: \(error)")
        if let authError = error as? AuthErrorCode {
            switch authError.code {
            case .invalidCredential:
                return "認証情報が無効です。もう一度お試しください。"
            case .networkError:
                return "ネットワークエラーです。接続を確認してください。"
            case .tooManyRequests:
                return "リクエストが多すぎます。しばらく時間をおいてください。"
            default:
                return "認証に失敗しました: \(error.localizedDescription)"
            }
        } else {
            return "認証に失敗しました: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Crypto Helper Functions
    
    private static func randomNonceString(length: Int = 32) -> String {
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
                    print("⚠️ Crypto: Failed to generate secure random byte (OSStatus: \(errorCode))")
                    return nil
                }
                return random
            }
            
            // If we couldn't generate any random bytes, use fallback
            guard !randoms.isEmpty else {
                print("❌ Crypto: Critical - Unable to generate secure random bytes, using fallback")
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
    
    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - Supporting Types

enum AppleSignInError: Error {
    case invalidToken
    case noNonce
    case invalidCredential
}

extension AppleSignInError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Apple ID トークンの処理に失敗しました"
        case .noNonce:
            return "認証エラーが発生しました。アプリを再起動してもう一度お試しください。"
        case .invalidCredential:
            return "Apple Sign In credential processing failed"
        }
    }
}