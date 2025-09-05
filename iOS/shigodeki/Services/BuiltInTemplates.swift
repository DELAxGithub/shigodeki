//
//  BuiltInTemplates.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import Foundation

class BuiltInTemplates {
    
    static var allTemplates: [ProjectTemplate] {
        return [
            // ソフトウェア開発テンプレート
            sampleWebsiteTemplate,
            mobileAppTemplate,
            webApiTemplate,
            
            // プロジェクト管理テンプレート
            productLaunchTemplate,
            teamOnboardingTemplate,
            
            // イベント企画テンプレート
            conferenceTemplate,
            weddingPlanningTemplate,
            
            // ライフイベントテンプレート
            movingTemplate,
            homeRenovationTemplate,
            
            // ビジネステンプレート
            startupLaunchTemplate,
            marketingCampaignTemplate,
            
            // 教育・学習テンプレート
            languageLearningTemplate,
            skillDevelopmentTemplate,
            
            // 個人テンプレート
            healthGoalsTemplate,
            travelPlanningTemplate
        ]
    }
    
    // MARK: - Software Development Templates
    
    static var sampleWebsiteTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "シンプルなウェブサイト作成",
            description: "基本的なウェブサイトを最初から最後まで作成するためのテンプレート",
            goal: "レスポンシブで使いやすいウェブサイトを公開する",
            category: .softwareDevelopment,
            version: "1.0",
            phases: [
                PhaseTemplate(
                    title: "企画・設計",
                    description: "ウェブサイトの企画と基本設計を行う",
                    order: 0,
                    estimatedDuration: "1-2週間",
                    taskLists: [
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
                        ),
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
                    ]
                ),
                PhaseTemplate(
                    title: "開発・実装",
                    description: "実際のコーディングとコンテンツ作成",
                    order: 1,
                    prerequisites: ["企画・設計"],
                    estimatedDuration: "3-4週間",
                    taskLists: [
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
                        ),
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
                    ]
                ),
                PhaseTemplate(
                    title: "テスト・最適化",
                    description: "品質チェックとパフォーマンス最適化",
                    order: 2,
                    prerequisites: ["開発・実装"],
                    estimatedDuration: "1-2週間",
                    taskLists: [
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
                        ),
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
                    ]
                ),
                PhaseTemplate(
                    title: "デプロイ・公開",
                    description: "本番環境へのデプロイとSEO対策",
                    order: 3,
                    prerequisites: ["テスト・最適化"],
                    estimatedDuration: "数日",
                    taskLists: [
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
                    ]
                )
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
    
    static var mobileAppTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "モバイルアプリ開発",
            description: "iOS/Androidアプリを最初から最後まで開発するためのテンプレート",
            goal: "App StoreとGoogle Playでの公開",
            category: .softwareDevelopment,
            phases: [
                PhaseTemplate(
                    title: "企画・プロトタイプ",
                    description: "アプリの企画とプロトタイプ作成",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "アプリ企画",
                            tasks: [
                                TaskTemplate(
                                    title: "ターゲットユーザー分析",
                                    description: "アプリを使用するユーザーの特性と課題を分析",
                                    priority: .high,
                                    tags: ["企画", "ユーザー分析"]
                                ),
                                TaskTemplate(
                                    title: "機能仕様書作成",
                                    description: "アプリの主要機能と画面遷移を定義",
                                    priority: .high,
                                    tags: ["仕様", "機能"]
                                )
                            ]
                        )
                    ]
                ),
                PhaseTemplate(
                    title: "UI/UXデザイン",
                    description: "ユーザーインターフェースの設計",
                    order: 1,
                    taskLists: [
                        TaskListTemplate(
                            name: "デザイン",
                            tasks: [
                                TaskTemplate(
                                    title: "ワイヤーフレーム作成",
                                    priority: .high,
                                    tags: ["UI", "ワイヤーフレーム"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .advanced,
                tags: ["mobile", "iOS", "Android", "app"]
            )
        )
    }
    
    static var webApiTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "Web API開発",
            description: "RESTful APIの設計から実装まで",
            category: .softwareDevelopment,
            phases: [
                PhaseTemplate(
                    title: "API設計",
                    description: "エンドポイントとデータ構造の設計",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "設計",
                            tasks: [
                                TaskTemplate(
                                    title: "API仕様書作成",
                                    priority: .high,
                                    tags: ["API", "仕様"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .advanced,
                tags: ["API", "backend", "REST"]
            )
        )
    }
    
    // MARK: - Project Management Templates
    
    static var productLaunchTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "新商品・サービスローンチ",
            description: "新商品やサービスの市場投入を成功させるための包括的なテンプレート",
            goal: "ターゲット市場での認知度向上と売上目標達成",
            category: .projectManagement,
            phases: [
                PhaseTemplate(
                    title: "市場調査・戦略立案",
                    description: "市場分析と商品戦略の策定",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "市場分析",
                            tasks: [
                                TaskTemplate(
                                    title: "競合分析",
                                    description: "競合他社の商品、価格、マーケティング戦略を調査",
                                    priority: .high,
                                    tags: ["市場調査", "競合"]
                                ),
                                TaskTemplate(
                                    title: "ターゲット顧客の明確化",
                                    description: "ペルソナの作成とニーズ分析",
                                    priority: .high,
                                    tags: ["顧客", "ペルソナ"]
                                )
                            ]
                        )
                    ]
                ),
                PhaseTemplate(
                    title: "マーケティング準備",
                    description: "プロモーション戦略と販促材料の準備",
                    order: 1,
                    taskLists: [
                        TaskListTemplate(
                            name: "販促資料",
                            tasks: [
                                TaskTemplate(
                                    title: "ランディングページ作成",
                                    priority: .high,
                                    tags: ["マーケティング", "LP"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .intermediate,
                tags: ["launch", "marketing", "business"]
            )
        )
    }
    
    static var teamOnboardingTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "新チームメンバーオンボーディング",
            description: "新しいチームメンバーの効果的な受け入れと育成プロセス",
            category: .projectManagement,
            phases: [
                PhaseTemplate(
                    title: "事前準備",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "環境準備",
                            tasks: [
                                TaskTemplate(
                                    title: "アカウント・権限設定",
                                    priority: .high,
                                    tags: ["準備", "アクセス"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .beginner,
                tags: ["onboarding", "team", "HR"]
            )
        )
    }
    
    // MARK: - Event Planning Templates
    
    static var conferenceTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "カンファレンス・セミナー企画",
            description: "成功するビジネスイベントの企画・運営テンプレート",
            category: .eventPlanning,
            phases: [
                PhaseTemplate(
                    title: "企画・準備",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "基本企画",
                            tasks: [
                                TaskTemplate(
                                    title: "イベントコンセプト決定",
                                    priority: .high,
                                    tags: ["企画", "コンセプト"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .intermediate,
                tags: ["conference", "event", "seminar"]
            )
        )
    }
    
    static var weddingPlanningTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "結婚式準備",
            description: "思い出に残る結婚式を計画するためのテンプレート",
            category: .lifeEvents,
            phases: [
                PhaseTemplate(
                    title: "基本計画",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "式場選び",
                            tasks: [
                                TaskTemplate(
                                    title: "予算設定",
                                    priority: .high,
                                    tags: ["予算", "計画"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .intermediate,
                tags: ["wedding", "ceremony", "life"]
            )
        )
    }
    
    // MARK: - Life Events Templates
    
    static var movingTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "引越し準備",
            description: "スムーズな引越しのための準備チェックリスト",
            category: .lifeEvents,
            phases: [
                PhaseTemplate(
                    title: "引越し2ヶ月前",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "基本手続き",
                            tasks: [
                                TaskTemplate(
                                    title: "引越し業者の選定・見積り",
                                    priority: .high,
                                    tags: ["業者", "見積り"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .beginner,
                tags: ["moving", "relocation", "life"]
            )
        )
    }
    
    static var homeRenovationTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "住宅リフォーム",
            description: "住宅リフォームプロジェクトの計画・実行テンプレート",
            category: .lifeEvents,
            phases: [
                PhaseTemplate(
                    title: "計画・設計",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "設計",
                            tasks: [
                                TaskTemplate(
                                    title: "リフォーム箇所の決定",
                                    priority: .high,
                                    tags: ["計画", "設計"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .intermediate,
                tags: ["renovation", "home", "construction"]
            )
        )
    }
    
    // MARK: - Business Templates
    
    static var startupLaunchTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "スタートアップ立ち上げ",
            description: "新規事業・スタートアップの立ち上げプロセス",
            category: .business,
            phases: [
                PhaseTemplate(
                    title: "事業計画",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "計画策定",
                            tasks: [
                                TaskTemplate(
                                    title: "事業計画書作成",
                                    priority: .high,
                                    tags: ["事業計画", "起業"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .expert,
                tags: ["startup", "business", "entrepreneurship"]
            )
        )
    }
    
    static var marketingCampaignTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "マーケティングキャンペーン",
            description: "効果的なマーケティングキャンペーンの企画・実行",
            category: .business,
            phases: [
                PhaseTemplate(
                    title: "戦略立案",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "戦略",
                            tasks: [
                                TaskTemplate(
                                    title: "ターゲット分析",
                                    priority: .high,
                                    tags: ["マーケティング", "戦略"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .intermediate,
                tags: ["marketing", "campaign", "promotion"]
            )
        )
    }
    
    // MARK: - Education Templates
    
    static var languageLearningTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "語学学習プログラム",
            description: "体系的な語学習得のための学習計画",
            category: .education,
            phases: [
                PhaseTemplate(
                    title: "基礎学習",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "基礎",
                            tasks: [
                                TaskTemplate(
                                    title: "現在のレベル測定",
                                    priority: .high,
                                    tags: ["評価", "レベル"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .beginner,
                tags: ["language", "learning", "education"]
            )
        )
    }
    
    static var skillDevelopmentTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "スキル開発プログラム",
            description: "新しいスキルの習得と向上のための体系的なアプローチ",
            category: .education,
            phases: [
                PhaseTemplate(
                    title: "学習計画",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "計画",
                            tasks: [
                                TaskTemplate(
                                    title: "学習目標設定",
                                    priority: .high,
                                    tags: ["目標", "計画"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .beginner,
                tags: ["skill", "development", "learning"]
            )
        )
    }
    
    // MARK: - Personal Templates
    
    static var healthGoalsTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "健康・フィットネス目標",
            description: "健康的なライフスタイルの構築と維持",
            category: .health,
            phases: [
                PhaseTemplate(
                    title: "現状評価",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "評価",
                            tasks: [
                                TaskTemplate(
                                    title: "健康診断・体力測定",
                                    priority: .high,
                                    tags: ["健康", "評価"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .beginner,
                tags: ["health", "fitness", "wellness"]
            )
        )
    }
    
    static var travelPlanningTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "旅行計画",
            description: "思い出に残る旅行の計画・準備テンプレート",
            category: .travel,
            phases: [
                PhaseTemplate(
                    title: "計画・予約",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "基本計画",
                            tasks: [
                                TaskTemplate(
                                    title: "行き先・日程決定",
                                    priority: .high,
                                    tags: ["計画", "日程"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .beginner,
                tags: ["travel", "vacation", "planning"]
            )
        )
    }
    
    // MARK: - Template Categories Summary
    
    static var templatesByCategory: [TemplateCategory: [ProjectTemplate]] {
        Dictionary(grouping: allTemplates) { $0.category }
    }
    
    static func templates(for category: TemplateCategory) -> [ProjectTemplate] {
        return allTemplates.filter { $0.category == category }
    }
    
    static func searchTemplates(query: String) -> [ProjectTemplate] {
        let lowercaseQuery = query.lowercased()
        return allTemplates.filter { template in
            template.name.lowercased().contains(lowercaseQuery) ||
            template.description?.lowercased().contains(lowercaseQuery) == true ||
            template.metadata.tags.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
}