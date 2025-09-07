//
//  WebApiTemplateService.swift
//  shigodeki
//
//  Extracted from SoftwareDevTemplates.swift for CLAUDE.md compliance
//  Web API development template generation service
//

import Foundation

@MainActor
class WebApiTemplateService {
    
    static func generateWebApiTemplate() -> ProjectTemplate {
        return ProjectTemplate(
            name: "Web API開発",
            description: "RESTful APIの設計から実装まで",
            goal: "スケーラブルで安全なWeb APIサービスの構築",
            category: TemplateCategory.softwareDevelopment,
            version: "1.0",
            phases: [
                WebApiPhaseBuilder.createDesignPhase(),
                WebApiPhaseBuilder.createDevelopmentPhase(),
                WebApiPhaseBuilder.createTestingPhase(),
                WebApiPhaseBuilder.createDeploymentPhase()
            ],
            metadata: TemplateMetadata(
                author: "Shigodeki Template Library",
                difficulty: .advanced,
                tags: ["API", "backend", "REST", "microservices"],
                requiredSkills: ["サーバーサイド開発", "データベース設計", "API設計"],
                targetAudience: "中級者〜上級者のバックエンド開発者"
            )
        )
    }
}