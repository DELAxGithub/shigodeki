import Foundation
import FirebaseFirestore
import FirebaseAuth

/// FamilyInvitationService - 統一招待システムへの委譲クラス
/// 旧Triple-save戦略を廃止し、UnifiedInvitationServiceに完全委譲
class FamilyInvitationService {
    private let unifiedService = UnifiedInvitationService()
    
    /// 家族招待コード生成（統一システム委譲）
    /// - Parameters:
    ///   - familyId: 家族ID
    ///   - familyName: 家族名（表示用、統一システムでは不要）
    func generateInvitationCode(familyId: String, familyName: String) async throws {
        // Triple-save戦略を廃止し、統一システムに完全委譲
        let code = try await unifiedService.createInvitation(
            targetId: familyId, 
            type: .family
        )
        
        print("✅ [FamilyInvitationService] Delegation completed: \(code) -> family \(familyId)")
    }
    
    /// 家族参加処理（統一システム委譲）
    /// - Parameters:
    ///   - code: 招待コード（正規化前）
    ///   - familyId: 家族ID（統一システムでは不要、互換性のため維持）
    ///   - familyName: 家族名（統一システムでは不要、互換性のため維持）
    ///   - userId: ユーザーID（統一システムでは不要、互換性のため維持）
    func joinFamilyWithCodeOnServer(code: String, familyId: String, familyName: String, userId: String) async throws {
        // 複雑な検証ロジック・トランザクション・冪等性処理を全て統一システムに委譲
        do {
            try await unifiedService.joinWithInvitationCode(code)
            print("✅ [FamilyInvitationService] Join completed: \(code)")
        } catch let error as InvitationError {
            // 統一エラーを旧エラー形式にマッピング（互換性維持）
            throw mapToLegacyError(error)
        }
    }
    
    /// 招待コード検証（統一システム委譲）
    func validateInvitationCode(_ code: String) async throws -> (familyId: String, familyName: String) {
        do {
            let result = try await unifiedService.validateInvitationCode(code)
            print("✅ [FamilyInvitationService] Validation completed: \(code) -> \(result.targetName)")
            return (familyId: result.targetId, familyName: result.targetName)
        } catch let error as InvitationError {
            throw mapToLegacyError(error)
        }
    }
    
    // MARK: - 互換性マッピング（段階的廃止予定）
    
    /// 統一エラーを旧エラー形式にマッピング（API互換性維持）
    private func mapToLegacyError(_ error: InvitationError) -> FamilyError {
        switch error {
        case .userNotAuthenticated:
            return .userNotAuthenticated
        case .invalidCode(_):
            return .invalidInvitationCode
        case .invalidOrExpired:
            return .expiredInvitationCode
        case .corruptedData:
            return .invalidInvitationCode
        case .joinFailed(_):
            return .invalidInvitationCode
        }
    }
}