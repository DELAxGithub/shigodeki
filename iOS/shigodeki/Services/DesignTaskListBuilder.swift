//
//  DesignTaskListBuilder.swift
//  shigodeki
//
//  Created from MobileAppTaskListBuilder split for CLAUDE.md compliance
//  Design and prototype task list builder
//

import Foundation

@MainActor
struct DesignTaskListBuilder {
    
    static func createDesignTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "デザイン",
            color: .green,
            order: 0,
            tasks: [
                TaskTemplate(
                    title: "ワイヤーフレーム作成",
                    description: "主要画面のレイアウト設計",
                    priority: .high,
                    tags: ["UI", "ワイヤーフレーム"],
                    estimatedHours: 20
                ),
                TaskTemplate(
                    title: "デザインシステム構築",
                    description: "カラー、フォント、コンポーネントの統一",
                    priority: .high,
                    tags: ["デザインシステム", "UI"],
                    estimatedHours: 16
                ),
                TaskTemplate(
                    title: "アイコン・画像作成",
                    description: "アプリアイコンと必要な画像素材の作成",
                    priority: .medium,
                    tags: ["アイコン", "画像"],
                    estimatedHours: 12
                )
            ]
        )
    }
    
    static func createPrototypeTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "プロトタイプ",
            color: .orange,
            order: 1,
            tasks: [
                TaskTemplate(
                    title: "インタラクティブプロトタイプ作成",
                    description: "実際の操作感を確認できるプロトタイプを作成",
                    priority: .high,
                    tags: ["プロトタイプ", "UX"],
                    estimatedHours: 24
                ),
                TaskTemplate(
                    title: "ユーザビリティテスト",
                    description: "プロトタイプを使った使いやすさの検証",
                    priority: .medium,
                    tags: ["ユーザビリティ", "テスト"],
                    estimatedHours: 16
                )
            ]
        )
    }
}