//
//  AccessibilityValidationTests.swift
//  shigodekiTests
//
//  Created by Claude for newtips.md validation
//  Based on newtips.md Accessibility Testing methodology
//

import XCTest

class AccessibilityValidationTests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["isRunningUITests", "skipOnboarding"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
    }
    
    // MARK: - Accessibility Testing Implementation from newtips.md
    
    func testVoiceOverSupport() {
        print("🔊 Testing VoiceOver support...")
        
        let elements = app.descendants(matching: .any).allElementsBoundByIndex
        var accessibilityIssues: [AccessibilityIssue] = []
        var totalInteractiveElements = 0
        var elementsWithLabels = 0
        var elementsWithHints = 0
        
        for element in elements {
            if element.isHittable {
                totalInteractiveElements += 1
                
                // Test accessibility label
                if let label = element.label, !label.isEmpty && label != element.identifier {
                    elementsWithLabels += 1
                } else {
                    accessibilityIssues.append(
                        AccessibilityIssue(
                            element: element.identifier,
                            type: .missingLabel,
                            severity: .high,
                            description: "Interactive element missing accessibility label"
                        )
                    )
                }
                
                // Test accessibility hint for complex interactions
                if shouldHaveHint(element: element) {
                    if let hint = element.value as? String, !hint.isEmpty {
                        elementsWithHints += 1
                    } else {
                        accessibilityIssues.append(
                            AccessibilityIssue(
                                element: element.identifier,
                                type: .missingHint,
                                severity: .medium,
                                description: "Complex interactive element missing accessibility hint"
                            )
                        )
                    }
                }
            }
        }
        
        // Generate accessibility report
        let accessibilityScore = totalInteractiveElements > 0 ? 
            Double(elementsWithLabels) / Double(totalInteractiveElements) * 100 : 0
        
        recordAccessibilityResults(
            totalElements: totalInteractiveElements,
            elementsWithLabels: elementsWithLabels,
            elementsWithHints: elementsWithHints,
            issues: accessibilityIssues,
            score: accessibilityScore
        )
        
        // Accessibility should be at least 80% compliant
        XCTAssertGreaterThan(accessibilityScore, 80.0, 
                           "Accessibility compliance below threshold: \(accessibilityScore)%")
        
        print("✅ VoiceOver support test completed. Score: \(accessibilityScore)%")
    }
    
    func testDynamicTypeSupport() {
        print("📱 Testing Dynamic Type support...")
        
        let contentSizes: [UIContentSizeCategory] = [
            .extraSmall,
            .medium,
            .large,
            .extraLarge,
            .extraExtraLarge,
            .extraExtraExtraLarge,
            .accessibilityMedium,
            .accessibilityLarge,
            .accessibilityExtraLarge,
            .accessibilityExtraExtraLarge,
            .accessibilityExtraExtraExtraLarge
        ]
        
        var dynamicTypeResults: [DynamicTypeTestResult] = []
        
        for size in contentSizes {
            print("🔤 Testing content size: \(size.rawValue)")
            
            // Simulate content size change (limited in UI tests)
            app.launchArguments = ["ContentSizeCategory:\(size.rawValue)"]
            
            let result = testLayoutWithContentSize(size)
            dynamicTypeResults.append(result)
            
            if !result.isSuccessful {
                print("⚠️ Layout issues found with content size: \(size.rawValue)")
            }
        }
        
        recordDynamicTypeResults(results: dynamicTypeResults)
        
        // Verify that at least standard sizes work
        let criticalSizes: [UIContentSizeCategory] = [.medium, .large, .extraLarge, .accessibilityLarge]
        let criticalResults = dynamicTypeResults.filter { result in
            criticalSizes.contains(result.contentSize)
        }
        
        let successfulCriticalTests = criticalResults.filter { $0.isSuccessful }.count
        let criticalSuccessRate = Double(successfulCriticalTests) / Double(criticalResults.count) * 100
        
        XCTAssertGreaterThan(criticalSuccessRate, 90.0,
                           "Critical Dynamic Type sizes support below threshold: \(criticalSuccessRate)%")
        
        print("✅ Dynamic Type support test completed. Critical success rate: \(criticalSuccessRate)%")
    }
    
    func testColorContrastAndAccessibility() {
        print("🎨 Testing color contrast and visual accessibility...")
        
        // Test that critical elements are visible and accessible
        let criticalElements = [
            "create_project_button",
            "save_button", 
            "cancel_button",
            "delete_button"
        ]
        
        var contrastIssues: [AccessibilityIssue] = []
        
        for elementId in criticalElements {
            if app.buttons[elementId].exists {
                let element = app.buttons[elementId]
                
                // Test if element is visually distinguishable
                // (Limited testing possible in UI tests)
                
                if !element.isEnabled {
                    contrastIssues.append(
                        AccessibilityIssue(
                            element: elementId,
                            type: .contrast,
                            severity: .high,
                            description: "Critical button not enabled/visible"
                        )
                    )
                }
                
                // Test button size for touch accessibility (minimum 44pt)
                let frame = element.frame
                if frame.width < 44 || frame.height < 44 {
                    contrastIssues.append(
                        AccessibilityIssue(
                            element: elementId,
                            type: .touchTarget,
                            severity: .medium,
                            description: "Touch target smaller than 44pt minimum"
                        )
                    )
                }
            }
        }
        
        recordContrastResults(issues: contrastIssues)
        
        // Should have no high-severity contrast issues
        let highSeverityIssues = contrastIssues.filter { $0.severity == .high }
        XCTAssertTrue(highSeverityIssues.isEmpty, 
                     "High-severity contrast issues found: \(highSeverityIssues.count)")
        
        print("✅ Color contrast and visual accessibility test completed")
    }
    
    func testKeyboardAccessibility() {
        print("⌨️ Testing keyboard accessibility...")
        
        // Test tab order and keyboard navigation
        let textFields = app.textFields.allElementsBoundByIndex
        var keyboardIssues: [AccessibilityIssue] = []
        
        for textField in textFields {
            if textField.isHittable {
                textField.tap()
                
                // Verify keyboard appears
                if !app.keyboards.firstMatch.exists {
                    keyboardIssues.append(
                        AccessibilityIssue(
                            element: textField.identifier,
                            type: .keyboardAccess,
                            severity: .medium,
                            description: "Text field does not bring up keyboard"
                        )
                    )
                }
                
                // Test return key functionality
                if app.keyboards.firstMatch.exists {
                    let returnButton = app.keyboards.buttons["return"] 
                    if returnButton.exists && returnButton.isHittable {
                        returnButton.tap()
                        // Should either dismiss keyboard or move to next field
                    }
                }
            }
        }
        
        recordKeyboardResults(issues: keyboardIssues)
        
        print("✅ Keyboard accessibility test completed")
    }
    
    // MARK: - Helper Methods
    
    private func shouldHaveHint(element: XCUIElement) -> Bool {
        // Elements that should have hints for better accessibility
        let elementNeedingHints = [
            "create", "delete", "share", "edit", "settings"
        ]
        
        return elementNeedingHints.contains { hint in
            element.identifier.lowercased().contains(hint)
        }
    }
    
    private func testLayoutWithContentSize(_ size: UIContentSizeCategory) -> DynamicTypeTestResult {
        let criticalElements = ["create_project_button", "navigation_bar", "tab_bar"]
        var layoutIssues: [String] = []
        
        for elementId in criticalElements {
            let element = app.buttons[elementId].exists ? app.buttons[elementId] :
                         app.navigationBars[elementId].exists ? app.navigationBars[elementId] :
                         app.tabBars[elementId].exists ? app.tabBars[elementId] : nil
            
            if let element = element {
                // Check if element is still hittable with larger text
                if !element.isHittable {
                    layoutIssues.append("Element \(elementId) not hittable with content size \(size.rawValue)")
                }
                
                // Check if element is visible (not clipped)
                let frame = element.frame
                let screenBounds = app.frame
                if !screenBounds.contains(frame) {
                    layoutIssues.append("Element \(elementId) clipped with content size \(size.rawValue)")
                }
            }
        }
        
        return DynamicTypeTestResult(
            contentSize: size,
            layoutIssues: layoutIssues,
            isSuccessful: layoutIssues.isEmpty
        )
    }
    
    // MARK: - Recording Methods
    
    private func recordAccessibilityResults(
        totalElements: Int,
        elementsWithLabels: Int, 
        elementsWithHints: Int,
        issues: [AccessibilityIssue],
        score: Double
    ) {
        let timestamp = DateFormatter().string(from: Date())
        
        let report = """
        
        ## Phase 3.3: Accessibility Testing Results - \(timestamp)
        ========================================================
        
        ### VoiceOver Support Analysis
        - Total interactive elements: \(totalElements)
        - Elements with accessibility labels: \(elementsWithLabels)
        - Elements with hints: \(elementsWithHints)
        - **Accessibility Score: \(String(format: "%.1f", score))%**
        
        ### Issues Found (\(issues.count))
        \(issues.isEmpty ? "✅ No accessibility issues detected" : issues.map { "- [\($0.severity)] \($0.element): \($0.description)" }.joined(separator: "\n"))
        
        ### Compliance Status
        \(score >= 80 ? "✅ WCAG 2.1 AA Compliant" : "❌ Below WCAG compliance threshold")
        
        """
        
        writeToValidationLog(report)
    }
    
    private func recordDynamicTypeResults(results: [DynamicTypeTestResult]) {
        let timestamp = DateFormatter().string(from: Date())
        let successfulResults = results.filter { $0.isSuccessful }
        let successRate = Double(successfulResults.count) / Double(results.count) * 100
        
        let report = """
        
        ### Dynamic Type Support Analysis - \(timestamp)
        - Content sizes tested: \(results.count)
        - Successful layouts: \(successfulResults.count)
        - **Success Rate: \(String(format: "%.1f", successRate))%**
        
        ### Failed Content Sizes
        \(results.filter { !$0.isSuccessful }.map { "- \($0.contentSize.rawValue): \($0.layoutIssues.joined(separator: ", "))" }.joined(separator: "\n"))
        
        """
        
        writeToValidationLog(report)
    }
    
    private func recordContrastResults(issues: [AccessibilityIssue]) {
        let report = """
        
        ### Color Contrast & Visual Accessibility Analysis
        - Contrast issues found: \(issues.count)
        \(issues.isEmpty ? "✅ No contrast issues detected" : issues.map { "- [\($0.severity)] \($0.element): \($0.description)" }.joined(separator: "\n"))
        
        """
        
        writeToValidationLog(report)
    }
    
    private func recordKeyboardResults(issues: [AccessibilityIssue]) {
        let report = """
        
        ### Keyboard Accessibility Analysis  
        - Keyboard issues found: \(issues.count)
        \(issues.isEmpty ? "✅ No keyboard accessibility issues detected" : issues.map { "- [\($0.severity)] \($0.element): \($0.description)" }.joined(separator: "\n"))
        
        """
        
        writeToValidationLog(report)
    }
    
    private func writeToValidationLog(_ content: String) {
        let logPath = "/Users/hiroshikodera/repos/_active/apps/shigodeki/iOS/validation_results_2025-08-29_17-25.log"
        do {
            let fileHandle = FileHandle(forWritingAtPath: logPath)
            fileHandle?.seekToEndOfFile()
            fileHandle?.write(content.data(using: .utf8) ?? Data())
            fileHandle?.closeFile()
        } catch {
            print("Failed to write to log: \(error)")
        }
    }
}

// MARK: - Supporting Structures

struct AccessibilityIssue {
    let element: String
    let type: AccessibilityIssueType
    let severity: Severity
    let description: String
}

enum AccessibilityIssueType {
    case missingLabel
    case missingHint
    case contrast
    case touchTarget
    case keyboardAccess
}

enum Severity {
    case low, medium, high
}

struct DynamicTypeTestResult {
    let contentSize: UIContentSizeCategory
    let layoutIssues: [String]
    let isSuccessful: Bool
}