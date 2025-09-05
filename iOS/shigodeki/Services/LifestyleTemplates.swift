//
//  LifestyleTemplates.swift
//  shigodeki
//
//  Extracted from BuiltInTemplates.swift for better code organization
//  Contains personal and lifestyle templates
//

import Foundation

/// Lifestyle Templates - Personal Goals, Health, Travel, Home
class LifestyleTemplates {
    
    static var allTemplates: [ProjectTemplate] {
        return [
            movingTemplate,
            homeRenovationTemplate,
            healthGoalsTemplate,
            travelPlanningTemplate
        ]
    }
    
    // MARK: - Moving Template
    
    static var movingTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "引っ越しプロジェクト",
            description: "スムーズな引っ越しを実現するための準備テンプレート",
            category: TemplateCategory.personal,
            phases: [
                PhaseTemplate(
                    title: "準備フェーズ",
                    description: "引っ越しの基本準備",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "事前準備",
                            tasks: [
                                TaskTemplate(
                                    title: "引っ越し業者選定",
                                    priority: .high,
                                    tags: ["準備", "業者"]
                                ),
                                TaskTemplate(
                                    title: "住所変更手続きリスト作成",
                                    priority: .medium,
                                    tags: ["手続き", "リスト"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .intermediate,
                tags: ["moving", "personal", "planning"]
            )
        )
    }
    
    // MARK: - Home Renovation Template
    
    static var homeRenovationTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "住宅リフォーム・リノベーション",
            description: "住まいの改修を成功させるためのテンプレート",
            category: TemplateCategory.personal,
            phases: [
                PhaseTemplate(
                    title: "計画・設計",
                    description: "リフォームの計画策定",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "プランニング",
                            tasks: [
                                TaskTemplate(
                                    title: "リフォーム範囲決定",
                                    priority: .high,
                                    tags: ["計画", "範囲"]
                                ),
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
                difficulty: .advanced,
                tags: ["home", "renovation", "planning"]
            )
        )
    }
    
    // MARK: - Health Goals Template
    
    static var healthGoalsTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "健康目標達成プログラム",
            description: "健康的な生活習慣の確立と目標達成をサポート",
            category: TemplateCategory.personal,
            phases: [
                PhaseTemplate(
                    title: "現状分析・目標設定",
                    description: "健康状態の把握と目標設定",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "分析・設定",
                            tasks: [
                                TaskTemplate(
                                    title: "健康状態チェック",
                                    priority: .high,
                                    tags: ["健康", "チェック"]
                                ),
                                TaskTemplate(
                                    title: "具体的目標設定",
                                    priority: .high,
                                    tags: ["目標", "設定"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .beginner,
                tags: ["health", "personal", "goals"]
            )
        )
    }
    
    // MARK: - Travel Planning Template
    
    static var travelPlanningTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "旅行計画プロジェクト",
            description: "忘れられない旅行を実現するための包括的な計画テンプレート",
            category: TemplateCategory.personal,
            phases: [
                PhaseTemplate(
                    title: "旅行企画",
                    description: "旅行の基本計画立案",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "基本計画",
                            tasks: [
                                TaskTemplate(
                                    title: "目的地決定",
                                    priority: .high,
                                    tags: ["計画", "目的地"]
                                ),
                                TaskTemplate(
                                    title: "予算設定",
                                    priority: .high,
                                    tags: ["予算", "計画"]
                                ),
                                TaskTemplate(
                                    title: "日程調整",
                                    priority: .high,
                                    tags: ["日程", "スケジュール"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .beginner,
                tags: ["travel", "planning", "personal"]
            )
        )
    }
}