//
//  WebApiTaskListBuilder.swift
//  shigodeki
//
//  Extracted from WebApiTemplateService.swift on 2025-09-07.
//  Web API development task list generation builder
//

import Foundation

struct WebApiTaskListBuilder {
    
    // MARK: - Task List Creation
    
    static func createApiDesignTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "設計",
            color: .blue,
            order: 0,
            tasks: [
                TaskTemplate(
                    title: "API仕様書作成",
                    description: "OpenAPI/Swaggerを使用したAPI仕様の定義",
                    priority: .high,
                    tags: ["API", "仕様", "OpenAPI"],
                    estimatedHours: 20
                ),
                TaskTemplate(
                    title: "エンドポイント設計",
                    description: "RESTful原則に基づくURLとHTTPメソッドの設計",
                    priority: .high,
                    tags: ["REST", "エンドポイント"],
                    estimatedHours: 16
                ),
                TaskTemplate(
                    title: "エラーハンドリング設計",
                    description: "統一されたエラーレスポンス形式の定義",
                    priority: .medium,
                    tags: ["エラー", "設計"],
                    estimatedHours: 8
                )
            ]
        )
    }
    
    static func createDataModelTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "データモデル",
            color: .purple,
            order: 1,
            tasks: [
                TaskTemplate(
                    title: "データベーススキーマ設計",
                    description: "効率的なテーブル構造とリレーションシップの設計",
                    priority: .high,
                    tags: ["データベース", "スキーマ"],
                    estimatedHours: 24
                ),
                TaskTemplate(
                    title: "JSONスキーマ定義",
                    description: "リクエスト/レスポンスのデータ形式定義",
                    priority: .high,
                    tags: ["JSON", "スキーマ"],
                    estimatedHours: 12
                )
            ]
        )
    }
    
    static func createServerImplementationTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "サーバー実装",
            color: .green,
            order: 0,
            tasks: [
                TaskTemplate(
                    title: "開発環境構築",
                    description: "サーバーフレームワークと開発ツールのセットアップ",
                    priority: .high,
                    tags: ["環境構築", "フレームワーク"],
                    estimatedHours: 8
                ),
                TaskTemplate(
                    title: "ルーティング実装",
                    description: "各エンドポイントのルーティング設定",
                    priority: .high,
                    tags: ["ルーティング", "エンドポイント"],
                    estimatedHours: 20
                ),
                TaskTemplate(
                    title: "ビジネスロジック実装",
                    description: "各APIの処理ロジック実装",
                    priority: .high,
                    tags: ["ビジネスロジック", "処理"],
                    estimatedHours: 40
                ),
                TaskTemplate(
                    title: "バリデーション実装",
                    description: "入力データの検証処理",
                    priority: .medium,
                    tags: ["バリデーション", "検証"],
                    estimatedHours: 16
                )
            ]
        )
    }
    
    static func createDatabaseTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "データベース",
            color: .orange,
            order: 1,
            tasks: [
                TaskTemplate(
                    title: "データベースセットアップ",
                    description: "本番用データベースの構築と設定",
                    priority: .high,
                    tags: ["データベース", "セットアップ"],
                    estimatedHours: 12
                ),
                TaskTemplate(
                    title: "マイグレーション作成",
                    description: "データベーススキーマのバージョン管理",
                    priority: .high,
                    tags: ["マイグレーション", "スキーマ"],
                    estimatedHours: 16
                ),
                TaskTemplate(
                    title: "ORM/クエリ実装",
                    description: "データアクセスレイヤーの実装",
                    priority: .medium,
                    tags: ["ORM", "クエリ"],
                    estimatedHours: 24
                )
            ]
        )
    }
    
    static func createAuthenticationTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "認証・認可",
            color: .red,
            order: 2,
            tasks: [
                TaskTemplate(
                    title: "認証システム実装",
                    description: "JWTまたはOAuth2による認証機能",
                    priority: .high,
                    tags: ["認証", "JWT", "OAuth2"],
                    estimatedHours: 24
                ),
                TaskTemplate(
                    title: "認可制御実装",
                    description: "ロールベースアクセス制御の実装",
                    priority: .medium,
                    tags: ["認可", "RBAC"],
                    estimatedHours: 16
                ),
                TaskTemplate(
                    title: "セキュリティミドルウェア",
                    description: "CORS、レート制限等のセキュリティ対策",
                    priority: .medium,
                    tags: ["セキュリティ", "ミドルウェア"],
                    estimatedHours: 12
                )
            ]
        )
    }
    
    static func createApiTestingTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "APIテスト",
            color: .yellow,
            order: 0,
            tasks: [
                TaskTemplate(
                    title: "ユニットテスト作成",
                    description: "個別機能のテストケース作成",
                    priority: .high,
                    tags: ["ユニットテスト", "テスト"],
                    estimatedHours: 32
                ),
                TaskTemplate(
                    title: "統合テスト作成",
                    description: "エンドポイント全体のテスト",
                    priority: .high,
                    tags: ["統合テスト", "API"],
                    estimatedHours: 24
                ),
                TaskTemplate(
                    title: "パフォーマンステスト",
                    description: "負荷テストと応答時間測定",
                    priority: .medium,
                    tags: ["パフォーマンス", "負荷テスト"],
                    estimatedHours: 16
                )
            ]
        )
    }
    
    static func createSecurityTestTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "セキュリティテスト",
            color: .red,
            order: 1,
            tasks: [
                TaskTemplate(
                    title: "脆弱性スキャン",
                    description: "セキュリティホールの検出と修正",
                    priority: .high,
                    tags: ["セキュリティ", "脆弱性"],
                    estimatedHours: 16
                ),
                TaskTemplate(
                    title: "認証テスト",
                    description: "認証・認可機能の詳細テスト",
                    priority: .high,
                    tags: ["認証", "テスト"],
                    estimatedHours: 12
                ),
                TaskTemplate(
                    title: "データ保護テスト",
                    description: "個人情報とセンシティブデータの保護確認",
                    priority: .medium,
                    tags: ["データ保護", "プライバシー"],
                    estimatedHours: 8
                )
            ]
        )
    }
    
    static func createDeploymentTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "デプロイメント",
            color: .blue,
            order: 0,
            tasks: [
                TaskTemplate(
                    title: "本番環境構築",
                    description: "クラウドインフラのセットアップ",
                    priority: .high,
                    tags: ["インフラ", "クラウド"],
                    estimatedHours: 16
                ),
                TaskTemplate(
                    title: "CI/CDパイプライン構築",
                    description: "自動デプロイメントシステムの構築",
                    priority: .medium,
                    tags: ["CI/CD", "自動化"],
                    estimatedHours: 20
                ),
                TaskTemplate(
                    title: "SSL/TLS設定",
                    description: "HTTPS対応とセキュリティ証明書設定",
                    priority: .high,
                    tags: ["SSL", "HTTPS"],
                    estimatedHours: 4
                )
            ]
        )
    }
    
    static func createMonitoringTaskList() -> TaskListTemplate {
        TaskListTemplate(
            name: "監視・ログ",
            color: .purple,
            order: 1,
            tasks: [
                TaskTemplate(
                    title: "ログシステム構築",
                    description: "アプリケーションログの収集と分析システム",
                    priority: .medium,
                    tags: ["ログ", "監視"],
                    estimatedHours: 12
                ),
                TaskTemplate(
                    title: "監視システム設定",
                    description: "パフォーマンス監視とアラート設定",
                    priority: .medium,
                    tags: ["監視", "アラート"],
                    estimatedHours: 16
                ),
                TaskTemplate(
                    title: "API文書化",
                    description: "利用者向けAPIドキュメントの作成",
                    priority: .low,
                    tags: ["文書化", "API"],
                    estimatedHours: 8
                )
            ]
        )
    }
}