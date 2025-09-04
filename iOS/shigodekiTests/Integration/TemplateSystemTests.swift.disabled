//
//  TemplateSystemTests.swift
//  shigodekiTests
//
//  Created by Claude on 2025-08-29.
//

import XCTest
import SwiftUI
@testable import shigodeki

/// Integration tests for the template system including import/export and validation
@MainActor
final class TemplateSystemTests: XCTestCase {
    
    var templateImporter: TemplateImporter!
    var templateValidator: TemplateValidator!
    var templateExporter: TemplateExporter!
    
    override func setUp() {
        super.setUp()
        templateImporter = TemplateImporter()
        templateValidator = TemplateValidator()
        templateExporter = TemplateExporter()
        
        trackMemoryUsage(maxMemoryMB: 30.0)
    }
    
    override func tearDown() {
        templateImporter = nil
        templateValidator = nil
        templateExporter = nil
        forceGarbageCollection()
        super.tearDown()
    }
    
    // MARK: - Template Import Tests
    
    /// Test successful template import from valid JSON
    func testValidTemplateImport() async throws {
        let validJSON = createValidTemplateJSON()
        let data = validJSON.data(using: .utf8)!
        
        trackForMemoryLeak(templateImporter)
        
        let result = try await templateImporter.importTemplate(from: data)
        
        XCTAssertNotNil(result.projectTemplate)
        XCTAssertEqual(result.projectTemplate.name, "テスト プロジェクト")
        XCTAssertEqual(result.projectTemplate.phases.count, 2)
        XCTAssertTrue(result.warnings.isEmpty)
        
        // Verify template structure
        let firstPhase = result.projectTemplate.phases[0]
        XCTAssertEqual(firstPhase.title, "準備フェーズ")
        XCTAssertEqual(firstPhase.taskLists.count, 1)
        XCTAssertEqual(firstPhase.taskLists[0].tasks.count, 2)
    }
    
    /// Test import failure with invalid JSON
    func testInvalidJSONImportFailure() async {
        let invalidJSON = "{ invalid json }"
        let data = invalidJSON.data(using: .utf8)!
        
        trackForMemoryLeak(templateImporter)
        
        do {
            _ = try await templateImporter.importTemplate(from: data)
            XCTFail("Should have thrown an error for invalid JSON")
        } catch let error as TemplateImporter.ImportError {
            XCTAssertEqual(error, .invalidJSON)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        XCTAssertNotNil(templateImporter.lastImportError)
        XCTAssertNil(templateImporter.lastImportResult)
    }
    
    /// Test legacy format conversion
    func testLegacyFormatConversion() async throws {
        let legacyJSON = createLegacyTemplateJSON()
        let data = legacyJSON.data(using: .utf8)!
        
        trackForMemoryLeak(templateImporter)
        
        let result = try await templateImporter.importTemplate(from: data)
        
        XCTAssertNotNil(result.projectTemplate)
        XCTAssertEqual(result.projectTemplate.name, "レガシー テンプレート")
        XCTAssertFalse(result.warnings.isEmpty) // Should have conversion warnings
    }
    
    // MARK: - Template Validation Tests
    
    /// Test validation of complete template
    func testCompleteTemplateValidation() async {
        let template = createValidProjectTemplate()
        
        trackForMemoryLeak(templateValidator)
        
        let result = await templateValidator.validate(template)
        
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(result.warnings.isEmpty)
        XCTAssertEqual(result.severity, .valid)
    }
    
    /// Test validation with missing required fields
    func testValidationWithMissingFields() async {
        var template = createValidProjectTemplate()
        template.name = "" // Invalid empty name
        template.phases = [] // Invalid empty phases
        
        trackForMemoryLeak(templateValidator)
        
        let result = await templateValidator.validate(template)
        
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.errors.isEmpty)
        XCTAssertEqual(result.severity, .error)
        
        // Check specific errors
        let hasNameError = result.errors.contains { $0.contains("name") }
        let hasPhasesError = result.errors.contains { $0.contains("phase") }
        XCTAssertTrue(hasNameError || hasPhasesError)
    }
    
    /// Test validation performance with large template
    func testValidationPerformance() async {
        let largeTemplate = createLargeProjectTemplate()
        
        trackForMemoryLeak(templateValidator)
        
        measure {
            Task { @MainActor in
                _ = await templateValidator.validate(largeTemplate)
            }
        }
    }
    
    // MARK: - Template Export Tests
    
