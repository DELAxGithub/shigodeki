//
//  InvitationCodeNormalizationTests.swift
//  shigodekiTests
//
//  Created by Claude on 2025-09-07.
//

import XCTest
@testable import shigodeki

final class InvitationCodeNormalizationTests: XCTestCase {

    // MARK: - Normalization Tests
    
    func testNormalize_EmptyString() {
        let result = InvitationCodeNormalizer.normalize("")
        XCTAssertEqual(result, "")
    }
    
    func testNormalize_WhitespaceOnly() {
        let result = InvitationCodeNormalizer.normalize("   \n\t  ")
        XCTAssertEqual(result, "")
    }
    
    func testNormalize_ValidSixDigitCode() {
        let result = InvitationCodeNormalizer.normalize("123456")
        XCTAssertEqual(result, "123456")
    }
    
    func testNormalize_ValidNewFormatWithPrefix() {
        let result = InvitationCodeNormalizer.normalize("INV-V7DBKV")
        XCTAssertEqual(result, "V7DBKV")
    }
    
    func testNormalize_ValidNewFormatWithPrefixAndSpaces() {
        let result = InvitationCodeNormalizer.normalize(" INV-V7DBKV ")
        XCTAssertEqual(result, "V7DBKV")
    }
    
    func testNormalize_ValidNewFormatLowercase() {
        let result = InvitationCodeNormalizer.normalize("inv-v7dbkv")
        XCTAssertEqual(result, "V7DBKV")
    }
    
    func testNormalize_WithLeadingTrailingSpaces() {
        let result = InvitationCodeNormalizer.normalize("  123456  ")
        XCTAssertEqual(result, "123456")
    }
    
    func testNormalize_WithHyphens() {
        let result = InvitationCodeNormalizer.normalize("123-456")
        XCTAssertEqual(result, "123456")
    }
    
    func testNormalize_WithInternalSpaces() {
        let result = InvitationCodeNormalizer.normalize("12 34 56")
        XCTAssertEqual(result, "123456")
    }
    
    func testNormalize_FullWidthToHalfWidth() {
        let result = InvitationCodeNormalizer.normalize("１２３４５６")
        XCTAssertEqual(result, "123456")
    }
    
    func testNormalize_MixedFullWidthAndHalfWidth() {
        let result = InvitationCodeNormalizer.normalize("１２3４5６")
        XCTAssertEqual(result, "123456")
    }
    
    func testNormalize_ComplexMixedInput() {
        let result = InvitationCodeNormalizer.normalize(" ９１５-５４９ ")
        XCTAssertEqual(result, "915549")
    }
    
    func testNormalize_NewFormatAlphanumeric() {
        let result = InvitationCodeNormalizer.normalize("A1B2C3")
        XCTAssertEqual(result, "A1B2C3")  // New format preserves alphanumeric
    }
    
    func testNormalize_MixedCaseAlphanumeric() {
        let result = InvitationCodeNormalizer.normalize("inv-a1b2c3")
        XCTAssertEqual(result, "A1B2C3")  // Converted to uppercase, prefix removed
    }
    
    func testNormalize_MultipleHyphensAndSpaces() {
        let result = InvitationCodeNormalizer.normalize("1-2-3 4 5 6")
        XCTAssertEqual(result, "123456")
    }
    
    func testNormalize_AllAlphabeticCharacters() {
        let result = InvitationCodeNormalizer.normalize("ABC-DEF")
        XCTAssertEqual(result, "ABCDEF")  // New format preserves alphabetic
    }
    
    // MARK: - Classification Tests
    
    func testClassify_NewFormat() {
        let result = InvitationCodeNormalizer.classify("INV-V7DBKV")
        if case let .new(code) = result {
            XCTAssertEqual(code, "V7DBKV")
        } else {
            XCTFail("Expected .new classification")
        }
    }
    
    func testClassify_LegacyFormat() {
        let result = InvitationCodeNormalizer.classify("915549")
        if case let .legacy(code) = result {
            XCTAssertEqual(code, "915549")
        } else {
            XCTFail("Expected .legacy classification")
        }
    }
    
    func testClassify_InvalidFormat() {
        let result = InvitationCodeNormalizer.classify("INVALID")
        XCTAssertNil(result, "Should return nil for invalid format")
    }
    
