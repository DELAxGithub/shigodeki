//
//  DemoAuthService.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import Foundation
import FirebaseAuth

struct DemoAuthService {
    private static let demoEmail = "demo@shigodeki.com"
    private static let demoPassword = "demo123456"
    
    // MARK: - Anonymous Sign In
    
    static func signInAnonymously() async throws -> AuthDataResult {
        do {
            let result = try await Auth.auth().signInAnonymously()
            print("Anonymous sign in successful")
            return result
        } catch {
            print("Anonymous sign in error: \(error)")
            // Fallback to demo email sign in
            return try await signInWithDemoEmail()
        }
    }
    
    // MARK: - Demo Email Sign In
    
    static func signInWithDemoEmail() async throws -> AuthDataResult {
        do {
            // Try to sign in first
            let result = try await Auth.auth().signIn(withEmail: demoEmail, password: demoPassword)
            print("Demo email sign in successful")
            return result
        } catch {
            // If sign in fails, try to create account
            do {
                let result = try await Auth.auth().createUser(withEmail: demoEmail, password: demoPassword)
                print("Demo account created successfully")
                return result
            } catch {
                print("Demo email sign in/create failed: \(error)")
                throw DemoAuthError.signInFailed(error)
            }
        }
    }
    
    // MARK: - User Info for Demo
    
    static func getDemoUserInfo() -> (name: String, email: String) {
        return ("Demo User", demoEmail)
    }
}

// MARK: - Supporting Types

enum DemoAuthError: Error {
    case signInFailed(Error)
}

extension DemoAuthError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .signInFailed(let error):
            return "Demo sign in failed: \(error.localizedDescription)"
        }
    }
}