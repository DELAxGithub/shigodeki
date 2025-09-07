//
//  WebApiPhaseBuilder.swift
//  shigodeki
//
//  Extracted from WebApiTemplateService.swift on 2025-09-07.
//  Web API development phase generation builder
//

import Foundation

struct WebApiPhaseBuilder {
    
    // MARK: - Phase Creation
    
    static func createDesignPhase() -> PhaseTemplate {
        PhaseTemplate(
            title: "API設計",
            description: "エンドポイントとデータ構造の設計",
            order: 0,
            estimatedDuration: "2-3週間",
            taskLists: [
                WebApiTaskListBuilder.createApiDesignTaskList(),
                WebApiTaskListBuilder.createDataModelTaskList()
            ]
        )
    }
    
    static func createDevelopmentPhase() -> PhaseTemplate {
        PhaseTemplate(
            title: "実装・開発",
            description: "APIサーバーの実装とデータベース構築",
            order: 1,
            prerequisites: ["API設計"],
            estimatedDuration: "4-6週間",
            taskLists: [
                WebApiTaskListBuilder.createServerImplementationTaskList(),
                WebApiTaskListBuilder.createDatabaseTaskList(),
                WebApiTaskListBuilder.createAuthenticationTaskList()
            ]
        )
    }
    
    static func createTestingPhase() -> PhaseTemplate {
        PhaseTemplate(
            title: "テスト・品質保証",
            description: "APIテストとセキュリティ検証",
            order: 2,
            prerequisites: ["実装・開発"],
            estimatedDuration: "2-3週間",
            taskLists: [
                WebApiTaskListBuilder.createApiTestingTaskList(),
                WebApiTaskListBuilder.createSecurityTestTaskList()
            ]
        )
    }
    
    static func createDeploymentPhase() -> PhaseTemplate {
        PhaseTemplate(
            title: "デプロイ・運用",
            description: "本番環境への展開と監視設定",
            order: 3,
            prerequisites: ["テスト・品質保証"],
            estimatedDuration: "1-2週間",
            taskLists: [
                WebApiTaskListBuilder.createDeploymentTaskList(),
                WebApiTaskListBuilder.createMonitoringTaskList()
            ]
        )
    }
}