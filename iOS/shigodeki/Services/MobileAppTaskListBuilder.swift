//
//  MobileAppTaskListBuilder.swift
//  shigodeki
//
//  Created from MobileAppTemplateService split for CLAUDE.md compliance
//  Mobile app template task list builder
//

import Foundation

@MainActor
struct MobileAppTaskListBuilder {
    
    // MARK: - Task List Creation
    
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
    
    static func createTestingTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "テスト",
            color: .yellow,
            order: 0,
            tasks: [
                TaskTemplate(
                    title: "ユニットテスト作成",
                    description: "個別機能の動作確認テスト",
                    priority: .high,
                    tags: ["ユニットテスト", "自動テスト"],
                    estimatedHours: 32
                ),
                TaskTemplate(
                    title: "UIテスト作成",
                    description: "画面操作の自動テスト",
                    priority: .medium,
                    tags: ["UIテスト", "自動テスト"],
                    estimatedHours: 24
                ),
                TaskTemplate(
                    title: "手動テスト",
                    description: "実機での総合的な動作確認",
                    priority: .high,
                    tags: ["手動テスト", "品質保証"],
                    estimatedHours: 20
                )
            ]
        )
    }
    
    static func createPerformanceTestTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "パフォーマンステスト",
            color: .purple,
            order: 1,
            tasks: [
                TaskTemplate(
                    title: "メモリ・CPU使用量測定",
                    description: "アプリのリソース使用状況の最適化",
                    priority: .medium,
                    tags: ["パフォーマンス", "最適化"],
                    estimatedHours: 12
                ),
                TaskTemplate(
                    title: "バッテリー消費テスト",
                    description: "電池持ちに関する測定と改善",
                    priority: .medium,
                    tags: ["バッテリー", "最適化"],
                    estimatedHours: 8
                )
            ]
        )
    }
    
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