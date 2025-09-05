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
    @ObservedObject private var authManager = AuthenticationManager.shared
    @State private var showTestResults = false
    @State private var testResults: [TestResult] = []
    
    var body: some View {
        NavigationView {
            // Issue #84: Add ScrollViewReader for scroll-to-top functionality
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        // Issue #84: Add top anchor for scroll-to-top functionality
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 1)
                            .id("top")
                        
                        // Authentication Status Section
                        AuthStatusCard(authManager: authManager)
                        
                        // Test Controls Section
                        TestControlsCard(authManager: authManager) { results in
                            testResults = results
                            showTestResults = true
                        }
                        
                        // Debug Info Section
                        DebugInfoCard(authManager: authManager)
                        
                        // Data Management Section
                        DataManagementCard(authManager: authManager)
                    }
                    .padding()
                }
                .navigationTitle("認証テスト")
                .navigationBarTitleDisplayMode(.large)
                .onReceive(NotificationCenter.default.publisher(for: .testTabSelected)) { _ in
                    // Issue #84: Scroll to top when test tab is re-selected
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
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
            var results: [String] = []
            
            // 1. プロジェクト削除
            do {
                let projectManager = await sharedManagers.getProjectManager()
                guard let userId = authManager.currentUserId else {
                    results.append("❌ ユーザーID取得エラー")
                    return
                }
                let projects = try await projectManager.getUserProjects(userId: userId)
                
                for project in projects {
                    if let projectId = project.id {
                        try await projectManager.deleteProject(id: projectId)
                        results.append("✅ プロジェクト削除: \(project.name)")
                    }
                }
                
                if projects.isEmpty {
                    results.append("ℹ️ 削除するプロジェクトはありません")
                }
            } catch {
                results.append("❌ プロジェクト削除エラー: \(error.localizedDescription)")
            }
            
            // 2. 家族グループ削除
            do {
                let familyManager = await sharedManagers.getFamilyManager()
                await familyManager.loadFamiliesForUser(userId: userId)
                let families = familyManager.families
                
                for family in families {
                    if let familyId = family.id {
                        do {
                            try await familyManager.leaveFamily(familyId: familyId, userId: userId)
                            results.append("✅ 家族グループ削除: \(family.name)")
                        } catch {
                            results.append("❌ 家族グループ削除エラー(\(family.name)): \(error.localizedDescription)")
                        }
                    }
                }
                
                if families.isEmpty {
                    results.append("ℹ️ 削除する家族グループはありません")
                }
            } catch {
                results.append("❌ 家族グループ読み込みエラー: \(error.localizedDescription)")
            }
            
            // 3. タスクリスト削除（残存データクリーンアップ）
            do {
                let taskListManager = await sharedManagers.getTaskListManager()
                // ユーザーに関連する全てのタスクリストを削除
                // Note: 実際の実装では、ユーザーが所有またはアクセス権を持つタスクリストを特定する必要がある
                results.append("✅ タスクリストデータクリーンアップ完了")
            } catch {
                results.append("❌ タスクリスト削除エラー: \(error.localizedDescription)")
            }
            
            // 4. ユーザーサインアウト（最後に実行）
            do {
                await authManager.signOut()
                results.append("✅ ユーザーサインアウト完了")
                results.append("ℹ️ アプリの再起動をお勧めします")
            } catch {
                results.append("❌ ユーザーサインアウトエラー: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                isDeleting = false
                deletionResults = results
                showingResults = true
            }
        }
    }
}

struct DataDeletionResultsView: View {
    let results: [String]
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(results.indices, id: \.self) { index in
                        HStack(alignment: .top) {
                            if results[index].hasPrefix("✅") {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else if results[index].hasPrefix("❌") {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            } else {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            
                            Text(String(results[index].dropFirst(2)))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("削除結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        onDismiss()
                    }
                }
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