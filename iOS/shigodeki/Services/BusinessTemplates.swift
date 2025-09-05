//
//  BusinessTemplates.swift
//  shigodeki
//
//  Extracted from BuiltInTemplates.swift for better code organization
//  Contains business and project management templates
//

import Foundation

/// Business Templates - Product Launch, Team Management, Marketing
class BusinessTemplates {
    
    static var allTemplates: [ProjectTemplate] {
        return [
            productLaunchTemplate,
            teamOnboardingTemplate,
            startupLaunchTemplate,
            marketingCampaignTemplate
        ]
    }
    
    // MARK: - Product Launch Template
    
    static var productLaunchTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "新商品・サービスローンチ",
            description: "新商品やサービスの市場投入を成功させるための包括的なテンプレート",
            goal: "ターゲット市場での認知度向上と売上目標達成",
            category: TemplateCategory.projectManagement,
            phases: [
                PhaseTemplate(
                    title: "市場調査・戦略立案",
                    description: "市場分析と戦略の策定",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "市場調査",
                            tasks: [
                                TaskTemplate(
                                    title: "競合分析",
                                    description: "競合他社の商品・サービス分析",
                                    priority: .high,
                                    tags: ["市場調査", "競合分析"]
                                ),
                                TaskTemplate(
                                    title: "ターゲット顧客分析",
                                    description: "ペルソナ設定と顧客ニーズ分析",
                                    priority: .high,
                                    tags: ["顧客分析", "ペルソナ"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .intermediate,
                tags: ["business", "product", "launch", "marketing"]
            )
        )
    }
    
    // MARK: - Team Onboarding Template
    
    static var teamOnboardingTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "チーム新人研修プログラム",
            description: "新メンバーの円滑な組織統合を支援する研修テンプレート",
            category: TemplateCategory.projectManagement,
            phases: [
                PhaseTemplate(
                    title: "準備フェーズ",
                    description: "新人受け入れの準備",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "環境準備",
                            tasks: [
                                TaskTemplate(
                                    title: "ワークスペース準備",
                                    priority: .high,
                                    tags: ["準備", "環境"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .beginner,
                tags: ["team", "onboarding", "training"]
            )
        )
    }
    
    // MARK: - Startup Launch Template
    
    static var startupLaunchTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "スタートアップ立ち上げ",
            description: "新しいビジネスを立ち上げるためのテンプレート",
            category: TemplateCategory.projectManagement,
            phases: [
                PhaseTemplate(
                    title: "事業計画",
                    description: "ビジネスプランの作成",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "プランニング",
                            tasks: [
                                TaskTemplate(
                                    title: "事業計画書作成",
                                    priority: .high,
                                    tags: ["計画", "ビジネス"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .advanced,
                tags: ["startup", "business", "planning"]
            )
        )
    }
    
    // MARK: - Marketing Campaign Template
    
    static var marketingCampaignTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "マーケティングキャンペーン",
            description: "効果的なマーケティングキャンペーンの企画・実行テンプレート",
            category: TemplateCategory.projectManagement,
            phases: [
                PhaseTemplate(
                    title: "キャンペーン企画",
                    description: "キャンペーンの戦略策定",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "戦略立案",
                            tasks: [
                                TaskTemplate(
                                    title: "キャンペーン目標設定",
                                    priority: .high,
                                    tags: ["企画", "目標"]
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
}