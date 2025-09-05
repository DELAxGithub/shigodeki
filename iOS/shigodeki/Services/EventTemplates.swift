//
//  EventTemplates.swift
//  shigodeki
//
//  Extracted from BuiltInTemplates.swift for better code organization
//  Contains event planning templates
//

import Foundation

/// Event Templates - Conference, Wedding, and Special Events
class EventTemplates {
    
    static var allTemplates: [ProjectTemplate] {
        return [
            conferenceTemplate,
            weddingPlanningTemplate
        ]
    }
    
    // MARK: - Conference Template
    
    static var conferenceTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "カンファレンス開催",
            description: "技術カンファレンスやビジネスイベントの企画・運営テンプレート",
            category: TemplateCategory.eventPlanning,
            phases: [
                PhaseTemplate(
                    title: "企画・準備",
                    description: "イベントの企画と基本準備",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "企画",
                            tasks: [
                                TaskTemplate(
                                    title: "イベント概要決定",
                                    priority: .high,
                                    tags: ["企画", "イベント"]
                                ),
                                TaskTemplate(
                                    title: "会場選定・予約",
                                    priority: .high,
                                    tags: ["会場", "予約"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .advanced,
                tags: ["conference", "event", "planning"]
            )
        )
    }
    
    // MARK: - Wedding Planning Template
    
    static var weddingPlanningTemplate: ProjectTemplate {
        ProjectTemplate(
            name: "結婚式準備",
            description: "理想の結婚式を実現するための包括的な準備テンプレート",
            category: TemplateCategory.eventPlanning,
            phases: [
                PhaseTemplate(
                    title: "基本準備",
                    description: "結婚式の基本プランニング",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "プランニング",
                            tasks: [
                                TaskTemplate(
                                    title: "結婚式スタイル決定",
                                    priority: .high,
                                    tags: ["プランニング", "スタイル"]
                                ),
                                TaskTemplate(
                                    title: "予算設定",
                                    priority: .high,
                                    tags: ["予算", "計画"]
                                ),
                                TaskTemplate(
                                    title: "会場選定・見学",
                                    priority: .high,
                                    tags: ["会場", "見学"]
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .intermediate,
                tags: ["wedding", "planning", "event"]
            )
        )
    }
}