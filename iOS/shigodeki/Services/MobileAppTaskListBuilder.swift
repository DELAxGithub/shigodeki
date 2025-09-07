//
//  MobileAppTaskListBuilder.swift
//  shigodeki
//
//  Created from MobileAppTemplateService split for CLAUDE.md compliance
//  Mobile app template task list builder orchestrator
//

import Foundation

@MainActor
struct MobileAppTaskListBuilder {
    
    // MARK: - Task List Creation (Delegating to specialized builders)
    
    static func createAppPlanningTaskList() -> TaskListTemplate {
        AppPlanningTaskListBuilder.createAppPlanningTaskList()
    }
    
    static func createMarketResearchTaskList() -> TaskListTemplate {
        AppPlanningTaskListBuilder.createMarketResearchTaskList()
    }
    
    static func createDesignTaskList() -> TaskListTemplate {
        DesignTaskListBuilder.createDesignTaskList()
    }
    
    static func createPrototypeTaskList() -> TaskListTemplate {
        DesignTaskListBuilder.createPrototypeTaskList()
    }
    
    static func createiOSDevelopmentTaskList() -> TaskListTemplate {
        DevelopmentTaskListBuilder.createiOSDevelopmentTaskList()
    }
    
    static func createAndroidDevelopmentTaskList() -> TaskListTemplate {
        DevelopmentTaskListBuilder.createAndroidDevelopmentTaskList()
    }
    
    static func createBackendIntegrationTaskList() -> TaskListTemplate {
        DevelopmentTaskListBuilder.createBackendIntegrationTaskList()
    }
    
    static func createTestingTaskList() -> TaskListTemplate {
        TestingTaskListBuilder.createTestingTaskList()
    }
    
    static func createPerformanceTestTaskList() -> TaskListTemplate {
        TestingTaskListBuilder.createPerformanceTestTaskList()
    }
    
    static func createAppStoreTaskList() -> TaskListTemplate {
        PublishingTaskListBuilder.createAppStoreTaskList()
    }
    
    static func createMarketingTaskList() -> TaskListTemplate {
        PublishingTaskListBuilder.createMarketingTaskList()
    }
}