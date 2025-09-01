//
//  FamilyManager.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FamilyManager: ObservableObject {
    @Published var families: [Family] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var familyListeners: [ListenerRegistration] = []
    private let listenerQueue = DispatchQueue(label: "com.shigodeki.familyManager.listeners", qos: .userInteractive)
    
    // MARK: - Optimistic Updates Support
    private var pendingOperations: [String: PendingOperation] = [:]
    
    private struct PendingOperation {
        let type: OperationType
        let originalData: Any?
        let timestamp: Date
        let retryCount: Int
        
        enum OperationType {
            case createFamily(tempId: String)
            case deleteFamily(familyId: String)
            case removeMember(familyId: String, userId: String)
            case joinFamily(familyId: String, userId: String)
        }
    }
    
    // ペンディング操作のタイムアウト時間（秒）
    private let pendingOperationTimeout: TimeInterval = 30.0
    private let maxRetryCount: Int = 3
    
    // ペンディング操作の管理
    private func cleanupExpiredOperations() {
        let now = Date()
        let expiredKeys = pendingOperations.keys.filter { key in
            guard let operation = pendingOperations[key] else { return true }
            return now.timeIntervalSince(operation.timestamp) > pendingOperationTimeout
        }
        
        for key in expiredKeys {
            if let operation = pendingOperations[key] {
                print("⚠️ Expired pending operation: \(operation.type)")
            }
            pendingOperations.removeValue(forKey: key)
        }
    }
    
    private func createPendingOperation(type: PendingOperation.OperationType, originalData: Any? = nil) -> PendingOperation {
        return PendingOperation(
            type: type,
            originalData: originalData,
            timestamp: Date(),
            retryCount: 0
        )
    }
    
    // MARK: - Family Creation
    
    /// 楽観的更新版の家族作成メソッド
    func createFamilyOptimistic(name: String, creatorUserId: String) async throws -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw FamilyError.invalidName
        }
        
        // 1. 楽観的更新: UI に即座に反映
        let tempId = "temp_\(UUID().uuidString)"
        var optimisticFamily = Family(name: trimmedName, members: [creatorUserId])
        optimisticFamily.id = tempId
        optimisticFamily.createdAt = Date()
        
        // UI即座更新
        families.append(optimisticFamily)
        
        // ペンディング操作を記録
        cleanupExpiredOperations() // 期限切れ操作をクリーンアップ
        pendingOperations[tempId] = createPendingOperation(
            type: .createFamily(tempId: tempId),
            originalData: nil // 新規作成なので元データなし
        )
        
        do {
            // 2. サーバー処理実行
            let realFamilyId = try await createFamilyOnServer(name: trimmedName, creatorUserId: creatorUserId)
            
            // 3. 成功時: 一時IDを実際のIDに置き換え
            if let index = families.firstIndex(where: { $0.id == tempId }) {
                families[index].id = realFamilyId
                pendingOperations.removeValue(forKey: tempId)
            }
            
            return realFamilyId
            
        } catch {
            // 4. 失敗時: ロールバック
            rollbackCreateFamily(tempId: tempId)
            throw error
        }
    }
    
    private func createFamilyOnServer(name: String, creatorUserId: String) async throws -> String {
        let familyData: [String: Any] = [
            "name": name,
            "members": [creatorUserId],
            "createdAt": FieldValue.serverTimestamp(),
            "lastUpdatedAt": FieldValue.serverTimestamp(),
            "devEnvironmentTest": "Created in DEV at \(Date().formatted())"
        ]
        
        do {
            let familyRef = try await db.collection("families").addDocument(data: familyData)
            let familyId = familyRef.documentID
            
            // Update user's familyIds array
            try await updateUserFamilyIds(userId: creatorUserId, familyId: familyId, action: .add)
            
            // Create invitation code for this family
            try await generateInvitationCode(familyId: familyId, familyName: name)
            
            print("Family created successfully with ID: \(familyId)")
            return familyId
            
        } catch {
            print("Error creating family: \(error)")
            errorMessage = "家族グループの作成に失敗しました"
            throw FamilyError.creationFailed(error.localizedDescription)
        }
    }
    
    private func rollbackCreateFamily(tempId: String) {
        // ペンディング操作をクリア
        pendingOperations.removeValue(forKey: tempId)
        
        // UIから一時的に追加した家族を削除
        families.removeAll { $0.id == tempId }
        
        print("Rolled back optimistic family creation: \(tempId)")
    }
    
    /// 後方互換性のため既存のメソッドを楽観的更新版にリダイレクト
    func createFamily(name: String, creatorUserId: String) async throws -> String {
        return try await createFamilyOptimistic(name: name, creatorUserId: creatorUserId)
    }
    
    // MARK: - Family Data Loading
    
    func loadFamiliesForUser(userId: String) async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            // First, get user document to find their family IDs
            let userDoc = try await db.collection("users").document(userId).getDocument()
            
            guard let userData = userDoc.data(),
                  let familyIds = userData["familyIds"] as? [String] else {
                families = []
                return
            }
            
            if familyIds.isEmpty {
                families = []
                return
            }
            
            // Load all families the user belongs to
            var loadedFamilies: [Family] = []
            
            for familyId in familyIds {
                if let family = try await loadFamily(familyId: familyId) {
                    loadedFamilies.append(family)
                }
            }
            
            families = loadedFamilies
            
        } catch {
            print("Error loading families: \(error)")
            errorMessage = "家族グループの読み込みに失敗しました"
        }
    }
    
    private func loadFamily(familyId: String) async throws -> Family? {
        let familyDoc = try await db.collection("families").document(familyId).getDocument()
        
        guard familyDoc.exists, let data = familyDoc.data() else {
            return nil
        }
        
        var family = Family(
            name: data["name"] as? String ?? "",
            members: data["members"] as? [String] ?? []
        )
        family.id = familyId
        family.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        family.lastUpdatedAt = (data["lastUpdatedAt"] as? Timestamp)?.dateValue()
        family.devEnvironmentTest = data["devEnvironmentTest"] as? String
        
        return family
    }
    
    // MARK: - Real-time Listeners
    
    func startListeningToFamilies(userId: String) {
        stopListeningToFamilies()
        
        Task { @MainActor in
            do {
                // Get user's family IDs
                let userDoc = try await db.collection("users").document(userId).getDocument()
                guard let userData = userDoc.data(),
                      let familyIds = userData["familyIds"] as? [String] else {
                    return
                }
                
                // Set up listeners for each family
                for familyId in familyIds {
                    let listener = db.collection("families").document(familyId)
                        .addSnapshotListener { [weak self] documentSnapshot, error in
                            Task { @MainActor in
                                guard let self = self else { return }
                                
                                if let error = error {
                                    print("Family listener error: \(error)")
                                    self.errorMessage = "家族データの同期中にエラーが発生しました"
                                    return
                                }
                                
                                guard let document = documentSnapshot,
                                      let data = document.data() else {
                                    return
                                }
                                
                                var family = Family(
                                    name: data["name"] as? String ?? "",
                                    members: data["members"] as? [String] ?? []
                                )
                                family.id = document.documentID
                                family.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                                family.lastUpdatedAt = (data["lastUpdatedAt"] as? Timestamp)?.dateValue()
                                family.devEnvironmentTest = data["devEnvironmentTest"] as? String
                                
                                // Update families array thread-safely
                                self.updateFamilyInArray(family)
                            }
                        }
                    
                    familyListeners.append(listener)
                }
                
            } catch {
                print("Error setting up family listeners: \(error)")
                errorMessage = "家族データの監視設定に失敗しました"
            }
        }
    }
    
    func stopListeningToFamilies() {
        familyListeners.forEach { $0.remove() }
        familyListeners.removeAll()
    }
    
    // MARK: - Invitation System
    
    func generateInvitationCode(familyId: String, familyName: String) async throws {
        let invitationCode = generateRandomCode()
        
        let invitationData: [String: Any] = [
            "familyId": familyId,
            "familyName": familyName,
            "code": invitationCode,
            "isActive": true,
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": Timestamp(date: Date().addingTimeInterval(7 * 24 * 60 * 60)) // 7 days
        ]
        
        try await db.collection("invitations").document(invitationCode).setData(invitationData)
        print("Invitation code generated: \(invitationCode)")
    }
    
    /// 楽観的更新版の家族参加メソッド  
    func joinFamilyWithCodeOptimistic(_ code: String, userId: String) async throws -> String {
        // まずは招待コードの検証のみ実行（楽観的更新前の必要な検証）
        let codeDoc = try await db.collection("invitations").document(code).getDocument()
        
        guard codeDoc.exists, let data = codeDoc.data(),
              let isActive = data["isActive"] as? Bool, isActive,
              let familyId = data["familyId"] as? String,
              let familyName = data["familyName"] as? String else {
            throw FamilyError.invalidInvitationCode
        }
        
        // Check if invitation hasn't expired
        if let expiresAt = data["expiresAt"] as? Timestamp,
           expiresAt.dateValue() < Date() {
            throw FamilyError.expiredInvitationCode
        }
        
        // 1. 楽観的更新: 新しい家族をUIに追加
        let optimisticFamily = Family(name: familyName, members: [userId])  
        let tempId = "joining_\(familyId)"
        var newFamily = optimisticFamily
        newFamily.id = familyId
        newFamily.createdAt = Date()
        
        families.append(newFamily)
        
        // ペンディング操作を記録
        cleanupExpiredOperations()
        pendingOperations[tempId] = createPendingOperation(
            type: .joinFamily(familyId: familyId, userId: userId),
            originalData: nil
        )
        
        do {
            // 2. サーバー処理実行
            try await joinFamilyWithCodeOnServer(code: code, familyId: familyId, familyName: familyName, userId: userId)
            
            // 3. 成功時: ペンディング操作をクリア
            pendingOperations.removeValue(forKey: tempId)
            return familyName
            
        } catch {
            // 4. 失敗時: ロールバック
            rollbackJoinFamily(familyId: familyId)
            throw error
        }
    }
    
    private func joinFamilyWithCodeOnServer(code: String, familyId: String, familyName: String, userId: String) async throws {
        // Add user to family members
        try await db.collection("families").document(familyId).updateData([
            "members": FieldValue.arrayUnion([userId])
        ])
        
        // Update user's familyIds
        try await updateUserFamilyIds(userId: userId, familyId: familyId, action: .add)
        
        // 🔗 同期: 家族所有の全プロジェクトにプロジェクトメンバーとして追加
        do {
            let projectsSnap = try await db.collection("projects").whereField("ownerId", isEqualTo: familyId).getDocuments()
            let encoder = Firestore.Encoder()
            var displayName: String? = nil
            do {
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let data = userDoc.data() { displayName = data["name"] as? String }
            } catch {
                // ignore permission issues
            }
            for doc in projectsSnap.documents {
                // Only family-owned projects
                if let ownerType = doc.data()["ownerType"] as? String, ownerType == "family" {
                    // Add to memberIds array
                    try await doc.reference.updateData(["memberIds": FieldValue.arrayUnion([userId])])
                    // Create/merge ProjectMember subdocument
                    let member = ProjectMember(userId: userId, projectId: doc.documentID, role: .editor, invitedBy: userId, displayName: displayName)
                    try await doc.reference.collection("members").document(userId).setData(try encoder.encode(member), merge: true)
                }
            }
        } catch {
            // 同期に失敗してもファミリー参加自体は成功扱いとする
            print("Family join sync warning: \(error)")
        }
    }
    
    private func rollbackJoinFamily(familyId: String) {
        let tempId = "joining_\(familyId)"
        pendingOperations.removeValue(forKey: tempId)
        
        // UIから追加した家族を削除
        families.removeAll { $0.id == familyId }
        
        print("Rolled back optimistic family join: \(familyId)")
    }
    
    func joinFamilyWithCode(_ code: String, userId: String) async throws -> String {
        return try await joinFamilyWithCodeOptimistic(code, userId: userId)
    }
    
    
    private func generateRandomCode() -> String {
        let characters = "0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
    
    // MARK: - Member Management
    
    /// 楽観的更新版のメンバー削除メソッド
    func removeMemberFromFamilyOptimistic(familyId: String, userId: String) async throws {
        // 1. 楽観的更新: UI から即座にメンバーを削除
        guard let familyIndex = families.firstIndex(where: { $0.id == familyId }) else {
            throw FamilyError.notFound
        }
        
        let originalMembers = families[familyIndex].members
        let operationId = "\(familyId)_\(userId)"
        
        // UI即座更新
        families[familyIndex].members.removeAll { $0 == userId }
        
        // ペンディング操作を記録
        cleanupExpiredOperations()
        pendingOperations[operationId] = createPendingOperation(
            type: .removeMember(familyId: familyId, userId: userId),
            originalData: originalMembers
        )
        
        do {
            // 2. サーバー処理実行
            try await removeMemberFromFamilyOnServer(familyId: familyId, userId: userId)
            
            // 3. 成功時: ペンディング操作をクリア
            pendingOperations.removeValue(forKey: operationId)
            
        } catch {
            // 4. 失敗時: ロールバック
            rollbackRemoveMember(familyId: familyId, userId: userId, originalMembers: originalMembers)
            throw error
        }
    }
    
    private func removeMemberFromFamilyOnServer(familyId: String, userId: String) async throws {
        // Remove user from family members
        try await db.collection("families").document(familyId).updateData([
            "members": FieldValue.arrayRemove([userId])
        ])
        
        // Update user's familyIds
        try await updateUserFamilyIds(userId: userId, familyId: familyId, action: .remove)
    }
    
    private func deleteFamilyFromServer(familyId: String) async throws {
        // 最後のメンバーが退出時は家族自体を削除
        try await db.collection("families").document(familyId).delete()
        print("🗑️ Family deleted from server: \(familyId)")
    }
    
    private func rollbackRemoveMember(familyId: String, userId: String, originalMembers: [String]) {
        let operationId = "\(familyId)_\(userId)"
        pendingOperations.removeValue(forKey: operationId)
        
        // UIを元の状態に戻す
        if let familyIndex = families.firstIndex(where: { $0.id == familyId }) {
            families[familyIndex].members = originalMembers
        }
        
        print("Rolled back optimistic member removal: \(userId) from family \(familyId)")
    }
    
    func removeMemberFromFamily(familyId: String, userId: String) async throws {
        return try await removeMemberFromFamilyOptimistic(familyId: familyId, userId: userId)
    }
    
    /// 楽観的更新版の家族退出メソッド
    func leaveFamilyOptimistic(familyId: String, userId: String) async throws {
        // デバッグ情報追加
        print("🔍 Leave family attempt - familyId: \(familyId), userId: \(userId)")
        print("🔍 Current families count: \(families.count)")
        print("🔍 Current family IDs: \(families.compactMap { $0.id })")
        
        // 退出時は家族をfamilies配列からも削除する
        guard let familyIndex = families.firstIndex(where: { $0.id == familyId }) else {
            print("❌ Family not found in array - familyId: \(familyId)")
            throw FamilyError.notFound
        }
        
        let originalFamily = families[familyIndex]
        let operationId = "leave_\(familyId)_\(userId)"
        
        // UI即座更新: 家族をリストから削除
        families.remove(at: familyIndex)
        
        // ペンディング操作を記録
        cleanupExpiredOperations()
        pendingOperations[operationId] = createPendingOperation(
            type: .removeMember(familyId: familyId, userId: userId),
            originalData: originalFamily
        )
        
        do {
            // 最後のメンバー（創設者）の場合は家族自体を削除
            if originalFamily.members.count == 1 && originalFamily.members.first == userId {
                print("🗑️ Deleting family (last member leaving): \(familyId)")
                // ユーザーのfamilyIdsからも削除
                try await updateUserFamilyIds(userId: userId, familyId: familyId, action: .remove)
                // 家族ドキュメントを削除
                try await deleteFamilyFromServer(familyId: familyId)
            } else {
                // 通常の退出処理
                print("👋 Removing member from family: \(userId)")
                try await removeMemberFromFamilyOnServer(familyId: familyId, userId: userId)
            }
            
            // 成功時: ペンディング操作をクリア
            pendingOperations.removeValue(forKey: operationId)
            print("✅ Family exit completed successfully")
            
        } catch {
            print("❌ Family exit failed: \(error)")
            // 失敗時: ロールバック
            rollbackLeaveFamily(familyId: familyId, userId: userId, originalFamily: originalFamily)
            throw error
        }
    }
    
    private func rollbackLeaveFamily(familyId: String, userId: String, originalFamily: Family) {
        let operationId = "leave_\(familyId)_\(userId)"
        pendingOperations.removeValue(forKey: operationId)
        
        // UIを元の状態に戻す: 家族をリストに再追加
        families.append(originalFamily)
        
        print("Rolled back optimistic family leave: \(userId) from family \(familyId)")
    }
    
    func leaveFamily(familyId: String, userId: String) async throws {
        try await leaveFamilyOptimistic(familyId: familyId, userId: userId)
    }
    
    // MARK: - Helper Methods
    
    private func updateFamilyInArray(_ family: Family) {
        if let index = families.firstIndex(where: { $0.id == family.id }) {
            families[index] = family
        } else {
            families.append(family)
        }
    }
    
    private enum FamilyIdAction {
        case add, remove
    }
    
    private func updateUserFamilyIds(userId: String, familyId: String, action: FamilyIdAction) async throws {
        let userRef = db.collection("users").document(userId)
        
        switch action {
        case .add:
            try await userRef.updateData([
                "familyIds": FieldValue.arrayUnion([familyId])
            ])
        case .remove:
            try await userRef.updateData([
                "familyIds": FieldValue.arrayRemove([familyId])
            ])
        }
    }
    
    // MARK: - Cleanup
    
    func cleanupInactiveListeners() {
        // Remove listeners for families that no longer exist in the current list
        _ = Set(families.compactMap { $0.id })
        familyListeners.removeAll { listener in
            // This would require more sophisticated tracking to identify which listener belongs to which family
            // For now, we'll keep all listeners active
            false
        }
    }
    
    deinit {
        familyListeners.forEach { $0.remove() }
        familyListeners.removeAll()
    }
}

// MARK: - Error Types

enum FamilyError: LocalizedError {
    case invalidName
    case creationFailed(String)
    case invalidInvitationCode
    case expiredInvitationCode
    case notFound
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "家族グループ名が無効です"
        case .creationFailed(let message):
            return "家族グループの作成に失敗しました: \(message)"
        case .invalidInvitationCode:
            return "無効な招待コードです"
        case .expiredInvitationCode:
            return "招待コードの有効期限が切れています"
        case .notFound:
            return "家族グループが見つかりません"
        case .permissionDenied:
            return "この操作の権限がありません"
        }
    }
}
