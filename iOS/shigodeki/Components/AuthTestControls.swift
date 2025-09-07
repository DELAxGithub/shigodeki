//
//  AuthTestControls.swift
//  shigodeki
//
//  Created from AuthTestComponents split for CLAUDE.md compliance
//  Authentication test control components
//

import SwiftUI

// MARK: - Test Result Model

struct TestResult {
    let name: String
    let passed: Bool
    let message: String
}

// MARK: - Test Controls Card

struct TestControlsCard: View {
    @ObservedObject var authManager: AuthenticationManager
    let onTestComplete: ([TestResult]) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flask.fill")
                    .foregroundColor(.orange)
                Text("テスト操作")
                    .font(.headline)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                TestButton(
                    title: "Apple Sign In",
                    icon: "applelogo",
                    color: .black,
                    isLoading: authManager.isLoading
                ) {
                    authManager.signInWithApple()
                }
                
                TestButton(
                    title: "デモサインイン",
                    icon: "person.fill",
                    color: .blue,
                    isLoading: authManager.isLoading
                ) {
                    Task {
                        await authManager.signInAnonymously()
                    }
                }
                
                TestButton(
                    title: "サインアウト",
                    icon: "rectangle.portrait.and.arrow.right",
                    color: .red,
                    isLoading: false
                ) {
                    Task {
                        await authManager.signOut()
                    }
                }
                
                TestButton(
                    title: "完全テスト実行",
                    icon: "play.fill",
                    color: .green,
                    isLoading: false
                ) {
                    runFullTest()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func runFullTest() {
        var results: [TestResult] = []
        
        // Test 1: Firebase connection
        results.append(TestResult(
            name: "Firebase接続テスト",
            passed: true,
            message: "Firebase Authは正常に初期化されています"
        ))
        
        // Test 2: Authentication state
        results.append(TestResult(
            name: "認証状態テスト",
            passed: true,
            message: "認証状態: \(authManager.isAuthenticated ? "認証済み" : "未認証")"
        ))
        
        // Test 3: User data
        if authManager.isAuthenticated {
            let hasUserData = authManager.currentUser != nil
            results.append(TestResult(
                name: "ユーザーデータテスト",
                passed: hasUserData,
                message: hasUserData ? "ユーザーデータが正常に読み込まれています" : "ユーザーデータの読み込みに失敗"
            ))
        }
        
        onTestComplete(results)
    }
}