//
//  EducationTemplates.swift
//  shigodeki
//
//  Extracted from BuiltInTemplates.swift for better code organization
//  Contains learning and skill development templates
//

import Foundation

/// Education Templates - Language Learning, Skill Development
class EducationTemplates {
    
    static var allTemplates: [ProjectTemplate] {
        return [
            languageLearningTemplate,
            skillDevelopmentTemplate
        ]
    }
    
    // MARK: - Language Learning Template
    
    static var languageLearningTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "言語学習プログラム",
            description: "効果的な外国語習得のための学習テンプレート",
            category: TemplateCategory.personal,
            phases: [
                PhaseTemplate(
                    title: "学習準備",
                    description: "学習計画の立案と基礎準備",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "準備",
                            tasks: [
                                TaskTemplate(
                                    title: "学習目標設定",
                                    priority: .high,
                                    tags: ["学習", "目標"]
                                ),
                                TaskTemplate(
                                    title: "学習スケジュール作成",
                                    priority: .high,
                                    tags: ["スケジュール", "計画"]
                                ),
                                TaskTemplate(
                                    title: "学習教材選定",
                                    priority: .medium,
                                    tags: ["教材", "選定"]
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
    
    // MARK: - Skill Development Template
    
    static var skillDevelopmentTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "スキル習得プロジェクト",
            description: "新しいスキルや技術を効率的に習得するためのテンプレート",
            category: TemplateCategory.personal,
            phases: [
                PhaseTemplate(
                    title: "学習計画",
                    description: "スキル習得の戦略立案",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "計画立案",
                            tasks: [
                                TaskTemplate(
                                    title: "習得スキル明確化",
                                    priority: .high,
                                    tags: ["スキル", "明確化"]
                                ),
                                TaskTemplate(
                                    title: "学習ロードマップ作成",
                                    priority: .high,
                                    tags: ["ロードマップ", "計画"]
                                ),
                                TaskTemplate(
                                    title: "実践プロジェクト企画",
                                    priority: .medium,
                                    tags: ["実践", "プロジェクト"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .intermediate,
                tags: ["skill", "development", "learning"]
            )
        )
    }
}