    // MARK: - Character Confusion Tests (Critical for Security)
    
    func testNormalize_OZeroConfusion() {
        // O (オー) should be normalized to 0 (ゼロ)
        let inputWithO = InvitationCodeNormalizer.normalize("71ZODH")  // Contains O
        let inputWith0 = InvitationCodeNormalizer.normalize("71Z0DH")  // Contains 0
        
        // Both should normalize to the same result
        XCTAssertEqual(inputWithO, inputWith0, "O and 0 should normalize to the same result")
        XCTAssertEqual(inputWithO, "71Z0DH", "O should be converted to 0")
    }
    
    func testNormalize_IOneConfusion() {
        // I (アイ) should be normalized to 1 (イチ)
        let inputWithI = InvitationCodeNormalizer.normalize("A1B2I3")  // Contains I
        let inputWith1 = InvitationCodeNormalizer.normalize("A1B213")  // Contains 1
        
        XCTAssertEqual(inputWithI, inputWith1, "I and 1 should normalize to the same result")
        XCTAssertEqual(inputWithI, "A1B213", "I should be converted to 1")
    }
    
    func testNormalize_LOneConfusion() {
        // L (エル) should be normalized to 1 (イチ)
        let inputWithL = InvitationCodeNormalizer.normalize("ABC1LF")  // Contains L
        let inputWith1 = InvitationCodeNormalizer.normalize("ABC11F")  // Contains 1
        
        XCTAssertEqual(inputWithL, inputWith1, "L and 1 should normalize to the same result")
        XCTAssertEqual(inputWithL, "ABC11F", "L should be converted to 1")
    }
    
    func testNormalize_MultipleConfusingChars() {
        let result = InvitationCodeNormalizer.normalize("INV-LOIL01")
        // L→1, O→0, I→1, L→1, 0→0, 1→1
        XCTAssertEqual(result, "101101", "Multiple confusing characters should be normalized consistently")
    }
    
    func testNormalize_RealWorldExample() {
        // Real-world scenario from the bug report
        let inviterGenerated = "71ZODH"  // What was generated (contains O)
        let joinerInput = "71Z0DH"      // What was typed (contains 0)
        
        let normalizedInviter = InvitationCodeNormalizer.normalize(inviterGenerated)
        let normalizedJoiner = InvitationCodeNormalizer.normalize(joinerInput)
        
        XCTAssertEqual(normalizedInviter, normalizedJoiner, "Real-world O/0 confusion should be resolved")
        XCTAssertEqual(normalizedInviter, "71Z0DH", "Both should normalize to the zero version")
    }
    
    // MARK: - Logging Tests
    
    func testNormalizeWithLogging_ContainsAllSteps() {
        let input = " ９１５-５４９ "
        let result = InvitationCodeNormalizer.normalizeWithLogging(input)
        
        XCTAssertEqual(result.normalized, "915549")
        XCTAssertNotNil(result.type)
        
        // ログが各ステップを含んでいることを確認
        XCTAssertTrue(result.log.contains("Input: \" ９１５-５４９ \""))
        XCTAssertTrue(result.log.contains("Step 1 (trim):"))
        XCTAssertTrue(result.log.contains("Step 2 (full->half):"))
        XCTAssertTrue(result.log.contains("Step 3 (uppercase):"))
        XCTAssertTrue(result.log.contains("Step 4 (remove spaces/hyphens):"))
        XCTAssertTrue(result.log.contains("Step 5 (remove INV prefix): \"915549\""))
        XCTAssertTrue(result.log.contains("Classification:"))
    }
}

final class InviteCodeSpecTests: XCTestCase {

    // MARK: - Validation Tests
    
    func testValidate_Success_NewFormat() {
        let result = InviteCodeSpec.validate("V7DBKV")
        XCTAssertTrue(result.isValid)
        
        if case let .success(codeType) = result {
            if case let .new(code) = codeType {
                XCTAssertEqual(code, "V7DBKV")
            } else {
                XCTFail("Expected .new code type")
            }
        } else {
            XCTFail("Expected success but got failure")
        }
    }
    
