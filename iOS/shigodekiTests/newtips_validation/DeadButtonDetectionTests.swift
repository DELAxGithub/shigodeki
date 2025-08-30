//
//  DeadButtonDetectionTests.swift
//  shigodekiTests
//
//  Created by Claude for newtips.md validation
//  Based on newtips.md Dead Button Detection methodology
//

import XCTest

class DeadButtonDetectionTests: XCTestCase {
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
    
    // MARK: - Dead Button Detection Implementation from newtips.md
    
    func testScanForDeadButtons() {
        let deadButtons = app.scanForDeadButtons()
        
        // Record results for analysis
        let resultMessage = deadButtons.isEmpty 
            ? "✅ No dead buttons detected" 
            : "⚠️ Dead buttons found: \(deadButtons.joined(separator: ", "))"
        
        print("🔍 Dead Button Detection Results:")
        print(resultMessage)
        
        // Create detailed report
        recordDeadButtonResults(deadButtons: deadButtons)
        
        // Fail test if critical buttons are non-functional
        let criticalDeadButtons = deadButtons.filter { identifier in
            identifier.contains("create") || 
            identifier.contains("save") || 
            identifier.contains("login")
        }
        
        XCTAssertTrue(criticalDeadButtons.isEmpty, 
                     "Critical dead buttons detected: \(criticalDeadButtons)")
    }
    
    func testSpecificButtonFunctionality() {
        // Test key buttons mentioned in manual-checklist.md
        let criticalButtons = [
            "create_project_button",
            "add_task_button", 
            "save_button",
            "settings_button"
        ]
        
        var nonFunctionalButtons: [String] = []
        
        for buttonId in criticalButtons {
            if app.buttons[buttonId].exists && app.buttons[buttonId].isHittable {
                let initialState = captureAppState()
                
                app.buttons[buttonId].tap()
                Thread.sleep(forTimeInterval: 0.5)
                
                let newState = captureAppState()
                
                if initialState.isEquivalent(to: newState) {
                    nonFunctionalButtons.append(buttonId)
                    print("⚠️ Non-functional button detected: \(buttonId)")
                } else {
                    print("✅ Button functional: \(buttonId)")
                }
                
                // Navigate back for next test
                navigateBack()
            }
        }
        
        XCTAssertTrue(nonFunctionalButtons.isEmpty, 
                     "Non-functional critical buttons: \(nonFunctionalButtons)")
    }
    
    // MARK: - Helper Methods (Implementation of newtips.md patterns)
    
    private func captureAppState() -> AppState {
        return AppState(
            currentScreen: app.navigationBars.firstMatch.identifier,
            visibleElements: app.otherElements.allElementsBoundByIndex.map { $0.identifier },
            alerts: app.alerts.count,
            sheets: app.sheets.count,
            modals: app.otherElements.matching(identifier: "modal").count
        )
    }
    
    private func navigateBack() {
        // Try multiple back navigation methods
        if app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
        } else if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
        } else if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        }
    }
    
    private func recordDeadButtonResults(deadButtons: [String]) {
        let timestamp = DateFormatter().string(from: Date())
        let report = """
        
        # Dead Button Detection Results - \(timestamp)
        
        ## Summary
        - Total buttons scanned: \(app.buttons.allElementsBoundByIndex.count)
        - Dead buttons found: \(deadButtons.count)
        - Success rate: \(((Double(app.buttons.allElementsBoundByIndex.count - deadButtons.count) / Double(app.buttons.allElementsBoundByIndex.count)) * 100).rounded())%
        
        ## Dead Buttons List
        \(deadButtons.isEmpty ? "None detected ✅" : deadButtons.map { "- \($0)" }.joined(separator: "\n"))
        
        ## Recommendations
        \(deadButtons.isEmpty ? "No action required" : "Review and fix the above non-functional buttons")
        
        """
        
        print(report)
        
        // Write to validation results file
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

// MARK: - AppState Structure (from newtips.md)

struct AppState: Equatable {
    let currentScreen: String
    let visibleElements: [String]
    let alerts: Int
    let sheets: Int
    let modals: Int
    
    func isEquivalent(to other: AppState) -> Bool {
        return currentScreen == other.currentScreen &&
               visibleElements == other.visibleElements &&
               alerts == other.alerts &&
               sheets == other.sheets &&
               modals == other.modals
    }
}

// MARK: - XCUIApplication Extension (from newtips.md)

extension XCUIApplication {
    func scanForDeadButtons() -> [String] {
        var deadButtons: [String] = []
        let buttons = self.buttons.allElementsBoundByIndex
        
        print("🔍 Scanning \(buttons.count) buttons for functionality...")
        
        for (index, button) in buttons.enumerated() {
            guard button.isHittable && !button.identifier.isEmpty else { 
                continue 
            }
            
            print("Testing button \(index + 1)/\(buttons.count): \(button.identifier)")
            
            // Capture initial state
            let initialState = self.captureAppState()
            
            // Tap button
            button.tap()
            
            // Wait for potential changes
            Thread.sleep(forTimeInterval: 0.8)
            
            // Capture new state
            let newState = self.captureAppState()
            
            // Check if anything changed
            if initialState.isEquivalent(to: newState) {
                deadButtons.append(button.identifier)
                print("❌ Dead button detected: \(button.identifier)")
            } else {
                print("✅ Functional button: \(button.identifier)")
            }
            
            // Attempt to return to previous state
            navigateBackToInitialState()
        }
        
        return deadButtons
    }
    
    private func captureAppState() -> AppState {
        return AppState(
            currentScreen: navigationBars.firstMatch.identifier,
            visibleElements: otherElements.allElementsBoundByIndex.map { $0.identifier },
            alerts: alerts.count,
            sheets: sheets.count,
            modals: otherElements.matching(identifier: "modal").count
        )
    }
    
    private func navigateBackToInitialState() {
        // Multiple navigation back strategies
        if navigationBars.buttons.matching(identifier: "Back").firstMatch.exists {
            navigationBars.buttons.matching(identifier: "Back").firstMatch.tap()
        } else if buttons["Close"].exists {
            buttons["Close"].tap()
        } else if buttons["Cancel"].exists {
            buttons["Cancel"].tap()
        } else if buttons["Done"].exists {
            buttons["Done"].tap()
        }
        
        Thread.sleep(forTimeInterval: 0.3)
    }
}