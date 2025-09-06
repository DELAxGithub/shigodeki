//
//  SoftwareDevTemplates.swift
//  shigodeki
//
//  Refactored for CLAUDE.md compliance - Lightweight coordinator
//  Template generation services extracted to individual files
//

import Foundation

@MainActor
class SoftwareDevTemplates {
    
    // MARK: - Template Collection
    
    static var allTemplates: [ProjectTemplate] {
        return [
            sampleWebsiteTemplate,
            mobileAppTemplate,
            webApiTemplate
        ]
    }
    
    // MARK: - Template Accessors
    
    static var sampleWebsiteTemplate: ProjectTemplate {
        return WebsiteTemplateService.generateWebsiteTemplate()
    }
    
    static var mobileAppTemplate: ProjectTemplate {
        return MobileAppTemplateService.generateMobileAppTemplate()
    }
    
    static var webApiTemplate: ProjectTemplate {
        return WebApiTemplateService.generateWebApiTemplate()
    }
    
    // MARK: - Template Management
    
    static func getTemplate(by name: String) -> ProjectTemplate? {
        return allTemplates.first { $0.name == name }
    }
    
    static func getTemplatesByDifficulty(_ difficulty: TemplateDifficulty) -> [ProjectTemplate] {
        return allTemplates.filter { $0.metadata.difficulty == difficulty }
    }
    
    static func getTemplatesByTag(_ tag: String) -> [ProjectTemplate] {
        return allTemplates.filter { $0.metadata.tags.contains(tag) }
    }
}