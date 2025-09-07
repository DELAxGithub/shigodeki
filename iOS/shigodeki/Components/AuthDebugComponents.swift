//
//  AuthDebugComponents.swift
//  shigodeki
//
//  Created from AuthTestComponents split for CLAUDE.md compliance
//  Authentication debug and data management components
//

import SwiftUI
import FirebaseAuth
import FirebaseCore

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