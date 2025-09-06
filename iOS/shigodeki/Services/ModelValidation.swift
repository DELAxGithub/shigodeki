//
//  ModelValidation.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation

protocol Validatable {
    func validate() throws
}

enum ModelValidationError: LocalizedError {
    case missingRequiredField(String)
    case invalidFieldLength(String, Int, Int)
    case invalidFormat(String)
    case invalidRelationship(String)
    case duplicateEntry(String)
    
    var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field):
            return "\(field)は必須項目です"
        case .invalidFieldLength(let field, let min, let max):
            return "\(field)は\(min)文字以上\(max)文字以下で入力してください"
        case .invalidFormat(let field):
            return "\(field)の形式が正しくありません"
        case .invalidRelationship(let description):
            return "関係性エラー: \(description)"
        case .duplicateEntry(let field):
            return "\(field)が重複しています"
        }
    }
}

extension Project: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.missingRequiredField("プロジェクト名")
        }
        
        if name.count > 100 {
            throw ModelValidationError.invalidFieldLength("プロジェクト名", 1, 100)
        }
        
        if let description = description, description.count > 500 {
            throw ModelValidationError.invalidFieldLength("プロジェクトの説明", 0, 500)
        }
        
        if ownerId.isEmpty {
            throw ModelValidationError.missingRequiredField("プロジェクトオーナー")
        }
        
        if memberIds.isEmpty {
            throw ModelValidationError.invalidRelationship("プロジェクトには少なくとも1人のメンバーが必要です")
        }
        
        // 個人所有の場合のみ、ownerId(=ユーザーID)がメンバーに含まれることを要求
        if ownerType == .individual && !memberIds.contains(ownerId) {
            throw ModelValidationError.invalidRelationship("プロジェクトオーナーはメンバーに含まれている必要があります")
        }
    }
}

extension Phase: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.missingRequiredField("フェーズ名")
        }
        
        if name.count > 100 {
            throw ModelValidationError.invalidFieldLength("フェーズ名", 1, 100)
        }
        
        if let description = description, description.count > 500 {
            throw ModelValidationError.invalidFieldLength("フェーズの説明", 0, 500)
        }
        
        if projectId.isEmpty {
            throw ModelValidationError.missingRequiredField("プロジェクトID")
        }
        
        if createdBy.isEmpty {
            throw ModelValidationError.missingRequiredField("作成者")
        }
        
        if order < 0 {
            throw ModelValidationError.invalidFormat("フェーズの順序")
        }
    }
}

extension TaskList: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.missingRequiredField("タスクリスト名")
        }
        
        if name.count > 100 {
            throw ModelValidationError.invalidFieldLength("タスクリスト名", 1, 100)
        }
        
        if phaseId.isEmpty && familyId == nil {
            throw ModelValidationError.missingRequiredField("フェーズID")
        }
        
        if projectId.isEmpty && familyId == nil {
            throw ModelValidationError.missingRequiredField("プロジェクトID")
        }
        
        if createdBy.isEmpty {
            throw ModelValidationError.missingRequiredField("作成者")
        }
        
        if order < 0 {
            throw ModelValidationError.invalidFormat("タスクリストの順序")
        }
    }
}

