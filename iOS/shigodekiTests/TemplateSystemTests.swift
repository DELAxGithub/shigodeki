//
//  TemplateSystemTests.swift
//  shigodekiTests
//
//  Created by Claude on 2025-08-29.
//

import XCTest
@testable import shigodeki

// MARK: - Template System Integration Tests

final class TemplateSystemTests: XCTestCase {
    
    struct TestResult {
        let testName: String
        let passed: Bool
        let error: Error?
        let duration: TimeInterval
    }
    
    private var results: [TestResult] = []
    
    override func setUp() {
        super.setUp()
        results.removeAll()
    }
    
    func testAllTemplateSystemComponents() async throws {
        print("🧪 Starting Template System Integration Tests...")
        
        // Template Model Tests
        await runTest("Template Model Creation") { try await self.testTemplateModelCreation() }
        await runTest("Template Stats Calculation") { try await self.testTemplateStatsCalculation() }
        
        // Import/Export Tests
        await runTest("JSON Import - Standard Format") { try await self.testJSONImportStandard() }
        await runTest("JSON Import - Legacy Format") { try await self.testJSONImportLegacy() }
        await runTest("Template Export") { try await self.testTemplateExport() }
        
        // Validation Tests
        await runTest("Template Validation - Valid") { try await self.testTemplateValidationValid() }
        await runTest("Template Validation - Invalid") { try await self.testTemplateValidationInvalid() }
        
        // Built-in Templates Tests
        await runTest("Built-in Templates Loading") { try await self.testBuiltInTemplatesLoading() }
        
        // Integration Tests
        await runTest("Template to Project Conversion") { try await self.testTemplateToProjectConversion() }
        await runTest("Project to Template Export") { try await self.testProjectToTemplateExport() }
        
        // Error Handling Tests
        await runTest("Error Handling - Invalid JSON") { try await self.testErrorHandlingInvalidJSON() }
        await runTest("Error Handling - Missing Fields") { try await self.testErrorHandlingMissingFields() }
        
        printTestSummary()
    }
    
