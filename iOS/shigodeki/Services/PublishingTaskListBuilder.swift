//
//  PublishingTaskListBuilder.swift
//  shigodeki
//
//  Created from MobileAppTaskListBuilder split for CLAUDE.md compliance
//  App store publishing and marketing task list builder
//

import Foundation

@MainActor
struct PublishingTaskListBuilder {
    
    static func createAppStoreTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "アプリストア公開",
            color: .blue,
            order: 0,
            tasks: [
                TaskTemplate(
                    title: "App Store申請準備",
                    description: "スクリーンショット、説明文、メタデータの準備",
                    priority: .high,
                    tags: ["App Store", "申請"],
                    estimatedHours: 12
                ),
                TaskTemplate(
                    title: "Google Play申請準備",
                    description: "ストア掲載情報とAPKの準備",
                    priority: .high,
                    tags: ["Google Play", "申請"],
                    estimatedHours: 12
                ),
                TaskTemplate(
                    title: "審査対応",
                    description: "ストア審査での修正要求への対応",
                    priority: .medium,
                    tags: ["審査", "修正"],
                    estimatedHours: 16
                )
            ]
        )
    }
    
    static func createMarketingTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "マーケティング",
            color: .orange,
            order: 1,
            tasks: [
                TaskTemplate(
                    title: "プロモーション素材作成",
                    description: "SNSやウェブサイトでの宣伝素材作成",
                    priority: .low,
                    tags: ["マーケティング", "プロモーション"],
                    estimatedHours: 8
                ),
                TaskTemplate(
                    title: "リリース戦略実行",
                    description: "公開タイミングと宣伝活動の実施",
                    priority: .medium,
                    tags: ["リリース", "戦略"],
                    estimatedHours: 4
                )
            ]
        )
    }
}