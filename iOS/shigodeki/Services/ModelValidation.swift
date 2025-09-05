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

enum ValidationError: LocalizedError {
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
            throw ValidationError.missingRequiredField("プロジェクト名")
        }
        
        if name.count > 100 {
            throw ValidationError.invalidFieldLength("プロジェクト名", 1, 100)
        }
        
        if let description = description, description.count > 500 {
            throw ValidationError.invalidFieldLength("プロジェクトの説明", 0, 500)
        }
        
        if ownerId.isEmpty {
            throw ValidationError.missingRequiredField("プロジェクトオーナー")
        }
        
        if memberIds.isEmpty {
            throw ValidationError.invalidRelationship("プロジェクトには少なくとも1人のメンバーが必要です")
        }
        
        // 個人所有の場合のみ、ownerId(=ユーザーID)がメンバーに含まれることを要求
        if ownerType == .individual && !memberIds.contains(ownerId) {
            throw ValidationError.invalidRelationship("プロジェクトオーナーはメンバーに含まれている必要があります")
        }
    }
}

extension Phase: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.missingRequiredField("フェーズ名")
        }
        
        if name.count > 100 {
            throw ValidationError.invalidFieldLength("フェーズ名", 1, 100)
        }
        
        if let description = description, description.count > 500 {
            throw ValidationError.invalidFieldLength("フェーズの説明", 0, 500)
        }
        
        if projectId.isEmpty {
            throw ValidationError.missingRequiredField("プロジェクトID")
        }
        
        if createdBy.isEmpty {
            throw ValidationError.missingRequiredField("作成者")
        }
        
        if order < 0 {
            throw ValidationError.invalidFormat("フェーズの順序")
        }
    }
}

extension TaskList: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.missingRequiredField("タスクリスト名")
        }
        
        if name.count > 100 {
            throw ValidationError.invalidFieldLength("タスクリスト名", 1, 100)
        }
        
        if phaseId.isEmpty && familyId == nil {
            throw ValidationError.missingRequiredField("フェーズID")
        }
        
        if projectId.isEmpty && familyId == nil {
            throw ValidationError.missingRequiredField("プロジェクトID")
        }
        
        if createdBy.isEmpty {
            throw ValidationError.missingRequiredField("作成者")
        }
        
        if order < 0 {
            throw ValidationError.invalidFormat("タスクリストの順序")
        }
    }
}

extension ShigodekiTask: Validatable {
    func validate() throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.missingRequiredField("タスクタイトル")
        }
        
        if title.count > 200 {
            throw ValidationError.invalidFieldLength("タスクタイトル", 1, 200)
        }
        
        if let description = description, description.count > 1000 {
            throw ValidationError.invalidFieldLength("タスクの説明", 0, 1000)
        }
        
        // listId は旧モデル（リスト配下タスク）で必須だったが、
        // 新モデル（フェーズ直下タスク）では空も許容するため検証を緩和
        
        if phaseId.isEmpty {
            throw ValidationError.missingRequiredField("フェーズID")
        }
        
        if projectId.isEmpty {
            throw ValidationError.missingRequiredField("プロジェクトID")
        }
        
        if createdBy.isEmpty {
            throw ValidationError.missingRequiredField("作成者")
        }
        
        if order < 0 {
            throw ValidationError.invalidFormat("タスクの順序")
        }
        
        if subtaskCount < 0 || completedSubtaskCount < 0 {
            throw ValidationError.invalidFormat("サブタスク数")
        }
        
        if completedSubtaskCount > subtaskCount {
            throw ValidationError.invalidRelationship("完了サブタスク数がサブタスク総数を上回っています")
        }
        
        if let estimatedHours = estimatedHours, estimatedHours < 0 {
            throw ValidationError.invalidFormat("推定時間")
        }
        
        if let actualHours = actualHours, actualHours < 0 {
            throw ValidationError.invalidFormat("実際の作業時間")
        }
        
        // Check for circular dependencies
        if dependsOn.contains(id ?? "") {
            throw ValidationError.invalidRelationship("タスクが自分自身に依存することはできません")
        }
    }
}

extension Subtask: Validatable {
    func validate() throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.missingRequiredField("サブタスクタイトル")
        }
        
        if title.count > 200 {
            throw ValidationError.invalidFieldLength("サブタスクタイトル", 1, 200)
        }
        
        if let description = description, description.count > 500 {
            throw ValidationError.invalidFieldLength("サブタスクの説明", 0, 500)
        }
        
        if taskId.isEmpty {
            throw ValidationError.missingRequiredField("親タスクID")
        }
        
        // 新モデルではサブタスクもリスト非依存のため検証を緩和
        
        if phaseId.isEmpty {
            throw ValidationError.missingRequiredField("フェーズID")
        }
        
        if projectId.isEmpty {
            throw ValidationError.missingRequiredField("プロジェクトID")
        }
        
        if createdBy.isEmpty {
            throw ValidationError.missingRequiredField("作成者")
        }
        
        if order < 0 {
            throw ValidationError.invalidFormat("サブタスクの順序")
        }
    }
}

extension User: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.missingRequiredField("ユーザー名")
        }
        
        if name.count > 100 {
            throw ValidationError.invalidFieldLength("ユーザー名", 1, 100)
        }
        
        if email.isEmpty {
            throw ValidationError.missingRequiredField("メールアドレス")
        }
        
        if !isValidEmail(email) {
            throw ValidationError.invalidFormat("メールアドレス")
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
            throw ValidationError.missingRequiredField("招待コード")
        }
        
        if inviteCode.count != 6 {
            throw ValidationError.invalidFieldLength("招待コード", 6, 6)
        }
        
        if projectId.isEmpty {
            throw ValidationError.missingRequiredField("プロジェクトID")
        }
        
        if projectName.isEmpty {
            throw ValidationError.missingRequiredField("プロジェクト名")
        }
        
        if invitedBy.isEmpty {
            throw ValidationError.missingRequiredField("招待者")
        }
        
        if invitedByName.isEmpty {
            throw ValidationError.missingRequiredField("招待者名")
        }
        
        if let expiresAt = expiresAt, expiresAt <= Date() {
            throw ValidationError.invalidFormat("招待の有効期限")
        }
    }
}

extension ProjectMember: Validatable {
    func validate() throws {
        if userId.isEmpty {
            throw ValidationError.missingRequiredField("ユーザーID")
        }
        
        if projectId.isEmpty {
            throw ValidationError.missingRequiredField("プロジェクトID")
        }
        
        if id != userId {
            throw ValidationError.invalidRelationship("メンバーIDはユーザーIDと一致する必要があります")
        }
    }
}
