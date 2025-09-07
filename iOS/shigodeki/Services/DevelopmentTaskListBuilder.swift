//
//  DevelopmentTaskListBuilder.swift
//  shigodeki
//
//  Created from MobileAppTaskListBuilder split for CLAUDE.md compliance
//  Development task list builder (iOS, Android, Backend)
//

import Foundation

@MainActor
struct DevelopmentTaskListBuilder {
    
    static func createiOSDevelopmentTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "iOS開発",
            color: .blue,
            order: 0,
            tasks: [
                TaskTemplate(
                    title: "Xcodeプロジェクト設定",
                    description: "開発環境とプロジェクト構成の初期設定",
                    priority: .high,
                    tags: ["iOS", "Xcode", "設定"],
                    estimatedHours: 8
                ),
                TaskTemplate(
                    title: "UI実装",
                    description: "SwiftUIまたはUIKitでの画面実装",
                    priority: .high,
                    tags: ["SwiftUI", "UI実装"],
                    estimatedHours: 40
                ),
                TaskTemplate(
                    title: "機能実装",
                    description: "ビジネスロジックとデータ処理の実装",
                    priority: .high,
                    tags: ["Swift", "機能実装"],
                    estimatedHours: 60
                )
            ]
        )
    }
    
    static func createAndroidDevelopmentTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "Android開発",
            color: .green,
            order: 1,
            tasks: [
                TaskTemplate(
                    title: "Android Studioプロジェクト設定",
                    description: "開発環境とプロジェクト構成の初期設定",
                    priority: .high,
                    tags: ["Android", "Android Studio", "設定"],
                    estimatedHours: 8
                ),
                TaskTemplate(
                    title: "UI実装（Compose）",
                    description: "Jetpack Composeでの画面実装",
                    priority: .high,
                    tags: ["Jetpack Compose", "UI実装"],
                    estimatedHours: 40
                ),
                TaskTemplate(
                    title: "機能実装",
                    description: "ビジネスロジックとデータ処理の実装",
                    priority: .high,
                    tags: ["Kotlin", "機能実装"],
                    estimatedHours: 60
                )
            ]
        )
    }
    
    static func createBackendIntegrationTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "バックエンド連携",
            color: .red,
            order: 2,
            tasks: [
                TaskTemplate(
                    title: "API連携実装",
                    description: "サーバーとの通信処理実装",
                    priority: .high,
                    tags: ["API", "通信"],
                    estimatedHours: 24
                ),
                TaskTemplate(
                    title: "データベース設計",
                    description: "ローカルデータベースの設計と実装",
                    priority: .medium,
                    tags: ["データベース", "SQLite"],
                    estimatedHours: 16
                )
            ]
        )
    }
}