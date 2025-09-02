//
//  ScoredEarthTests.swift  
//  shigodekiTests
//
//  Created by Claude for Operation Scorched Earth
//  Tests that MUST FAIL to expose the lies in our quality assurance
//

import XCTest
import FirebaseFirestore
@testable import shigodeki

/// 🔥 焦土作戦 (Operation: Scorched Earth)
/// These tests are designed to FAIL and expose the broken functionality
/// that our "37 comprehensive UI tests" failed to detect.
class ScoredEarthTests: XCTestCase {
    var app: XCUIApplication!
    var db: Firestore!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        // Launch app with test configuration pointing to Firebase Dev environment
        app = XCUIApplication()
        app.launchArguments = ["isRunningUITests", "useFirebaseDev"]
        app.launch()
        
        // Initialize Firestore connection to dev environment for verification
        db = Firestore.firestore()
        
        // Wait for app to be ready
        _ = app.wait(for: .runningForeground, timeout: 5)
    }
    
    override func tearDownWithError() throws {
        app.terminate()
    }
    
    // MARK: - Issue #61: タスク詳細の保存ボタンが機能しない
    
    /// この失敗テストは #61 のバグを再現します
    /// 期待: このテストは RED (失敗) になり、保存機能が動作していないことを証明します
    func testTaskDetailSaveButton_MustFail_Issue61() {
        print("🔥 [SCORCHED EARTH] Testing Issue #61: Task detail save button must fail")
        
        // Step 1: Navigate to a family/project
        navigateToFirstFamily()
        
        // Step 2: Navigate to first project  
        let firstProject = app.cells.containing(.staticText, identifier: "project").firstMatch
        XCTAssertTrue(firstProject.waitForExistence(timeout: 5), 
                     "No project found to test task detail")
        firstProject.tap()
        
        // Step 3: Navigate to first task detail
        let firstTask = app.cells.containing(.staticText, identifier: "task").firstMatch
        XCTAssertTrue(firstTask.waitForExistence(timeout: 5), 
                     "No task found to test detail editing")
        firstTask.tap()
        
        // Step 4: Wait for task detail screen
        let taskDetailTitle = app.navigationBars.firstMatch
        XCTAssertTrue(taskDetailTitle.waitForExistence(timeout: 5), 
                     "Task detail screen did not appear")
        
        // Step 5: Find and edit task title field
        let titleField = app.textFields["taskTitle"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), 
                     "Task title field not found")
        
        // Record original value for comparison
        let originalTitle = titleField.value as? String ?? ""
        let newTitle = "EDITED_TITLE_\(Date().timeIntervalSince1970)"
        
        // Edit the title
        titleField.tap()
        titleField.typeText(newTitle)
        
        // Step 6: Find and tap save button
        let saveButton = app.buttons["save"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), 
                     "Save button not found")
        XCTAssertTrue(saveButton.isEnabled, 
                     "Save button is not enabled after editing")
        
        saveButton.tap()
        
        // Step 7: Verify the edit was saved by checking UI reflection
        // Wait for save operation to complete
        Thread.sleep(forTimeInterval: 2)
        
        // Navigate away and back to verify persistence
        app.navigationBars.buttons["Back"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 1)
        
        // Return to same task
        firstTask.tap()
        
        // Step 8: Verify the change persisted in UI
        let updatedTitleField = app.textFields["taskTitle"].firstMatch
        XCTAssertTrue(updatedTitleField.waitForExistence(timeout: 3))
        
        let displayedTitle = updatedTitleField.value as? String ?? ""
        
        // 🔥 THIS TEST MUST FAIL because #61 bug prevents saving
        XCTAssertEqual(displayedTitle, newTitle, 
                      """
                      🚨 CRITICAL FAILURE: Task detail save is broken!
                      Expected: '\(newTitle)'
                      Actual: '\(displayedTitle)'
                      
                      This proves Issue #61: Save button does not function.
                      Our '37 comprehensive UI tests' failed to detect this basic functionality failure.
                      """)
        
        print("❌ [EXPECTED FAILURE] Issue #61 confirmed: Save functionality is broken")
    }
    
    // MARK: - Helper Methods
    
    private func navigateToFirstFamily() {
        // Wait for family list to load
        let familyList = app.tables.firstMatch
        XCTAssertTrue(familyList.waitForExistence(timeout: 10), 
                     "Family list did not appear")
        
        // Tap first family
        let firstFamily = app.cells.firstMatch
        XCTAssertTrue(firstFamily.waitForExistence(timeout: 5), 
                     "No family found for testing")
        firstFamily.tap()
    }
}

extension XCUIApplication {
    /// Wait for app to reach specified state
    func wait(for state: XCUIApplication.State, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "state == %d", state.rawValue)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}