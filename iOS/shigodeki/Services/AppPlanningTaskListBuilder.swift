//
//  AppPlanningTaskListBuilder.swift
//  shigodeki
//
//  Created from MobileAppTaskListBuilder split for CLAUDE.md compliance
//  App planning and market research task list builder
//

import Foundation

@MainActor
struct AppPlanningTaskListBuilder {
    
    static func createAppPlanningTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "アプリ企画",
            color: .blue,
            order: 0,
            tasks: [
                TaskTemplate(
                    title: "ターゲットユーザー分析",
                    description: "アプリを使用するユーザーの特性と課題を分析",
                    priority: .high,
                    tags: ["企画", "ユーザー分析"],
                    estimatedHours: 8
                ),
                TaskTemplate(
                    title: "機能仕様書作成",
                    description: "アプリの主要機能と画面遷移を定義",
                    priority: .high,
                    tags: ["仕様", "機能"],
                    estimatedHours: 16
                ),
                TaskTemplate(
                    title: "技術選定",
                    description: "開発プラットフォームとアーキテクチャの決定",
                    priority: .high,
                    tags: ["技術", "アーキテクチャ"],
                    estimatedHours: 12
                )
            ]
        )
    }
    
    static func createMarketResearchTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "市場調査",
            color: .purple,
            order: 1,
            tasks: [
                TaskTemplate(
                    title: "競合アプリ分析",
                    description: "類似アプリの機能と評価を分析",
                    priority: .medium,
                    tags: ["競合分析", "市場調査"],
                    estimatedHours: 12
                ),
                TaskTemplate(
                    title: "収益モデル設計",
                    description: "マネタイゼーション戦略の策定",
                    priority: .medium,
                    tags: ["収益", "ビジネスモデル"],
                    estimatedHours: 8
                )
            ]
        )
    }
}