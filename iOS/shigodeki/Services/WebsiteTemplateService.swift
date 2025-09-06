//
//  WebsiteTemplateService.swift
//  shigodeki
//
//  Extracted from SoftwareDevTemplates.swift for CLAUDE.md compliance
//  Website development template generation service
//

import Foundation

@MainActor
class WebsiteTemplateService {
    
    static func generateWebsiteTemplate() -> ProjectTemplate {
        return ProjectTemplate(
            name: "シンプルなウェブサイト作成",
            description: "基本的なウェブサイトを最初から最後まで作成するためのテンプレート",
            goal: "レスポンシブで使いやすいウェブサイトを公開する",
            category: TemplateCategory.softwareDevelopment,
            version: "1.0",
            phases: [
                createPlanningPhase(),
                createDevelopmentPhase(),
                createTestingPhase(),
                createDeploymentPhase()
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .intermediate,
                tags: ["web", "frontend", "HTML", "CSS", "JavaScript"],
                requiredSkills: ["HTML/CSS", "JavaScript基礎", "デザイン基礎"],
                targetAudience: "初心者〜中級者のWeb開発者"
            )
        )
    }
    
    // MARK: - Phase Creation
    
    private static func createPlanningPhase() -> PhaseTemplate {
        PhaseTemplate(
            title: "企画・設計",
            description: "ウェブサイトの企画と基本設計を行う",
            order: 0,
            estimatedDuration: "1-2週間",
            taskLists: [
                createRequirementsTaskList(),
                createDesignTaskList()
            ]
        )
    }
    
    private static func createDevelopmentPhase() -> PhaseTemplate {
        PhaseTemplate(
            title: "開発・実装",
            description: "実際のコーディングとコンテンツ作成",
            order: 1,
            prerequisites: ["企画・設計"],
            estimatedDuration: "3-4週間",
            taskLists: [
                createFrontendTaskList(),
                createContentTaskList()
            ]
        )
    }
    
    private static func createTestingPhase() -> PhaseTemplate {
        PhaseTemplate(
            title: "テスト・最適化",
            description: "品質チェックとパフォーマンス最適化",
            order: 2,
            prerequisites: ["開発・実装"],
            estimatedDuration: "1-2週間",
            taskLists: [
                createQualityTestTaskList(),
                createOptimizationTaskList()
            ]
        )
    }
    
    private static func createDeploymentPhase() -> PhaseTemplate {
        PhaseTemplate(
            title: "デプロイ・公開",
            description: "本番環境へのデプロイとSEO対策",
            order: 3,
            prerequisites: ["テスト・最適化"],
            estimatedDuration: "数日",
            taskLists: [
                createDeploymentTaskList()
            ]
        )
    }
    
    // MARK: - Task List Creation
    