extension ShigodekiTask: Validatable {
    func validate() throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.missingRequiredField("タスクタイトル")
        }
        
        if title.count > 200 {
            throw ModelValidationError.invalidFieldLength("タスクタイトル", 1, 200)
        }
        
        if let description = description, description.count > 1000 {
            throw ModelValidationError.invalidFieldLength("タスクの説明", 0, 1000)
        }
        
        // listId は旧モデル（リスト配下タスク）で必須だったが、
        // 新モデル（フェーズ直下タスク）では空も許容するため検証を緩和
        
        if phaseId.isEmpty {
            throw ModelValidationError.missingRequiredField("フェーズID")
        }
        
        if projectId.isEmpty {
            throw ModelValidationError.missingRequiredField("プロジェクトID")
        }
        
        if createdBy.isEmpty {
            throw ModelValidationError.missingRequiredField("作成者")
        }
        
        if order < 0 {
            throw ModelValidationError.invalidFormat("タスクの順序")
        }
        
        if subtaskCount < 0 || completedSubtaskCount < 0 {
            throw ModelValidationError.invalidFormat("サブタスク数")
        }
        
        if completedSubtaskCount > subtaskCount {
            throw ModelValidationError.invalidRelationship("完了サブタスク数がサブタスク総数を上回っています")
        }
        
        if let estimatedHours = estimatedHours, estimatedHours < 0 {
            throw ModelValidationError.invalidFormat("推定時間")
        }
        
        if let actualHours = actualHours, actualHours < 0 {
            throw ModelValidationError.invalidFormat("実際の作業時間")
        }
        
        // Check for circular dependencies
        if dependsOn.contains(id ?? "") {
            throw ModelValidationError.invalidRelationship("タスクが自分自身に依存することはできません")
        }
    }
}

extension Subtask: Validatable {
    func validate() throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.missingRequiredField("サブタスクタイトル")
        }
        
        if title.count > 200 {
            throw ModelValidationError.invalidFieldLength("サブタスクタイトル", 1, 200)
        }
        
        if let description = description, description.count > 500 {
            throw ModelValidationError.invalidFieldLength("サブタスクの説明", 0, 500)
        }
        
        if taskId.isEmpty {
            throw ModelValidationError.missingRequiredField("親タスクID")
        }
        
        // 新モデルではサブタスクもリスト非依存のため検証を緩和
        
        if phaseId.isEmpty {
            throw ModelValidationError.missingRequiredField("フェーズID")
        }
        
        if projectId.isEmpty {
            throw ModelValidationError.missingRequiredField("プロジェクトID")
        }
        
        if createdBy.isEmpty {
            throw ModelValidationError.missingRequiredField("作成者")
        }
        
        if order < 0 {
            throw ModelValidationError.invalidFormat("サブタスクの順序")
        }
    }
}

extension User: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.missingRequiredField("ユーザー名")
        }
        
        if name.count > 100 {
            throw ModelValidationError.invalidFieldLength("ユーザー名", 1, 100)
        }
        
        if email.isEmpty {
            throw ModelValidationError.missingRequiredField("メールアドレス")
        }
        
        if !isValidEmail(email) {
            throw ModelValidationError.invalidFormat("メールアドレス")
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[\\w\\.-]+@[\\w\\.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

extension ProjectInvitation: Validatable {
    func validate() throws {
        if inviteCode.isEmpty {
            throw ModelValidationError.missingRequiredField("招待コード")
        }
        
        if inviteCode.count != 6 {
            throw ModelValidationError.invalidFieldLength("招待コード", 6, 6)
        }
        
        if projectId.isEmpty {
            throw ModelValidationError.missingRequiredField("プロジェクトID")
        }
        
        if projectName.isEmpty {
            throw ModelValidationError.missingRequiredField("プロジェクト名")
        }
        
        if invitedBy.isEmpty {
            throw ModelValidationError.missingRequiredField("招待者")
        }
        
        if invitedByName.isEmpty {
            throw ModelValidationError.missingRequiredField("招待者名")
        }
        
        if let expiresAt = expiresAt, expiresAt <= Date() {
            throw ModelValidationError.invalidFormat("招待の有効期限")
        }
    }
}

extension ProjectMember: Validatable {
    func validate() throws {
        if userId.isEmpty {
            throw ModelValidationError.missingRequiredField("ユーザーID")
        }
        
        if projectId.isEmpty {
            throw ModelValidationError.missingRequiredField("プロジェクトID")
        }
        
        if id != userId {
            throw ModelValidationError.invalidRelationship("メンバーIDはユーザーIDと一致する必要があります")
        }
    }
}