    func testValidate_Success_LegacyFormat() {
        let result = InviteCodeSpec.validate("123456")
        XCTAssertTrue(result.isValid)
        
        if case let .success(codeType) = result {
            if case let .legacy(code) = codeType {
                XCTAssertEqual(code, "123456")
            } else {
                XCTFail("Expected .legacy code type")
            }
        } else {
            XCTFail("Expected success but got failure")
        }
    }
    
    func testValidate_EmptyString() {
        let result = InviteCodeSpec.validate("")
        XCTAssertFalse(result.isValid)
        
        if case .failure(let error) = result {
            XCTAssertEqual(error.localizedDescription, "招待コードを入力してください")
        } else {
            XCTFail("Expected failure but got success")
        }
    }
    
    func testValidate_TooShort() {
        let result = InviteCodeSpec.validate("12345")
        XCTAssertFalse(result.isValid)
        
        if case .failure(let error) = result {
            XCTAssertEqual(error.localizedDescription, "招待コードは5桁で入力してください（入力: 5桁）")
        } else {
            XCTFail("Expected failure but got success")
        }
    }
    
    func testValidate_TooLong() {
        let result = InviteCodeSpec.validate("1234567")
        XCTAssertFalse(result.isValid)
        
        if case .failure(let error) = result {
            XCTAssertEqual(error.localizedDescription, "招待コードは7桁で入力してください（入力: 7桁）")
        } else {
            XCTFail("Expected failure but got success")
        }
    }
    
    func testValidate_InvalidCharacters() {
        let result = InviteCodeSpec.validate("12@456")
        XCTAssertFalse(result.isValid)
        
        if case .failure(let error) = result {
            XCTAssertEqual(error.localizedDescription, "招待コードは 'INV-英数6桁' または '数字6桁' の形式で入力してください")
        } else {
            XCTFail("Expected failure but got success")
        }
    }
    
    // MARK: - Individual Helper Function Tests
    
    func testIsValidNewFormat_ValidCode() {
        XCTAssertTrue(InviteCodeSpec.isValidNewFormat("V7DBKV"))
        XCTAssertTrue(InviteCodeSpec.isValidNewFormat("ABC123"))
        XCTAssertTrue(InviteCodeSpec.isValidNewFormat("123456"))
    }
    
    func testIsValidLegacyFormat_ValidCode() {
        XCTAssertTrue(InviteCodeSpec.isValidLegacyFormat("123456"))
        XCTAssertTrue(InviteCodeSpec.isValidLegacyFormat("000000"))
    }
    
    func testIsValidNewFormat_InvalidCode() {
        XCTAssertFalse(InviteCodeSpec.isValidNewFormat("12@456"))
        XCTAssertFalse(InviteCodeSpec.isValidNewFormat("12345"))
        XCTAssertFalse(InviteCodeSpec.isValidNewFormat("1234567"))
        XCTAssertFalse(InviteCodeSpec.isValidNewFormat(""))
    }
    
    func testIsValidLegacyFormat_InvalidCode() {
        XCTAssertFalse(InviteCodeSpec.isValidLegacyFormat("12A456"))
        XCTAssertFalse(InviteCodeSpec.isValidLegacyFormat("12345"))
        XCTAssertFalse(InviteCodeSpec.isValidLegacyFormat("1234567"))
        XCTAssertFalse(InviteCodeSpec.isValidLegacyFormat(""))
    }
    
    func testHasCorrectLength() {
        XCTAssertTrue(InviteCodeSpec.hasCorrectLength("123456"))
        XCTAssertFalse(InviteCodeSpec.hasCorrectLength("12345"))
        XCTAssertFalse(InviteCodeSpec.hasCorrectLength("1234567"))
        XCTAssertFalse(InviteCodeSpec.hasCorrectLength(""))
    }
    
    // MARK: - Constant Tests
    
    func testConstants() {
        XCTAssertEqual(InviteCodeSpec.length, 6)
        XCTAssertEqual(InviteCodeSpec.regexNew, "^[A-Z0-9]{6}$")
        XCTAssertEqual(InviteCodeSpec.regexLegacy, "^[0-9]{6}$")
        XCTAssertEqual(InviteCodeSpec.displayPrefix, "INV-")
        XCTAssertEqual(InviteCodeSpec.newCharacters, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        XCTAssertEqual(InviteCodeSpec.legacyCharacters, "0123456789")
    }
    
    // MARK: - Code Type Tests
    
    func testInviteCodeType_DisplayFormat() {
        let newType = InviteCodeSpec.InviteCodeType.new("V7DBKV")
        XCTAssertEqual(newType.displayFormat, "INV-V7DBKV")
        XCTAssertEqual(newType.code, "V7DBKV")
        
        let legacyType = InviteCodeSpec.InviteCodeType.legacy("123456")
        XCTAssertEqual(legacyType.displayFormat, "123456")
        XCTAssertEqual(legacyType.code, "123456")
    }
}

final class IntegratedNormalizationValidationTests: XCTestCase {

