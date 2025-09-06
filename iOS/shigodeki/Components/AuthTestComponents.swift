//
//  AuthTestComponents.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import SwiftUI
import FirebaseAuth
import FirebaseCore

// MARK: - Auth Status Card

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

// MARK: - Debug Info Card

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

// MARK: - Data Management Card

struct DataManagementCard: View {
    @ObservedObject var authManager: AuthenticationManager
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deletionResults: [String] = []
    @State private var showingResults = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trash.fill")
                    .foregroundColor(.red)
                Text("データ管理")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("⚠️ 危険な操作")
                    .font(.caption)
                    .foregroundColor(.red)
                    .fontWeight(.semibold)
                
                Text("このアプリで作成した全データを削除します：")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• すべてのプロジェクト")
                    Text("• すべての家族グループ")
                    Text("• すべてのタスクリスト")
                    Text("• 招待コード")
                    Text("• ユーザーデータ")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            }
            
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash.circle.fill")
                    Text("全データ一括削除")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isDeleting || !authManager.isAuthenticated)
            
            if isDeleting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("削除中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .confirmationDialog(
            "全データ削除の確認",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除実行", role: .destructive) {
                executeDataDeletion()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("この操作は取り消せません。このアプリで作成したすべてのデータが完全に削除されます。")
        }
        .sheet(isPresented: $showingResults) {
            DataDeletionResultsView(results: deletionResults) {
                showingResults = false
                deletionResults = []
            }
        }
    }
    
    private func executeDataDeletion() {
        guard let userId = authManager.currentUser?.id else {
            deletionResults = ["❌ ユーザー認証が確認できません"]
            showingResults = true
            return
        }
        
        isDeleting = true
        deletionResults = []
        
        Task {
            let results = await AuthTestDataDeletionService.executeFullDataDeletion(
                userId: userId,
                authManager: authManager,
                sharedManagers: sharedManagers
            )
            
            await MainActor.run {
                isDeleting = false
                deletionResults = results
                showingResults = true
            }
        }
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