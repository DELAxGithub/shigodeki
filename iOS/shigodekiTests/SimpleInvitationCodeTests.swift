//
//  SimpleInvitationCodeTests.swift
//  shigodekiTests
//
//  Created by Claude on 2025-09-07.
//

import XCTest
@testable import shigodeki

final class SimpleInvitationCodeTests: XCTestCase {

    func testInvitationCodeNormalization() throws {
        // Basic normalization tests
        XCTAssertEqual(try InvitationCodeNormalizer.normalize("123456"), "123456")
        XCTAssertEqual(try InvitationCodeNormalizer.normalize("  123456  "), "123456")
        XCTAssertEqual(try InvitationCodeNormalizer.normalize("123456"), "123456")
        XCTAssertEqual(try InvitationCodeNormalizer.normalize("123456"), "123456")
        XCTAssertEqual(try InvitationCodeNormalizer.normalize("915549"), "915549")
    }

    func testInviteCodeSpecValidation() {
        // Valid codes
        XCTAssertTrue(InviteCodeSpec.validate("123456").isValid)

        // Invalid codes
        XCTAssertFalse(InviteCodeSpec.validate("").isValid)
        XCTAssertFalse(InviteCodeSpec.validate("12345").isValid)
        XCTAssertFalse(InviteCodeSpec.validate("1234567").isValid)
    }

    func testIntegratedNormalizationAndValidation() throws {
        // Test the full flow from user input to normalized validation
        let validCases: [(input: String, expected: String)] = [
            ("915549", "915549"),
            ("  915549  ", "915549"),
            ("915549", "915549"),
        ]

        for (input, expected) in validCases {
            let normalized = try InvitationCodeNormalizer.normalize(input)
            XCTAssertEqual(normalized, expected, "Failed for input: '\(input)' -> '\(normalized)'")
            let isValid = InviteCodeSpec.validate(normalized).isValid
            XCTAssertTrue(isValid, "Should be valid for input: '\(input)'")
        }

        // Invalid cases - these should fail validation
        let invalidInputs = ["91554", "9155499"]
        for input in invalidInputs {
            let normalized = try InvitationCodeNormalizer.normalize(input)
            let isValid = InviteCodeSpec.validate(normalized).isValid
            XCTAssertFalse(isValid, "Should be invalid for input: '\(input)'")
        }
    }
}
