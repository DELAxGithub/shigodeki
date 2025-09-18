//
//  TemplateDraftBuilder.swift
//  shigodeki
//
//  Generates TaskDrafts for quick-pick templates used in unified preview flow.
//

import Foundation

enum TemplateQuickPick: CaseIterable {
    case endOfLife
    case moving
    case caregiving

    var title: String {
        switch self {
        case .endOfLife: return "終活サポート"
        case .moving: return "引っ越し準備"
        case .caregiving: return "介護スタート"
        }
    }

    var description: String {
        switch self {
        case .endOfLife:
            return "親の終活でやるべきことを整理します"
        case .moving:
            return "引っ越し前後のチェックリスト"
        case .caregiving:
            return "介護が必要になった際の初動タスク"
        }
    }
}

enum TemplateDraftBuilder {
    static func build(for quickPick: TemplateQuickPick) -> [TaskDraft] {
        switch quickPick {
        case .endOfLife:
            return [
                TaskDraft(title: "家族で介護方針を話し合う", assignee: nil, due: nil, rationale: "家族で役割や希望を共有", priority: .medium),
                TaskDraft(title: "親の意思・連絡先をまとめる", assignee: nil, due: nil, rationale: "医療・葬儀先のメモ、緊急連絡リストを整備", priority: .medium),
                TaskDraft(title: "必要な公的手続きを確認", assignee: nil, due: nil, rationale: "要介護認定や遺言関連の手続きを調査", priority: .medium)
            ]
        case .moving:
            return [
                TaskDraft(title: "引っ越し業者の見積もりを取る", assignee: nil, due: nil, rationale: "3社比較して費用と日程を決定", priority: .medium),
                TaskDraft(title: "住所変更手続きリストを作る", assignee: nil, due: nil, rationale: "役所・銀行・カード会社の手続きを洗い出す", priority: .medium),
                TaskDraft(title: "不要品の処分計画を立てる", assignee: nil, due: nil, rationale: "粗大ゴミ・リサイクル・譲渡のスケジュール", priority: .medium)
            ]
        case .caregiving:
            return [
                TaskDraft(title: "要介護認定を申請する", assignee: nil, due: nil, rationale: "自治体窓口に書類を提出し調査日を決める", priority: .high),
                TaskDraft(title: "ケアマネージャーと面談を設定", assignee: nil, due: nil, rationale: "親の状態と希望を共有してケアプラン作成", priority: .medium),
                TaskDraft(title: "緊急連絡先リストを整備", assignee: nil, due: nil, rationale: "親戚・主治医・支援サービスの連絡先をまとめる", priority: .medium)
            ]
        }
    }
}
