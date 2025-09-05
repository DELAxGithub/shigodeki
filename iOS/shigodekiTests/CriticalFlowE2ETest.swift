//
//  CriticalFlowE2ETest.swift  
//  shigodekiTests
//
//  Created for Issue #66 Root Cause Analysis
//  Purpose: 100% reproduce "basic operations fail" phenomenon
//

import XCTest
@testable import shigodeki

final class CriticalFlowE2ETest: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Critical: Use production-like environment, NOT test mocks
        app.launchArguments = ["-e2e-testing", "-use-real-firebase"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }
    
    /// **CTO REQUIREMENT**: E2E Test that reproduces "basic operations fail" 100%
    /// **Target Flow**: Family Creation -> List Verification (Issue #42)
    /// **Expected**: This test will FAIL, proving the disconnection between test results and actual functionality
    func testFamilyCreationImmediateReflection_EXPECT_FAILURE() throws {
        // Step 1: Navigate to Family Creation
        let createFamilyButton = app.buttons["create_family_button"]
        XCTAssertTrue(createFamilyButton.exists, "Create family button should exist")
        createFamilyButton.tap()
        
        // Step 2: Enter Family Name
        let familyNameField = app.textFields["例: 田中家"]
        XCTAssertTrue(familyNameField.exists, "Family name input field should exist")
        
        let testFamilyName = "E2ETest_Family_\(Int.random(in: 1000...9999))"
        familyNameField.tap()
        familyNameField.typeText(testFamilyName)
        
        // Step 3: Tap Create Button - THE CRITICAL ACTION
        let submitButton = app.buttons.containing(NSPredicate(format: "label CONTAINS '名前をつけて作成'")).firstMatch
        XCTAssertTrue(submitButton.exists, "Submit button should exist")
        submitButton.tap()
        
        // Step 4: Wait for creation to complete and return to list
        // This is where the real test begins - can we see the created family?
        let expectationCreated = expectation(description: "Family creation completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectationCreated.fulfill()
        }
        waitForExpectations(timeout: 5.0)
        
        // Step 5: THE MOMENT OF TRUTH - Check if created family appears in list
        // **THIS ASSERTION WILL FAIL** - proving Issue #42 root cause
        let createdFamilyInList = app.staticTexts[testFamilyName]
        
        // CTO NOTE: This assertion will fail, demonstrating the gap between 
        // "test passes" and "actual functionality works"
        XCTAssertTrue(
            createdFamilyInList.exists, 
            """
            ❌ CRITICAL FAILURE REPRODUCED: 
            Created family '\(testFamilyName)' does NOT appear in family list immediately after creation.
            This proves Issue #42: 家族作成後にリストに即座に反映されない
            Root Cause: FamilyViewModel.createFamily() Line 284-300 missing families array update
            """
        )
        
        // Additional verification: Check that we're actually on the family list screen
        let familyListTitle = app.navigationBars.staticTexts["チーム"]
        XCTAssertTrue(familyListTitle.exists, "Should be on family list screen")
    }
}