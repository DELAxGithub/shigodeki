//
//  SimpleInvitationCodeTests.swift
//  shigodekiTests
//
//  Created by Claude on 2025-09-07.
//

import XCTest
@testable import shigodeki

final class SimpleInvitationCodeTests: XCTestCase {

    func testInvitationCodeNormalization() {
        // Basic normalization tests
        XCTAssertEqual(InvitationCodeNormalizer.normalize("123456"), "123456")
        XCTAssertEqual(InvitationCodeNormalizer.normalize("  123456  "), "123456")
        XCTAssertEqual(InvitationCodeNormalizer.normalize("１２３４５６"), "123456")
        XCTAssertEqual(InvitationCodeNormalizer.normalize("123-456"), "123456")
        XCTAssertEqual(InvitationCodeNormalizer.normalize(" ９１５-５４９ "), "915549")
    }
    
    func testInviteCodeSpecValidation() {
        // Valid codes
        XCTAssertTrue(InviteCodeSpec.validate("123456").isValid)
        
        // Invalid codes  
        XCTAssertFalse(InviteCodeSpec.validate("").isValid)
        XCTAssertFalse(InviteCodeSpec.validate("12345").isValid)
        XCTAssertFalse(InviteCodeSpec.validate("1234567").isValid)
        XCTAssertFalse(InviteCodeSpec.validate("12A456").isValid)
    }
    
    func testIntegratedNormalizationAndValidation() {
        // Test the full flow from user input to normalized validation
        let testCases: [(input: String, shouldBeValid: Bool)] = [
            ("915549", true),
            ("  915549  ", true), 
            ("９１５５４９", true),
            ("915-549", true),
            (" ９１５-５４９ ", true), // The problematic case from user description
            ("91554", false),
            ("9155499", false),
            ("915A49", false),
            ("ABCDEF", false),
        ]
        
        for (input, expected) in testCases {
            let normalized = InvitationCodeNormalizer.normalize(input)
            let isValid = InviteCodeSpec.validate(normalized).isValid
            XCTAssertEqual(isValid, expected, "Failed for input: '\(input)' -> '\(normalized)'")
        }
    }
}