    private static func createRequirementsTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "要件定義",
            color: .blue,
            order: 0,
            tasks: [
                TaskTemplate(
                    title: "目的と目標の明確化",
                    description: "ウェブサイトの目的、ターゲット、成功指標を定義する",
                    priority: .high,
                    tags: ["企画", "要件"],
                    estimatedHours: 4
                ),
                TaskTemplate(
                    title: "競合サイト調査",
                    description: "類似サイトの分析と差別化ポイントの洗い出し",
                    priority: .medium,
                    tags: ["リサーチ", "競合分析"],
                    estimatedHours: 6
                ),
                TaskTemplate(
                    title: "機能要件の整理",
                    description: "必要な機能とページ構成の決定",
                    priority: .high,
                    tags: ["機能", "要件"],
                    estimatedHours: 8
                )
            ]
        )
    }
    
    private static func createDesignTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "設計",
            color: .purple,
            order: 1,
            tasks: [
                TaskTemplate(
                    title: "サイトマップ作成",
                    description: "ウェブサイト全体の構造を視覚化",
                    priority: .high,
                    tags: ["設計", "構造"],
                    estimatedHours: 4
                ),
                TaskTemplate(
                    title: "ワイヤーフレーム作成",
                    description: "主要ページのレイアウト設計",
                    priority: .high,
                    tags: ["UI", "設計"],
                    estimatedHours: 12
                ),
                TaskTemplate(
                    title: "デザインシステム定義",
                    description: "カラー、フォント、コンポーネントのルール策定",
                    priority: .medium,
                    tags: ["デザイン", "システム"],
                    estimatedHours: 8
                )
            ]
        )
    }
    
    private static func createFrontendTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "フロントエンド開発",
            color: .green,
            order: 0,
            tasks: [
                TaskTemplate(
                    title: "環境構築",
                    description: "開発環境のセットアップとツールチェーンの準備",
                    priority: .high,
                    tags: ["環境", "セットアップ"],
                    estimatedHours: 4
                ),
                TaskTemplate(
                    title: "HTMLマークアップ",
                    description: "セマンティックなHTML構造の実装",
                    priority: .high,
                    tags: ["HTML", "マークアップ"],
                    estimatedHours: 16
                ),
                TaskTemplate(
                    title: "CSSスタイリング",
                    description: "レスポンシブデザインの実装",
                    priority: .high,
                    tags: ["CSS", "レスポンシブ"],
                    estimatedHours: 20
                ),
                TaskTemplate(
                    title: "JavaScript機能実装",
                    description: "インタラクティブな機能の追加",
                    priority: .medium,
                    tags: ["JavaScript", "機能"],
                    estimatedHours: 12
                )
            ]
        )
    }
    
    private static func createContentTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "コンテンツ作成",
            color: .orange,
            order: 1,
            tasks: [
                TaskTemplate(
                    title: "テキストコンテンツ執筆",
                    description: "各ページのテキスト内容を作成",
                    priority: .medium,
                    tags: ["コンテンツ", "ライティング"],
                    estimatedHours: 16
                ),
                TaskTemplate(
                    title: "画像・メディア準備",
                    description: "最適化された画像とメディアファイルの準備",
                    priority: .medium,
                    tags: ["画像", "メディア"],
                    estimatedHours: 8
                )
            ]
        )
    }
    
    private static func createQualityTestTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "品質テスト",
            color: .red,
            order: 0,
            tasks: [
                TaskTemplate(
                    title: "クロスブラウザテスト",
                    description: "主要ブラウザでの動作確認",
                    priority: .high,
                    tags: ["テスト", "ブラウザ"],
                    estimatedHours: 8
                ),
                TaskTemplate(
                    title: "レスポンシブテスト",
                    description: "様々なデバイスサイズでの表示確認",
                    priority: .high,
                    tags: ["テスト", "レスポンシブ"],
                    estimatedHours: 6
                ),
                TaskTemplate(
                    title: "アクセシビリティチェック",
                    description: "WCAG 2.1準拠の確認と修正",
                    priority: .medium,
                    tags: ["アクセシビリティ", "WCAG"],
                    estimatedHours: 8
                )
            ]
        )
    }
    
    private static func createOptimizationTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "パフォーマンス最適化",
            color: .yellow,
            order: 1,
            tasks: [
                TaskTemplate(
                    title: "画像最適化",
                    description: "WebPフォーマット対応と圧縮最適化",
                    priority: .medium,
                    tags: ["最適化", "画像"],
                    estimatedHours: 4
                ),
                TaskTemplate(
                    title: "CSS/JS最適化",
                    description: "ファイルの圧縮とバンドル最適化",
                    priority: .medium,
                    tags: ["最適化", "パフォーマンス"],
                    estimatedHours: 6
                )
            ]
        )
    }
    
    private static func createDeploymentTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "デプロイメント",
            color: .blue,
            order: 0,
            tasks: [
                TaskTemplate(
                    title: "ホスティング設定",
                    description: "本番サーバーのセットアップと設定",
                    priority: .high,
                    tags: ["デプロイ", "ホスティング"],
                    estimatedHours: 4
                ),
                TaskTemplate(
                    title: "ドメイン・SSL設定",
                    description: "独自ドメインとSSL証明書の設定",
                    priority: .high,
                    tags: ["ドメイン", "SSL"],
                    estimatedHours: 2
                ),
                TaskTemplate(
                    title: "SEO基本設定",
                    description: "メタタグ、サイトマップ、robots.txtの設定",
                    priority: .medium,
                    tags: ["SEO", "検索エンジン"],
                    estimatedHours: 4
                )
            ]
        )
    }
}