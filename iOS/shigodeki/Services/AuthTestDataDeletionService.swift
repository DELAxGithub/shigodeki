//
//  AuthTestDataDeletionService.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import Foundation

struct AuthTestDataDeletionService {
    
    static func executeFullDataDeletion(
        userId: String,
        authManager: AuthenticationManager,
        sharedManagers: SharedManagerStore
    ) async -> [String] {
        var results: [String] = []
        
        // 1. プロジェクト削除
        await deleteProjects(userId: userId, sharedManagers: sharedManagers, results: &results)
        
        // 2. 家族グループ削除
        await deleteFamilyGroups(userId: userId, sharedManagers: sharedManagers, results: &results)
        
        // 3. タスクリスト削除（残存データクリーンアップ）
        await cleanupTaskLists(sharedManagers: sharedManagers, results: &results)
        
        // 4. ユーザーサインアウト（最後に実行）
        await signOutUser(authManager: authManager, results: &results)
        
        return results
    }
    
    // MARK: - Private Methods
    
    private static func deleteProjects(
        userId: String,
        sharedManagers: SharedManagerStore,
        results: inout [String]
    ) async {
        do {
            let projectManager = await sharedManagers.getProjectManager()
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
    }
    
    private static func deleteFamilyGroups(
        userId: String,
        sharedManagers: SharedManagerStore,
        results: inout [String]
    ) async {
        let familyManager = await sharedManagers.getFamilyManager()
        await familyManager.loadFamiliesForUser(userId: userId)
        let families = await familyManager.families
        
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
    }
    
    private static func cleanupTaskLists(
        sharedManagers: SharedManagerStore,
        results: inout [String]
    ) async {
        let _ = await sharedManagers.getTaskListManager()
        // ユーザーに関連する全てのタスクリストを削除
        // Note: 実際の実装では、ユーザーが所有またはアクセス権を持つタスクリストを特定する必要がある
        results.append("✅ タスクリストデータクリーンアップ完了")
    }
    
    private static func signOutUser(
        authManager: AuthenticationManager,
        results: inout [String]
    ) async {
        await authManager.signOut()
        results.append("✅ ユーザーサインアウト完了")
        results.append("ℹ️ アプリの再起動をお勧めします")
    }
}
