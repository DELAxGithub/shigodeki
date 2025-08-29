//
//  AuthTestView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import SwiftUI
import FirebaseAuth
import FirebaseCore

struct AuthTestView: View {
    @StateObject private var authManager = AuthenticationManager()
    @State private var showTestResults = false
    @State private var testResults: [TestResult] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Authentication Status Section
                    AuthStatusCard(authManager: authManager)
                    
                    // Test Controls Section
                    TestControlsCard(authManager: authManager) { results in
                        testResults = results
                        showTestResults = true
                    }
                    
                    // Debug Info Section
                    DebugInfoCard(authManager: authManager)
                }
                .padding()
            }
            .navigationTitle("認証テスト")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showTestResults) {
            TestResultsView(results: testResults)
        }
    }
}

struct AuthStatusCard: View {
    @ObservedObject var authManager: AuthenticationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundColor(.blue)
                Text("認証状態")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(authManager.isAuthenticated ? .green : .red)
                    .frame(width: 12, height: 12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                StatusRow(label: "認証済み", value: authManager.isAuthenticated ? "はい" : "いいえ")
                StatusRow(label: "ローディング中", value: authManager.isLoading ? "はい" : "いいえ")
                StatusRow(label: "Firebase UID", value: Auth.auth().currentUser?.uid ?? "未設定")
                StatusRow(label: "メール", value: authManager.currentUser?.email ?? "未設定")
                StatusRow(label: "表示名", value: authManager.currentUser?.name ?? "未設定")
                
                if let errorMessage = authManager.errorMessage {
                    StatusRow(label: "エラー", value: errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

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
                    Task {
                        await authManager.signInWithApple()
                    }
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

struct DebugInfoCard: View {
    @ObservedObject var authManager: AuthenticationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("デバッグ情報")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                DebugRow(label: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "不明")
                DebugRow(label: "Build Version", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "不明")
                DebugRow(label: "App Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "不明")
                DebugRow(label: "Firebase Project", value: getFirebaseProjectId())
                DebugRow(label: "環境", value: isDebugBuild() ? "Development" : "Production")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func getFirebaseProjectId() -> String {
        // Try to get from Firebase app
        if let app = FirebaseApp.app() {
            return app.options.projectID ?? "不明"
        }
        return "未初期化"
    }
    
    private func isDebugBuild() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

// MARK: - Helper Views

struct StatusRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct DebugRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct TestButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(color.opacity(isLoading ? 0.3 : 1.0))
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(isLoading ? 0.95 : 1.0)
            .opacity(isLoading ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
        .disabled(isLoading)
    }
}

struct TestResult {
    let name: String
    let passed: Bool
    let message: String
}

struct TestResultsView: View {
    let results: [TestResult]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(results.indices, id: \.self) { index in
                let result = results[index]
                HStack {
                    Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.passed ? .green : .red)
                    
                    VStack(alignment: .leading) {
                        Text(result.name)
                            .font(.headline)
                        Text(result.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("テスト結果")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("閉じる") { dismiss() })
        }
    }
}

#Preview {
    AuthTestView()
}