    // MARK: - Integration Tests: Normalization + Validation
    
    func testIntegrated_ValidInputAfterNormalization() {
        let inputs = [
            " 123456 ",                  // Legacy format with spaces
            "１２３４５６",               // Full-width legacy
            "123-456",                   // Legacy with hyphens
            "１２３-４５６",              // Full-width legacy with hyphens
            " １２３ - ４５６ ",          // Complex legacy
            "INV-V7DBKV",                // New format
            " inv-v7dbkv ",              // New format lowercase with spaces
            "INV V7DBKV",                // New format with space instead of hyphen
            "inv v7dbkv"                 // New format lowercase with space
        ]
        
        for input in inputs {
            let normalized = InvitationCodeNormalizer.normalize(input)
            let validation = InviteCodeSpec.validate(normalized)
            
            XCTAssertTrue(validation.isValid, "Failed for input: '\(input)' -> '\(normalized)'")
        }
    }
    
    func testIntegrated_InvalidInputEvenAfterNormalization() {
        let inputs = [
            "12345",     // Too short
            "1234567",   // Too long
            "12@456",    // Contains invalid symbols
            "INV-1234",  // Too short after prefix removal
            "",          // Empty
            "   ",       // Whitespace only
            "INV-",      // Just prefix
            "INV"        // Incomplete prefix
        ]
        
        for input in inputs {
            let normalized = InvitationCodeNormalizer.normalize(input)
            let validation = InviteCodeSpec.validate(normalized)
            
            XCTAssertFalse(validation.isValid, "Unexpectedly valid for input: '\(input)' -> '\(normalized)'")
        }
    }
    
    func testIntegrated_RealWorldExamples() {
        // Real-world user input patterns
        let testCases: [(input: String, shouldBeValid: Bool, expectedNormalized: String)] = [
            // Legacy format cases
            ("915549", true, "915549"),                    // Normal legacy
            ("  915549  ", true, "915549"),               // Legacy with spaces
            ("９１５５４９", true, "915549"),                // Full-width digits
            ("915-549", true, "915549"),                   // Legacy with hyphens
            ("９１５-５４９", true, "915549"),               // Full-width + hyphens
            ("91 55 49", true, "915549"),                  // Legacy with spaces
            (" ９１５-５４９ ", true, "915549"),             // Complex legacy case
            
            // New format cases
            ("INV-V7DBKV", true, "V7DBKV"),               // Normal new format
            ("inv-v7dbkv", true, "V7DBKV"),               // Lowercase new format
            (" INV-V7DBKV ", true, "V7DBKV"),             // New format with spaces
            ("INV V7DBKV", true, "V7DBKV"),               // New format with space instead of hyphen
            ("inv v7dbkv", true, "V7DBKV"),               // Lowercase with space
            ("V7DBKV", true, "V7DBKV"),                   // Just the code part
            
            // Invalid cases
            ("91554", false, "91554"),                     // Too short
            ("9155499", false, "9155499"),                 // Too long
            ("INV-1234", false, "1234"),                   // Too short after prefix removal
            ("915@49", false, "91549"),                    // Invalid characters
            ("ABCDEFG", false, "ABCDEFG"),                 // Too long alphanumeric
            ("", false, ""),                               // Empty
        ]
        
        for testCase in testCases {
            let normalized = InvitationCodeNormalizer.normalize(testCase.input)
            let validation = InviteCodeSpec.validate(normalized)
            
            XCTAssertEqual(normalized, testCase.expectedNormalized, 
                          "Normalization failed for: '\(testCase.input)'")
            XCTAssertEqual(validation.isValid, testCase.shouldBeValid, 
                          "Validation result unexpected for: '\(testCase.input)' -> '\(normalized)'")
        }
    }
}