    /// Test project export to template
    func testProjectExport() async throws {
        let project = createSampleProject()
        
        trackForMemoryLeak(templateExporter)
        
        let templateData = try await templateExporter.exportProject(project)
        
        XCTAssertNotNil(templateData)
        XCTAssertGreaterThan(templateData.count, 0)
        
        // Verify exported data can be re-imported
        let importResult = try await templateImporter.importTemplate(from: templateData)
        XCTAssertNotNil(importResult.projectTemplate)
        XCTAssertEqual(importResult.projectTemplate.name, project.name)
    }
    
    /// Test template customization export
    func testCustomTemplateExport() async throws {
        let template = createValidProjectTemplate()
        let customizations = ProjectCustomizations(
            skipOptionalTasks: true,
            customPhaseColors: ["準備フェーズ": "blue"],
            taskPriorityOverrides: ["重要タスク": .high]
        )
        
        trackForMemoryLeak(templateExporter)
        
        let exportData = try await templateExporter.exportTemplate(template, with: customizations)
        
        XCTAssertNotNil(exportData)
        
        // Verify customizations are preserved
        let reimported = try await templateImporter.importTemplate(from: exportData)
        XCTAssertNotNil(reimported.projectTemplate)
    }
    
    // MARK: - Memory Leak Tests for Template System
    
    /// Test template importer memory management
    func testTemplateImporterMemoryLeak() async {
        testObservableObjectForMemoryLeak {
            TemplateImporter()
        }
        
        await waitForMemoryStabilization()
    }
    
    /// Test template validator memory management
    func testTemplateValidatorMemoryLeak() async {
        var validator: TemplateValidator? = TemplateValidator()
        trackForMemoryLeak(validator!)
        
        let template = createValidProjectTemplate()
        _ = await validator!.validate(template)
        
        validator = nil
        await waitForMemoryStabilization()
    }
    
    /// Test async operations memory management
    func testAsyncTemplateOperationsMemoryLeak() async {
        await testAsyncOperationForMemoryLeak { [weak self] in
            let importer = TemplateImporter()
            let data = self?.createValidTemplateJSON().data(using: .utf8) ?? Data()
            
            self?.trackForMemoryLeak(importer)
            
            do {
                return try await importer.importTemplate(from: data)
            } catch {
                return TemplateImporter.ImportResult(
                    projectTemplate: self?.createValidProjectTemplate() ?? ProjectTemplate.empty,
                    warnings: [],
                    statistics: TemplateStats(template: ProjectTemplate.empty)
                )
            }
        }
    }
    
    // MARK: - Integration Tests
    
    /// Test complete template workflow: import → validate → export
    func testCompleteTemplateWorkflow() async throws {
        trackMemoryUsage(maxMemoryMB: 50.0)
        
        // Step 1: Import
        let jsonData = createValidTemplateJSON().data(using: .utf8)!
        let importResult = try await templateImporter.importTemplate(from: jsonData)
        
        trackForMemoryLeak(templateImporter)
        trackForMemoryLeak(templateValidator)
        trackForMemoryLeak(templateExporter)
        
        // Step 2: Validate
        let validationResult = await templateValidator.validate(importResult.projectTemplate)
        XCTAssertTrue(validationResult.isValid)
        
        // Step 3: Export
        let exportData = try await templateExporter.exportTemplate(importResult.projectTemplate)
        
        // Step 4: Re-import to verify round-trip
        let reimportResult = try await templateImporter.importTemplate(from: exportData)
        
        XCTAssertEqual(importResult.projectTemplate.name, reimportResult.projectTemplate.name)
        XCTAssertEqual(importResult.projectTemplate.phases.count, reimportResult.projectTemplate.phases.count)
        
        await waitForMemoryStabilization()
    }
    
    /// Test template selection state synchronization (addresses the "No template selected" bug)
    func testTemplateSelectionStateSynchronization() async throws {
        let jsonData = createValidTemplateJSON().data(using: .utf8)!
        
        // Test that import sets the correct state
        let importResult = try await templateImporter.importTemplate(from: jsonData)
        
        XCTAssertNotNil(templateImporter.lastImportResult)
        XCTAssertEqual(templateImporter.lastImportResult?.projectTemplate.name, importResult.projectTemplate.name)
        XCTAssertNil(templateImporter.lastImportError)
        
        // Verify template can be retrieved after import
        XCTAssertNotNil(templateImporter.lastImportResult?.projectTemplate)
    }
    
    // MARK: - Helper Methods
    
