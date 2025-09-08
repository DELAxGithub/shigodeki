//
//  UnifiedInvitationService.swift  
//  shigodeki
//
//  CTO緊急リファクタリング: Over-engineeringの解消
//  1つのコレクション、1つの真実の源、シンプルな実装
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// 統一された招待システム - KISS原則の体現
/// 複雑性を排除し、保守性とユーザビリティを両立
class UnifiedInvitationService {
    private let db = Firestore.firestore()
    
    // 統一定数（InviteCodeSpecに統合）
    private var safeCharacters: String { InviteCodeSpec.safeCharacters }
    private var codeLength: Int { InviteCodeSpec.codeLength }
    
    /// 招待タイプ定義
    enum InvitationType: String, CaseIterable {
        case family = "family"
        case project = "project"
    }
    
    /// 招待情報構造体
    struct Invitation {
        let code: String
        let targetId: String
        let targetType: InvitationType
        let createdBy: String
        let createdAt: Date
        let expiresAt: Date
        let maxUses: Int
        let usedCount: Int
        let isActive: Bool
        
        var isValid: Bool {
            return isActive && 
                   expiresAt > Date() && 
                   usedCount < maxUses
        }
    }
    
    // MARK: - Public API
    
    /// 招待コード生成（シンプル、安全、確実）
    /// - Parameters:
    ///   - targetId: 招待対象のIDファミリーまたはプロジェクト）
    ///   - type: 招待タイプ
    /// - Returns: 6桁の安全文字コード（INV-プレフィックスなし）
    func createInvitation(targetId: String, type: InvitationType) async throws -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw InvitationError.userNotAuthenticated
        }
        
        let code = generateSafeCode()
        let now = Date()
        
        let invitationData: [String: Any] = [
            "code": code,
            "targetId": targetId,
            "targetType": type.rawValue,
            "createdBy": currentUserId,
            "createdAt": Timestamp(date: now),
            "expiresAt": Timestamp(date: now.addingTimeInterval(30 * 24 * 3600)), // 30日
            "maxUses": 50,
            "usedCount": 0,
            "isActive": true
        ]
        
        // 単一保存：1つのコレクション、1つの真実の源
        try await db.collection("invitations_unified").document(code).setData(invitationData)
        
        print("✅ [UnifiedInvitationService] Created invitation: \(code) -> \(type) \(targetId)")
        return code
    }
    
    /// 招待コード参加（原子的・冪等・厳密検証）
    /// - Parameter inputCode: ユーザー入力コード
    func joinWithInvitationCode(_ inputCode: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw InvitationError.userNotAuthenticated
        }
        
        // 統一正規化（エラーハンドリング強化）
        let code: String
        do {
            code = try normalizeCode(inputCode)
        } catch {
            throw InvitationError.invalidCode("正規化エラー: \(error.localizedDescription)")
        }
        
        // 1. 招待コード検証 + 使用回数チェック
        let inviteRef = db.collection("invitations_unified").document(code)
        let inviteDoc = try await inviteRef.getDocument()
        
        guard inviteDoc.exists, let data = inviteDoc.data() else {
            throw InvitationError.invalidOrExpired
        }
        
        let invitation = try parseInvitationData(code: code, data: data)
        
        // デバッグ: 招待コードの詳細情報をログ出力（join処理）
        print("🔍 [UnifiedInvitationService] Join validation for \(code):")
        print("   - isActive: \(invitation.isActive)")
        print("   - expiresAt: \(invitation.expiresAt) (now: \(Date()))")
        print("   - usedCount/maxUses: \(invitation.usedCount)/\(invitation.maxUses)")
        print("   - targetId: \(invitation.targetId)")
        print("   - targetType: \(invitation.targetType)")
        
        // 有効性 + 使用回数の厳密チェック
        guard invitation.isActive && 
              invitation.expiresAt > Date() &&
              invitation.usedCount < invitation.maxUses else {
            print("❌ [UnifiedInvitationService] Join validation failed - isActive: \(invitation.isActive), expired: \(invitation.expiresAt <= Date()), used up: \(invitation.usedCount >= invitation.maxUses)")
            throw InvitationError.invalidOrExpired
        }
        
        // 2. 原子的更新処理（Transaction使用 - 明示配列更新）
        try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            // 冪等性チェック（トランザクション内で実行）
            print("🔍 [UnifiedInvitationService] Checking existing membership in transaction for user \(currentUserId)")
            
            do {
                // 招待ドキュメントをトランザクション内で再取得（競合安全のため）
                let inviteSnap = try transaction.getDocument(inviteRef)
                guard let inviteData = inviteSnap.data() else {
                    throw InvitationError.invalidOrExpired
                }
                let currentUsedCount = (inviteData["usedCount"] as? Int) ?? invitation.usedCount

                let alreadyMember = try self.checkExistingMembershipInTransaction(
                    userId: currentUserId, 
                    invitation: invitation,
                    transaction: transaction
                )
                print("   - Already member: \(alreadyMember)")
                
                if alreadyMember {
                    // 重複参加は成功扱い（冪等性）- 使用回数は増加しない
                    print("ℹ️ [UnifiedInvitationService] User already member, skipping: \(code)")
                    return nil
                }
                
                // メンバーシップ追加（タイプ別処理 - 明示配列更新）
                try self.addMembershipWithTransaction(
                    userId: currentUserId,
                    invitation: invitation,
                    transaction: transaction
                )
                
                // 使用回数増加（厳密検証済み）
                transaction.updateData([
                    "usedCount": currentUsedCount + 1
                ], forDocument: inviteRef)
                
                return nil
            } catch {
                // エラーを errorPointer に設定
                errorPointer?.pointee = error as NSError
                return nil
            }
        })
        
        print("✅ [UnifiedInvitationService] Join completed: \(code)")
    }
    
    /// 招待コード検証（UI用プレビュー）
    /// - Parameter inputCode: ユーザー入力コード
    /// - Returns: 招待情報（ID、名前、タイプ）
    func validateInvitationCode(_ inputCode: String) async throws -> (targetId: String, targetName: String, targetType: InvitationType) {
        let code = try normalizeCode(inputCode)
        let invitation = try await fetchInvitation(code)
        
        // デバッグ: 招待コードの詳細情報をログ出力
        print("🔍 [UnifiedInvitationService] Invitation details for \(code):")
        print("   - isActive: \(invitation.isActive)")
        print("   - expiresAt: \(invitation.expiresAt) (now: \(Date()))")
        print("   - usedCount/maxUses: \(invitation.usedCount)/\(invitation.maxUses)")
        print("   - targetId: \(invitation.targetId)")
        print("   - targetType: \(invitation.targetType)")
        print("   - isValid: \(invitation.isValid)")
        
        guard invitation.isValid else {
            print("❌ [UnifiedInvitationService] Invitation invalid - isActive: \(invitation.isActive), expired: \(invitation.expiresAt <= Date()), used up: \(invitation.usedCount >= invitation.maxUses)")
            throw InvitationError.invalidOrExpired
        }
        
        // 対象の名前を取得
        let targetName = try await fetchTargetName(invitation.targetId, type: invitation.targetType)
        
        return (targetId: invitation.targetId, targetName: targetName, targetType: invitation.targetType)
    }
    
    // MARK: - Private Implementation
    
    /// 安全コード生成（統一仕様準拠）
    private func generateSafeCode() -> String {
        return String((0..<codeLength).map { _ in 
            safeCharacters.randomElement()! 
        })
    }
    
    /// 統一正規化（新正規化システム使用）
    private func normalizeCode(_ input: String) throws -> String {
        return try InvitationCodeNormalizer.normalize(input)
    }
    
    /// 招待情報取得
    private func fetchInvitation(_ code: String) async throws -> Invitation {
        let doc = try await db.collection("invitations_unified").document(code).getDocument()
        
        guard doc.exists, let data = doc.data() else {
            throw InvitationError.invalidOrExpired
        }
        
        guard let targetId = data["targetId"] as? String,
              let targetTypeString = data["targetType"] as? String,
              let targetType = InvitationType(rawValue: targetTypeString),
              let createdBy = data["createdBy"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let expiresAtTimestamp = data["expiresAt"] as? Timestamp,
              let maxUses = data["maxUses"] as? Int,
              let usedCount = data["usedCount"] as? Int,
              let isActive = data["isActive"] as? Bool else {
            throw InvitationError.corruptedData
        }
        
        return Invitation(
            code: code,
            targetId: targetId,
            targetType: targetType,
            createdBy: createdBy,
            createdAt: createdAtTimestamp.dateValue(),
            expiresAt: expiresAtTimestamp.dateValue(),
            maxUses: maxUses,
            usedCount: usedCount,
            isActive: isActive
        )
    }
    
    /// 対象名取得
    private func fetchTargetName(_ targetId: String, type: InvitationType) async throws -> String {
        switch type {
        case .family:
            let doc = try await db.collection("families").document(targetId).getDocument()
            return doc.data()?["name"] as? String ?? "Unknown Family"
        case .project:
            let doc = try await db.collection("projects").document(targetId).getDocument()
            return doc.data()?["name"] as? String ?? "Unknown Project"
        }
    }
    
    /// ファミリー参加処理
    private func joinFamily(_ familyId: String, userId: String) async throws {
        // ファミリーメンバー追加
        try await db.collection("families").document(familyId).updateData([
            "members": FieldValue.arrayUnion([userId])
        ])
        
        // ユーザーのfamilyIds更新
        try await db.collection("users").document(userId).updateData([
            "familyIds": FieldValue.arrayUnion([familyId])
        ])
    }
    
    /// プロジェクト参加処理
    private func joinProject(_ projectId: String, userId: String) async throws {
        // プロジェクトメンバー追加
        try await db.collection("projects").document(projectId).updateData([
            "memberIds": FieldValue.arrayUnion([userId])
        ])
        
        // メンバー詳細作成
        try await db.collection("projects").document(projectId)
            .collection("members").document(userId).setData([
                "userId": userId,
                "projectId": projectId,
                "role": "editor",
                "joinedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }
    
    /// 招待データ解析（トランザクション内用）
    private func parseInvitationData(code: String, data: [String: Any]) throws -> Invitation {
        guard let targetId = data["targetId"] as? String,
              let targetTypeString = data["targetType"] as? String,
              let targetType = InvitationType(rawValue: targetTypeString),
              let createdBy = data["createdBy"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let expiresAtTimestamp = data["expiresAt"] as? Timestamp,
              let maxUses = data["maxUses"] as? Int,
              let usedCount = data["usedCount"] as? Int,
              let isActive = data["isActive"] as? Bool else {
            throw InvitationError.corruptedData
        }
        
        return Invitation(
            code: code,
            targetId: targetId,
            targetType: targetType,
            createdBy: createdBy,
            createdAt: createdAtTimestamp.dateValue(),
            expiresAt: expiresAtTimestamp.dateValue(),
            maxUses: maxUses,
            usedCount: usedCount,
            isActive: isActive
        )
    }
    
    /// 既存メンバーシップチェック（冪等性保証）
    private func checkExistingMembership(
        userId: String, 
        invitation: Invitation
    ) async throws -> Bool {
        switch invitation.targetType {
        case .family:
            let familyRef = db.collection("families").document(invitation.targetId)
            let familyDoc = try await familyRef.getDocument()
            if let familyData = familyDoc.data(),
               let members = familyData["members"] as? [String] {
                return members.contains(userId)
            }
            return false
            
        case .project:
            let projectRef = db.collection("projects").document(invitation.targetId)
            let projectDoc = try await projectRef.getDocument()
            if let projectData = projectDoc.data(),
               let memberIds = projectData["memberIds"] as? [String] {
                return memberIds.contains(userId)
            }
            return false
        }
    }
    
    /// メンバーシップ追加（トランザクション内実行）
    private func addMembership(
        userId: String,
        invitation: Invitation,
        transaction: Transaction
    ) throws {
        switch invitation.targetType {
        case .family:
            try addFamilyMembership(userId: userId, familyId: invitation.targetId, transaction: transaction)
            
        case .project:
            // プロジェクト参加は家族参加も必要
            try addProjectMembership(userId: userId, invitation: invitation, transaction: transaction)
        }
    }
    
    /// 家族メンバーシップ追加（トランザクション内）
    private func addFamilyMembership(
        userId: String, 
        familyId: String, 
        transaction: Transaction
    ) throws {
        let familyRef = db.collection("families").document(familyId)
        transaction.updateData([
            "members": FieldValue.arrayUnion([userId])
        ], forDocument: familyRef)
        
        let userRef = db.collection("users").document(userId)
        transaction.updateData([
            "familyIds": FieldValue.arrayUnion([familyId])
        ], forDocument: userRef)
    }
    
    /// プロジェクトメンバーシップ追加（家族参加込み）
    private func addProjectMembership(
        userId: String, 
        invitation: Invitation, 
        transaction: Transaction
    ) throws {
        let projectRef = db.collection("projects").document(invitation.targetId)
        let projectDoc = try transaction.getDocument(projectRef)
        
        guard let projectData = projectDoc.data(),
              let familyId = projectData["familyId"] as? String else {
            throw InvitationError.joinFailed("プロジェクトのfamilyId取得エラー")
        }
        
        // 1. 先に家族メンバーシップを確保
        try addFamilyMembership(userId: userId, familyId: familyId, transaction: transaction)
        
        // 2. プロジェクトメンバーシップ追加
        transaction.updateData([
            "memberIds": FieldValue.arrayUnion([userId])
        ], forDocument: projectRef)
        
        // 3. プロジェクトメンバー詳細作成
        let memberRef = projectRef.collection("members").document(userId)
        transaction.setData([
            "userId": userId,
            "projectId": invitation.targetId,
            "role": "editor",
            "joinedAt": FieldValue.serverTimestamp(),
            "invitedBy": invitation.createdBy
        ], forDocument: memberRef, merge: true)
    }
    
    // MARK: - WriteBatch Methods (Firebase互換性対応)
    
    /// メンバーシップ追加（WriteBatch使用）
    private func addMembershipWithBatch(
        userId: String,
        invitation: Invitation,
        batch: WriteBatch
    ) async throws {
        switch invitation.targetType {
        case .family:
            try addFamilyMembershipWithBatch(userId: userId, familyId: invitation.targetId, batch: batch)
            
        case .project:
            // プロジェクト参加は家族参加も必要
            try await addProjectMembershipWithBatch(userId: userId, invitation: invitation, batch: batch)
        }
    }
    
    /// 家族メンバーシップ追加（WriteBatch使用）
    private func addFamilyMembershipWithBatch(
        userId: String, 
        familyId: String, 
        batch: WriteBatch
    ) throws {
        let familyRef = db.collection("families").document(familyId)
        batch.updateData([
            "members": FieldValue.arrayUnion([userId])
        ], forDocument: familyRef)
        
        let userRef = db.collection("users").document(userId)
        batch.updateData([
            "familyIds": FieldValue.arrayUnion([familyId])
        ], forDocument: userRef)
    }
    
    /// プロジェクトメンバーシップ追加（WriteBatch使用 + 家族参加込み）
    private func addProjectMembershipWithBatch(
        userId: String, 
        invitation: Invitation, 
        batch: WriteBatch
    ) async throws {
        let projectRef = db.collection("projects").document(invitation.targetId)
        let projectDoc = try await projectRef.getDocument()
        
        guard let projectData = projectDoc.data(),
              let familyId = projectData["familyId"] as? String else {
            throw InvitationError.joinFailed("プロジェクトのfamilyId取得エラー")
        }
        
        // 1. 先に家族メンバーシップを確保
        try addFamilyMembershipWithBatch(userId: userId, familyId: familyId, batch: batch)
        
        // 2. プロジェクトメンバーシップ追加
        batch.updateData([
            "memberIds": FieldValue.arrayUnion([userId])
        ], forDocument: projectRef)
        
        // 3. プロジェクトメンバー詳細作成
        let memberRef = projectRef.collection("members").document(userId)
        batch.setData([
            "userId": userId,
            "projectId": invitation.targetId,
            "role": "editor",
            "joinedAt": FieldValue.serverTimestamp(),
            "invitedBy": invitation.createdBy
        ], forDocument: memberRef, merge: true)
    }
    
    // MARK: - Transaction Methods (明示配列更新)
    
    /// トランザクション内での冪等性チェック
    private func checkExistingMembershipInTransaction(
        userId: String,
        invitation: Invitation,
        transaction: Transaction
    ) throws -> Bool {
        switch invitation.targetType {
        case .family:
            let familyRef = db.collection("families").document(invitation.targetId)
            let familyDoc = try transaction.getDocument(familyRef)
            if let members = familyDoc.data()?["members"] as? [String] {
                return members.contains(userId)
            }
            return false
            
        case .project:
            let projectRef = db.collection("projects").document(invitation.targetId)
            let memberRef = projectRef.collection("members").document(userId)
            let memberDoc = try transaction.getDocument(memberRef)
            return memberDoc.exists
        }
    }
    
    /// メンバーシップ追加（Transaction使用 - 明示配列更新）
    private func addMembershipWithTransaction(
        userId: String,
        invitation: Invitation,
        transaction: Transaction
    ) throws {
        switch invitation.targetType {
        case .family:
            try addFamilyMembershipWithTransaction(userId: userId, familyId: invitation.targetId, transaction: transaction)
            
        case .project:
            // プロジェクト参加は家族参加も必要
            try addProjectMembershipWithTransaction(userId: userId, invitation: invitation, transaction: transaction)
        }
    }
    
    /// 家族メンバーシップ追加（Transaction使用 - 明示配列更新）
    private func addFamilyMembershipWithTransaction(
        userId: String, 
        familyId: String, 
        transaction: Transaction
    ) throws {
        // Firestoreトランザクション制約: すべてのreadを最初に実行し、その後にwriteを行う
        // 1) 先に必要なドキュメントをすべて取得
        let familyRef = db.collection("families").document(familyId)
        let userRef = db.collection("users").document(userId)

        let familyDoc = try transaction.getDocument(familyRef)
        let userDoc = try transaction.getDocument(userRef)

        // 2) 新しい配列値を計算（重複は避ける）
        var nextMembers = (familyDoc.data()?["members"] as? [String]) ?? []
        if !nextMembers.contains(userId) {
            nextMembers.append(userId)
        }

        var nextFamilyIds = (userDoc.data()?["familyIds"] as? [String]) ?? []
        if !nextFamilyIds.contains(familyId) {
            nextFamilyIds.append(familyId)
        }

        // 3) 必要な場合のみwriteを実行
        if let currentMembers = familyDoc.data()?["members"] as? [String] {
            if currentMembers != nextMembers {
                transaction.updateData(["members": nextMembers], forDocument: familyRef)
            }
        } else {
            transaction.updateData(["members": nextMembers], forDocument: familyRef)
        }

        if let currentFamilyIds = userDoc.data()?["familyIds"] as? [String] {
            if currentFamilyIds != nextFamilyIds {
                transaction.updateData(["familyIds": nextFamilyIds], forDocument: userRef)
            }
        } else {
            transaction.updateData(["familyIds": nextFamilyIds], forDocument: userRef)
        }
    }
    
    /// プロジェクトメンバーシップ追加（Transaction使用 - 明示配列更新 + 家族参加込み）
    private func addProjectMembershipWithTransaction(
        userId: String, 
        invitation: Invitation, 
        transaction: Transaction
    ) throws {
        let projectRef = db.collection("projects").document(invitation.targetId)
        let projectDoc = try transaction.getDocument(projectRef)
        
        guard let projectData = projectDoc.data(),
              let familyId = projectData["familyId"] as? String else {
            throw InvitationError.joinFailed("プロジェクトのfamilyId取得エラー")
        }
        
        // 先に家族参加を実行
        try addFamilyMembershipWithTransaction(userId: userId, familyId: familyId, transaction: transaction)
        
        // プロジェクトメンバー追加
        let memberRef = projectRef.collection("members").document(userId)
        transaction.setData([
            "userId": userId,
            "projectId": invitation.targetId,
            "role": "editor",
            "joinedAt": FieldValue.serverTimestamp(),
            "invitedBy": invitation.createdBy
        ], forDocument: memberRef, merge: true)
    }
}

// MARK: - Error Definitions

/// 統一招待エラー（4種類に整理）
enum InvitationError: LocalizedError {
    case userNotAuthenticated
    case invalidCode(String)
    case invalidOrExpired  
    case corruptedData
    case joinFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "認証が必要です"
        case .invalidCode(let reason):
            return "無効な招待コード: \(reason)"
        case .invalidOrExpired:
            return "無効または期限切れの招待コードです"
        case .corruptedData:
            return "招待データが破損しています"
        case .joinFailed(let reason):
            return "参加に失敗しました: \(reason)"
        }
    }
}
