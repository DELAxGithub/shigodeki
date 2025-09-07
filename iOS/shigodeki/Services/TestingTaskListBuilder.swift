//
//  TestingTaskListBuilder.swift
//  shigodeki
//
//  Created from MobileAppTaskListBuilder split for CLAUDE.md compliance
//  Testing and performance task list builder
//

import Foundation

@MainActor
struct TestingTaskListBuilder {
    
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
}