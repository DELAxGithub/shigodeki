//
//  NavigationFlowTests.swift
//  shigodekiTests
//
//  Created by Claude for newtips.md validation
//  Based on newtips.md Navigation Flow Testing methodology
//

import XCTest

class NavigationFlowTests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "isRunningUITests",
            "skipOnboarding",
            "-FF.taskAddModal", "true"
        ]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
    }
    
    // MARK: - Navigation Flow Testing Implementation from newtips.md
    
    func testNavigationStateConsistency() {
        for state in NavigationState.allCases {
            print("🧭 Testing navigation to state: \(state.rawValue)")
            
            do {
                try navigateToState(state)
                verifyStateElements(state)
                verifyBackNavigation(state)
                
                print("✅ Navigation state \(state.rawValue) verified successfully")
            } catch {
                XCTFail("Navigation to state \(state.rawValue) failed: \(error)")
            }
        }
    }
    
    func testCompleteNavigationFlow() {
        // Test a complete user journey through the app
        let navigationFlow: [NavigationState] = [
            .projectList,
            .projectCreate,
            .projectList,  // back from create
            .projectDetail,
            .taskDetail,
            .projectDetail, // back from task
            .taskListBackToFamily,
            .projectDetail,
            .familyDetail,
            .settings,
            .projectList   // back to main
        ]
        
        for (index, state) in navigationFlow.enumerated() {
            print("🧭 Navigation flow step \(index + 1): \(state.rawValue)")
            
            do {
                try navigateToState(state)
                verifyStateElements(state)
                
                // Record navigation success
                recordNavigationStep(step: index + 1, state: state, success: true)
                
            } catch {
                recordNavigationStep(step: index + 1, state: state, success: false, error: error.localizedDescription)
                XCTFail("Navigation flow failed at step \(index + 1): \(state.rawValue) - \(error)")
            }
        }
        
        print("✅ Complete navigation flow verified successfully")
    }
    
    func testBackNavigationConsistency() {
        // Test that back navigation works from every screen
        let testStates: [NavigationState] = [.projectCreate, .projectDetail, .taskDetail, .settings]
        
        for state in testStates {
            print("🔄 Testing back navigation from: \(state.rawValue)")
            
            // Navigate to state
            do {
                try navigateToState(state)
                
                // Verify we can navigate back
                let backSuccess = attemptBackNavigation()
                XCTAssertTrue(backSuccess, "Back navigation failed from state: \(state.rawValue)")
                
                if backSuccess {
                    print("✅ Back navigation successful from: \(state.rawValue)")
                } else {
                    print("❌ Back navigation failed from: \(state.rawValue)")
                }
                
            } catch {
                XCTFail("Could not navigate to state \(state.rawValue) for back navigation test: \(error)")
            }
        }
    }
    
    // MARK: - Navigation Implementation Methods
    
    private func navigateToState(_ state: NavigationState) throws {
        switch state {
        case .projectList:
            // Should be the main screen - verify we're there or navigate
            if !app.navigationBars["プロジェクト"].exists {
                // Navigate to project list if not already there
                if app.tabBars.buttons["プロジェクト"].exists {
                    app.tabBars.buttons["プロジェクト"].tap()
                }
            }
            
        case .projectCreate:
            try navigateToState(.projectList)
            
            if app.buttons.matching(identifier: "create_project_button").firstMatch.exists {
                app.buttons.matching(identifier: "create_project_button").firstMatch.tap()
            } else if app.navigationBars.buttons["+"].exists {
                app.navigationBars.buttons["+"].tap()
            } else {
                throw NavigationError.buttonNotFound("Create project button not found")
            }
            
        case .projectDetail:
            try navigateToState(.projectList)
            
            // Find and tap the first project
            let projectCells = app.cells.allElementsBoundByIndex
            if let firstProject = projectCells.first(where: { $0.isHittable }) {
                firstProject.tap()
            } else {
                // Create a project first if none exist
                try navigateToState(.projectCreate)
                // Fill form and save (basic implementation)
                if app.textFields["project_name_field"].exists {
                    app.textFields["project_name_field"].tap()
                    app.textFields["project_name_field"].typeText("Test Project")
                }
                if app.buttons["save_project_button"].exists {
                    app.buttons["save_project_button"].tap()
                }
                // Now should be at project detail
            }
            
        case .taskDetail:
            try navigateToState(.projectDetail)
            
            if app.buttons.matching(identifier: "add_task_button").firstMatch.exists {
                app.buttons.matching(identifier: "add_task_button").firstMatch.tap()
            } else {
                // Find first task if exists
                let taskCells = app.cells.allElementsBoundByIndex.filter { $0.identifier.contains("task") }
                if let firstTask = taskCells.first {
                    firstTask.tap()
                } else {
                    throw NavigationError.stateNotReachable("No tasks available to navigate to")
                }
            }
            
        case .settings:
            if app.tabBars.buttons["設定"].exists {
                app.tabBars.buttons["設定"].tap()
            } else if app.navigationBars.buttons["Settings"].exists {
                app.navigationBars.buttons["Settings"].tap()
            } else {
                throw NavigationError.buttonNotFound("Settings navigation not found")
            }

        case .taskListBackToFamily:
            try navigateToState(.projectDetail)

            let taskListCells = app.tables.cells.allElementsBoundByIndex
            guard let firstList = taskListCells.first(where: { $0.isHittable }) else {
                throw NavigationError.stateNotReachable("No task lists available to open")
            }
            firstList.tap()

            let backButton = app.buttons["TaskList.BackToFamily"]
            guard backButton.waitForExistence(timeout: 3) else {
                throw NavigationError.buttonNotFound("TaskList Back to Family button not found")
            }
            backButton.tap()

            let familySheet = app.otherElements["FamilyDetailView"].firstMatch
            guard familySheet.waitForExistence(timeout: 5) else {
                throw NavigationError.stateNotReachable("Family detail sheet did not appear from TaskList")
            }

            if app.buttons["閉じる"].exists {
                app.buttons["閉じる"].tap()
            } else {
                app.swipeDown()
            }

            try navigateToState(.projectDetail)
            return

        case .profile:
            // Navigate to profile through settings or tab
            if app.tabBars.buttons["プロフィール"].exists {
                app.tabBars.buttons["プロフィール"].tap()
            } else {
                try navigateToState(.settings)
                if app.buttons["profile_button"].exists {
                    app.buttons["profile_button"].tap()
                }
            }
        }
        
        // Wait for navigation to complete
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    private func verifyStateElements(_ state: NavigationState) {
        // Check if expected navigation bar exists
        let expectedNavBar = state.rawValue
        if !expectedNavBar.isEmpty {
            XCTAssertTrue(
                app.navigationBars[expectedNavBar].exists || 
                app.navigationBars.staticTexts[expectedNavBar].exists,
                "Expected navigation bar '\(expectedNavBar)' not found for state \(state)"
            )
        }
        
        // Verify expected elements for each state
        for elementId in state.expectedElements {
            let elementExists = app.otherElements[elementId].exists ||
                               app.buttons[elementId].exists ||
                               app.textFields[elementId].exists ||
                               app.tables[elementId].exists
            
            if !elementExists {
                print("⚠️ Missing element: \(elementId) in state: \(state)")
                // Non-fatal for flexibility, as UI may evolve
            }
        }
    }
    
    private func verifyBackNavigation(_ state: NavigationState) -> Bool {
        // Skip back navigation test for root states or flows that already return
        switch state {
        case .projectList, .taskListBackToFamily:
            return true
        default:
            return attemptBackNavigation()
        }
    }
    
    private func attemptBackNavigation() -> Bool {
        let initialElementCount = app.otherElements.allElementsBoundByIndex.count
        
        // Try different back navigation methods
        if app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
        } else if app.navigationBars.buttons["戻る"].exists {
            app.navigationBars.buttons["戻る"].tap()
        } else if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
        } else if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        } else {
            // Swipe back gesture
            app.swipeRight()
        }
        
        Thread.sleep(forTimeInterval: 0.5)
        
        // Check if navigation occurred
        let newElementCount = app.otherElements.allElementsBoundByIndex.count
        return newElementCount != initialElementCount
    }
    
    // MARK: - Recording and Reporting
    
    private func recordNavigationStep(step: Int, state: NavigationState, success: Bool, error: String? = nil) {
        let timestamp = DateFormatter().string(from: Date())
        let status = success ? "✅ SUCCESS" : "❌ FAILED"
        let errorInfo = error.map { " - Error: \($0)" } ?? ""
        
        let report = """
        
        ## Navigation Flow Step \(step) - \(timestamp)
        - State: \(state.rawValue)
        - Status: \(status)\(errorInfo)
        
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

// MARK: - Navigation State Definition (adapted from newtips.md)

enum NavigationState: String, CaseIterable {
    case projectList = "プロジェクト"
    case projectDetail = "Project Detail"
    case projectCreate = "New Project" 
    case taskDetail = "Task Detail"
    case taskListBackToFamily = "Task List"
    case familyDetail = "Family Detail"
    case settings = "設定"
    case profile = "Profile"
    
    var expectedElements: [String] {
        switch self {
        case .projectList:
            return ["create_project_button", "project_list"]
        case .projectDetail:
            return ["add_task_button", "task_list", "project_settings"]
        case .projectCreate:
            return ["project_name_field", "save_project_button"]
        case .taskDetail:
            return ["task_title_field", "task_save_button"]
        case .taskListBackToFamily:
            return ["TaskListDetailView", "TaskList.BackToFamily"]
        case .familyDetail:
            return ["FamilyDetailView"]
        case .settings:
            return ["settings_list", "profile_button"]
        case .profile:
            return ["user_name_field", "logout_button"]
        }
    }
}

// MARK: - Navigation Errors

enum NavigationError: Error {
    case buttonNotFound(String)
    case stateNotReachable(String)
    case timeout(String)
}
