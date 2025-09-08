//
//  ProjectInvitationManager.swift
//  shigodeki
//
//  Created by Codex on 2025-08-30.
//

import Foundation
import FirebaseFirestore

/// ProjectInvitationManager - 統一招待システム委譲クラス
/// 旧複雑ロジックを廃止し、UnifiedInvitationServiceに完全委譲
@MainActor
class ProjectInvitationManager: ObservableObject {
    @Published var isLoading = false
    @Published var error: FirebaseError?
    
    private let unifiedService = UnifiedInvitationService()
    
    /// プロジェクト招待作成（統一システム委譲）
    func createInvitation(for project: Project, role: Role, invitedByUserId: String, invitedByName: String) async throws -> ProjectInvitation {
        isLoading = true
        defer { isLoading = false }
        do {
            let code = try await unifiedService.createInvitation(
                targetId: project.id ?? "",
                type: .project
            )
            
            // 互換性のためProjectInvitation形式で返却
            let invitation = ProjectInvitation(
                inviteCode: code,
                projectId: project.id ?? "",
                projectName: project.name,
                invitedBy: invitedByUserId,
                invitedByName: invitedByName,
                role: role
            )
            
            print("[ProjectInvitationManager] Delegation completed: \(code) -> project \(project.id ?? "unknown")")
            return invitation
        } catch let error as InvitationError {
            let fe = mapToFirebaseError(error)
            self.error = fe
            throw fe
        } catch {
            let fe = FirebaseError.from(error)
            self.error = fe
            throw fe
        }
    }
    
    /// プロジェクト招待受諾（統一システム完全委譲）
    func acceptInvitation(code: String, userId: String, displayName: String?) async throws -> Project {
        isLoading = true
        defer { isLoading = false }
        do {
            // 複雑な検証・参加・トランザクション処理を全て統一システムに委譲
            try await unifiedService.joinWithInvitationCode(code)
            
            // プロジェクト情報を取得して返却（API互換性維持）
            let result = try await unifiedService.validateInvitationCode(code)
            let project: Project = try await Firestore.firestore()
                .collection("projects")
                .document(result.targetId)
                .getDocument()
                .data(as: Project.self, decoder: Firestore.Decoder())
            
            print("✅ [ProjectInvitationManager] Join completed: \(code)")
            return project
        } catch let error as InvitationError {
            let fe = mapToFirebaseError(error)
            self.error = fe
            throw fe
        } catch {
            let fe = FirebaseError.from(error)
            self.error = fe
            throw fe
        }
    }
    
    // MARK: - 互換性マッピング（段階的廃止予定）
    
    /// 統一エラーをFirebaseErrorにマッピング（API互換性維持）
    private func mapToFirebaseError(_ error: InvitationError) -> FirebaseError {
        switch error {
        case .userNotAuthenticated:
            return .operationFailed("認証が必要です")
        case .invalidCode(let reason):
            return .operationFailed("無効な招待コード: \(reason)")
        case .invalidOrExpired:
            return .operationFailed("無効または期限切れの招待コードです")
        case .corruptedData:
            return .operationFailed("招待データが破損しています")
        case .joinFailed(let reason):
            return .operationFailed("参加に失敗しました: \(reason)")
        }
    }
}
