//
//  MobileAppTemplateService.swift
//  shigodeki
//
//  Extracted from SoftwareDevTemplates.swift for CLAUDE.md compliance
//  Mobile app development template generation service
//

import Foundation

@MainActor
class MobileAppTemplateService {
    
    static func generateMobileAppTemplate() -> ProjectTemplate {
        return ProjectTemplate(
            name: "モバイルアプリ開発",
            description: "iOS/Androidアプリを最初から最後まで開発するためのテンプレート",
            goal: "App StoreとGoogle Playでの公開",
            category: TemplateCategory.softwareDevelopment,
            phases: [
                createPlanningPhase(),
                createDesignPhase(),
                createDevelopmentPhase(),
                createTestingPhase(),
                createPublishingPhase()
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .advanced,
                tags: ["mobile", "iOS", "Android", "app"],
                requiredSkills: ["Swift/Kotlin", "UI/UXデザイン", "アプリストア公開"],
                targetAudience: "中級者〜上級者のアプリ開発者"
            )
        )
    }
    
    // MARK: - Phase Creation
    
    private static func createPlanningPhase() -> PhaseTemplate {
        PhaseTemplate(
            title: "企画・プロトタイプ",
            description: "アプリの企画とプロトタイプ作成",
            order: 0,
            estimatedDuration: "2-3週間",
            taskLists: [
                MobileAppTaskListBuilder.createAppPlanningTaskList(),
                MobileAppTaskListBuilder.createMarketResearchTaskList()
            ]
        )
    }
    
    private static func createDesignPhase() -> PhaseTemplate {
        PhaseTemplate(
            title: "UI/UXデザイン",
            description: "ユーザーインターフェースの設計",
            order: 1,
            prerequisites: ["企画・プロトタイプ"],
            estimatedDuration: "3-4週間",
            taskLists: [
                MobileAppTaskListBuilder.createDesignTaskList(),
                MobileAppTaskListBuilder.createPrototypeTaskList()
            ]
        )
    }
    
    private static func createDevelopmentPhase() -> PhaseTemplate {
        PhaseTemplate(
            title: "開発・実装",
            description: "アプリの実装とテスト",
            order: 2,
            prerequisites: ["UI/UXデザイン"],
            estimatedDuration: "6-8週間",
            taskLists: [
                MobileAppTaskListBuilder.createiOSDevelopmentTaskList(),
                MobileAppTaskListBuilder.createAndroidDevelopmentTaskList(),
                MobileAppTaskListBuilder.createBackendIntegrationTaskList()
            ]
        )
    }
    
    private static func createTestingPhase() -> PhaseTemplate {
        PhaseTemplate(
            title: "テスト・品質保証",
            description: "包括的なテストと品質確認",
            order: 3,
            prerequisites: ["開発・実装"],
            estimatedDuration: "2-3週間",
            taskLists: [
                MobileAppTaskListBuilder.createTestingTaskList(),
                MobileAppTaskListBuilder.createPerformanceTestTaskList()
            ]
        )
    }
    
    private static func createPublishingPhase() -> PhaseTemplate {
        PhaseTemplate(
            title: "公開・リリース",
            description: "アプリストアでの公開準備とリリース",
            order: 4,
            prerequisites: ["テスト・品質保証"],
            estimatedDuration: "1-2週間",
            taskLists: [
                MobileAppTaskListBuilder.createAppStoreTaskList(),
                MobileAppTaskListBuilder.createMarketingTaskList()
            ]
        )
    }
}