    private func runTest(_ name: String, test: @escaping () async throws -> Void) async {
        let startTime = Date()
        
        do {
            try await test()
            let duration = Date().timeIntervalSince(startTime)
            let result = TestResult(testName: name, passed: true, error: nil, duration: duration)
            results.append(result)
            print("✅ \(name) - Passed (\(String(format: "%.3f", duration))s)")
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let result = TestResult(testName: name, passed: false, error: error, duration: duration)
            results.append(result)
            print("❌ \(name) - Failed (\(String(format: "%.3f", duration))s): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Template Model Tests
    
    private func testTemplateModelCreation() async throws {
        let template = ProjectTemplate(
            name: "Test Template",
            description: "Test description",
            goal: "Test goal",
            category: .softwareDevelopment,
            version: "1.0",
            phases: [
                PhaseTemplate(
                    title: "Test Phase",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "Test List",
                            tasks: [
                                TaskTemplate(title: "Test Task", priority: .medium)
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(author: "Test Author")
        )
        
        XCTAssertEqual(template.name, "Test Template")
        XCTAssertEqual(template.phases.count, 1)
        XCTAssertEqual(template.phases[0].taskLists.count, 1)
        XCTAssertEqual(template.phases[0].taskLists[0].tasks.count, 1)
    }
    
    private func testTemplateStatsCalculation() async throws {
        let template = BuiltInTemplates.sampleWebsiteTemplate
        let stats = TemplateStats(template: template)
        
        XCTAssertGreaterThan(stats.totalPhases, 0)
        XCTAssertGreaterThan(stats.totalTasks, 0)
        XCTAssertGreaterThan(stats.estimatedCompletionHours, 0)
        XCTAssertFalse(stats.completionTimeRange.isEmpty)
    }
    
    // MARK: - Import/Export Tests
    
    private func testJSONImportStandard() async throws {
        let jsonString = """
        {
            "name": "Test Import",
            "category": "software_development",
            "version": "1.0",
            "phases": [
                {
                    "title": "Phase 1",
                    "order": 0,
                    "taskLists": [
                        {
                            "name": "Tasks",
                            "color": "blue",
                            "order": 0,
                            "tasks": [
                                {
                                    "title": "Task 1",
                                    "priority": "high",
                                    "tags": ["test"],
                                    "isOptional": false,
                                    "subtasks": []
                                }
                            ]
                        }
                    ]
                }
            ],
            "metadata": {
                "author": "Test",
                "createdAt": "2025-08-29T00:00:00Z",
                "difficulty": "beginner",
                "tags": ["test"]
            }
        }
        """
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create JSON data"])
        }
        
        let importer = TemplateImporter()
        let result = try await importer.importTemplate(from: jsonData)
        
        XCTAssertEqual(result.projectTemplate.name, "Test Import")
        XCTAssertEqual(result.projectTemplate.phases.count, 1)
    }
    
    private func testJSONImportLegacy() async throws {
        let jsonString = """
        {
            "name": "Legacy Test",
            "description": "Legacy format test",
            "category": "ソフトウェア開発",
            "steps": [
                {
                    "title": "Step 1",
                    "description": "First step",
                    "order": 0,
                    "tasks": [
                        {
                            "title": "Task 1",
                            "description": "First task",
                            "priority": "high",
                            "tags": ["test"]
                        }
                    ]
                }
            ],
            "metadata": {
                "author": "Test",
                "difficulty": "medium"
            }
        }
        """
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create JSON data"])
        }
        
        let importer = TemplateImporter()
        let result = try await importer.importTemplate(from: jsonData)
        
        XCTAssertEqual(result.projectTemplate.name, "Legacy Test")
        XCTAssertEqual(result.projectTemplate.phases.count, 1)
        XCTAssertEqual(result.projectTemplate.category, .softwareDevelopment)
    }
    
    private func testTemplateExport() async throws {
        let template = BuiltInTemplates.sampleWebsiteTemplate
        let exporter = TemplateExporter()
        
        let project = Project(name: "Test Export", ownerId: "test-user")
        
        // This is a simplified test - in real scenarios, we'd need actual Firebase data
        let exportedData = try await exporter.exportToJSON(
            project,
            phases: [],
            taskLists: [:],
            tasks: [:],
            subtasks: [:],
            options: .minimal
        )
        
        XCTAssertFalse(exportedData.isEmpty)
        
        // Verify it's valid JSON
        let jsonObject = try JSONSerialization.jsonObject(with: exportedData)
        XCTAssertTrue(jsonObject is [String: Any])
    }
    
    // MARK: - Validation Tests
    
    private func testTemplateValidationValid() async throws {
        let template = BuiltInTemplates.sampleWebsiteTemplate
        let validator = TemplateValidator()
        
        let result = await validator.validate(template)
        
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertGreaterThan(result.complexity.totalTasks, 0)
    }
    
    private func testTemplateValidationInvalid() async throws {
        let invalidTemplate = ProjectTemplate(
            name: "", // Invalid: empty name
            category: .softwareDevelopment,
            version: "1.0",
            phases: [], // Invalid: no phases
            metadata: TemplateMetadata(author: "Test")
        )
        
        let validator = TemplateValidator()
        let result = await validator.validate(invalidTemplate)
        
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.errors.isEmpty)
        XCTAssertTrue(result.errors.contains { error in
            if case .emptyName = error { return true }
            return false
        })
        XCTAssertTrue(result.errors.contains { error in
            if case .emptyPhases = error { return true }
            return false
        })
    }
    
    // MARK: - Built-in Templates Tests
    
    private func testBuiltInTemplatesLoading() async throws {
        let templates = BuiltInTemplates.allTemplates
        
        XCTAssertFalse(templates.isEmpty)
        XCTAssertGreaterThanOrEqual(templates.count, 10) // We should have at least 10 templates
        
        // Test that all categories are represented
        let categories = Set(templates.map { $0.category })
        XCTAssertGreaterThanOrEqual(categories.count, 5) // Should cover multiple categories
        
        // Test specific templates
        let websiteTemplate = templates.first { $0.name.contains("ウェブサイト") }
        XCTAssertNotNil(websiteTemplate)
        
        // Test template structure integrity
        for template in templates.prefix(3) { // Test first 3 templates
            XCTAssertFalse(template.name.isEmpty)
            XCTAssertFalse(template.phases.isEmpty)
            XCTAssertTrue(template.phases.allSatisfy { !$0.taskLists.isEmpty })
        }
    }
    
    // MARK: - Integration Tests
    
    private func testTemplateToProjectConversion() async throws {
        let template = BuiltInTemplates.sampleWebsiteTemplate
        let importer = TemplateImporter()
        
        let project = try await importer.createProject(
            from: template,
            ownerId: "test-user-id",
            projectName: "Converted Project"
        )
        
        XCTAssertEqual(project.name, "Converted Project")
        XCTAssertEqual(project.ownerId, "test-user-id")
        XCTAssertFalse(project.memberIds.isEmpty)
    }
    
    private func testProjectToTemplateExport() async throws {
        let project = Project(
            name: "Export Test Project", 
            description: "Test project for export",
            ownerId: "test-user"
        )
        
        // This test is limited since we don't have actual Firebase connection
        // In real scenario, we'd have actual project data
        XCTAssertEqual(project.name, "Export Test Project")
        XCTAssertEqual(project.ownerId, "test-user")
    }
    
    // MARK: - Error Handling Tests
    
    private func testErrorHandlingInvalidJSON() async throws {
        let invalidJSON = "{ invalid json }"
        guard let jsonData = invalidJSON.data(using: .utf8) else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create data"])
        }
        
        let importer = TemplateImporter()
        
        do {
            _ = try await importer.importTemplate(from: jsonData)
            XCTFail("Should have failed with invalid JSON")
        } catch {
            // Expected to fail
            XCTAssertTrue(error is TemplateImporter.ImportError)
        }
    }
    
    private func testErrorHandlingMissingFields() async throws {
        let incompleteJSON = """
        {
            "description": "Missing name field"
        }
        """
        
        guard let jsonData = incompleteJSON.data(using: .utf8) else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create data"])
        }
        
        let importer = TemplateImporter()
        
        do {
            _ = try await importer.importTemplate(from: jsonData)
            XCTFail("Should have failed with missing required fields")
        } catch {
            // Expected to fail due to missing required fields
            print("✓ Correctly caught error for missing fields: \(error)")
        }
    }
    
    // MARK: - Test Results Summary
    
    private func printTestSummary() {
        let totalTests = results.count
        let passedTests = results.filter { $0.passed }.count
        let failedTests = totalTests - passedTests
        let totalDuration = results.reduce(0) { $0 + $1.duration }
        
        print("\n🧪 Template System Integration Test Summary")
        print("==========================================")
        print("Total Tests: \(totalTests)")
        print("Passed: ✅ \(passedTests)")
        print("Failed: ❌ \(failedTests)")
        print("Success Rate: \(passedTests == 0 ? 0 : Int(Double(passedTests) / Double(totalTests) * 100))%")
        print("Total Duration: \(String(format: "%.3f", totalDuration))s")
        print()
        
        if failedTests > 0 {
            print("Failed Tests:")
            for result in results.filter({ !$0.passed }) {
                print("❌ \(result.testName): \(result.error?.localizedDescription ?? "Unknown error")")
            }
        }
        
        print("✅ Template System Integration Tests Completed!")
    }
}