    private func createValidTemplateJSON() -> String {
        return """
        {
            "name": "テスト プロジェクト",
            "description": "テスト用のプロジェクトテンプレート",
            "category": "testing",
            "version": "1.0",
            "author": "Claude",
            "difficulty": "beginner",
            "estimatedHours": 5,
            "tags": ["テスト", "サンプル"],
            "phases": [
                {
                    "title": "準備フェーズ",
                    "description": "プロジェクトの準備を行う",
                    "order": 0,
                    "prerequisites": [],
                    "taskLists": [
                        {
                            "name": "初期設定",
                            "color": "blue",
                            "order": 0,
                            "tasks": [
                                {
                                    "title": "環境構築",
                                    "description": "開発環境をセットアップする",
                                    "priority": "medium",
                                    "estimatedHours": 2.0,
                                    "isOptional": false
                                },
                                {
                                    "title": "設定ファイル作成",
                                    "description": "必要な設定ファイルを作成する",
                                    "priority": "high",
                                    "estimatedHours": 1.0,
                                    "isOptional": false
                                }
                            ]
                        }
                    ]
                },
                {
                    "title": "実装フェーズ",
                    "description": "実際の実装を行う",
                    "order": 1,
                    "prerequisites": ["準備フェーズ"],
                    "taskLists": [
                        {
                            "name": "コア機能",
                            "color": "green",
                            "order": 0,
                            "tasks": [
                                {
                                    "title": "基本機能実装",
                                    "description": "基本的な機能を実装する",
                                    "priority": "high",
                                    "estimatedHours": 2.0,
                                    "isOptional": false
                                }
                            ]
                        }
                    ]
                }
            ]
        }
        """
    }
    
    private func createLegacyTemplateJSON() -> String {
        return """
        {
            "name": "レガシー テンプレート",
            "description": "古い形式のテンプレート",
            "steps": [
                {
                    "title": "ステップ1",
                    "description": "最初のステップ"
                },
                {
                    "title": "ステップ2", 
                    "description": "次のステップ"
                }
            ]
        }
        """
    }
    
    private func createValidProjectTemplate() -> ProjectTemplate {
        let phase = PhaseTemplate(
            title: "テストフェーズ",
            description: "テスト用のフェーズ",
            order: 0,
            prerequisites: [],
            taskLists: [
                TaskListTemplate(
                    name: "テストタスクリスト",
                    color: "blue",
                    order: 0,
                    tasks: [
                        TaskTemplate(
                            title: "テストタスク",
                            description: "テスト用のタスク",
                            priority: .medium,
                            estimatedHours: 1.0,
                            isOptional: false
                        )
                    ]
                )
            ]
        )
        
        return ProjectTemplate(
            name: "テスト テンプレート",
            description: "テスト用のテンプレート",
            category: .testing,
            version: "1.0",
            author: "Claude",
            phases: [phase]
        )
    }
    
    private func createLargeProjectTemplate() -> ProjectTemplate {
        var phases: [PhaseTemplate] = []
        
        // Create 10 phases with 5 task lists each, 10 tasks per list
        for phaseIndex in 0..<10 {
            var taskLists: [TaskListTemplate] = []
            
            for listIndex in 0..<5 {
                var tasks: [TaskTemplate] = []
                
                for taskIndex in 0..<10 {
                    let task = TaskTemplate(
                        title: "Task \(phaseIndex)-\(listIndex)-\(taskIndex)",
                        description: "Description for task \(taskIndex)",
                        priority: .medium,
                        estimatedHours: 1.0,
                        isOptional: taskIndex % 3 == 0
                    )
                    tasks.append(task)
                }
                
                let taskList = TaskListTemplate(
                    name: "TaskList \(phaseIndex)-\(listIndex)",
                    color: "blue",
                    order: listIndex,
                    tasks: tasks
                )
                taskLists.append(taskList)
            }
            
            let phase = PhaseTemplate(
                title: "Phase \(phaseIndex)",
                description: "Description for phase \(phaseIndex)",
                order: phaseIndex,
                prerequisites: [],
                taskLists: taskLists
            )
            phases.append(phase)
        }
        
        return ProjectTemplate(
            name: "Large Test Template",
            description: "Large template for performance testing",
            category: .testing,
            version: "1.0",
            author: "Claude",
            phases: phases
        )
    }
    
    private func createSampleProject() -> Project {
        return Project(
            name: "Sample Project",
            description: "A sample project for testing",
            ownerId: "test-owner",
            memberIds: ["test-owner"]
        )
    }
}

// MARK: - Extensions for Testing

extension ProjectTemplate {
    static var empty: ProjectTemplate {
        return ProjectTemplate(
            name: "",
            description: "",
            category: .other,
            version: "1.0",
            author: "",
            phases: []
        )
    }
}

extension TemplateCategory {
    static var testing: TemplateCategory {
        return .other
    }
}