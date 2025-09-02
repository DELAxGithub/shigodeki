#!/usr/bin/env swift

//
// Issue #60 Reproduction Test: タスク詳細の説明文内のURLを自動でリンク化
//
// TDD RED Phase: URL自動リンク化機能のバグを検証
// Expected: FAIL (URLs in description are not automatically linked)
//

import Foundation

print("🔴 RED Phase: Issue #60 URL自動リンク化問題の検証")
print("========================================================")

// Mock URL Detection logic
struct URLDetector {
    static func detectURLs(in text: String) -> [URLMatch] {
        var matches: [URLMatch] = []
        
        // Use NSDataDetector to find URLs
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let range = NSRange(location: 0, length: text.utf16.count)
            
            detector.enumerateMatches(in: text, options: [], range: range) { (match, _, _) in
                guard let match = match, let url = match.url else { return }
                
                if let range = Range(match.range, in: text) {
                    let urlString = String(text[range])
                    matches.append(URLMatch(url: url, text: urlString, range: range))
                }
            }
        } catch {
            print("Error creating URL detector: \(error)")
        }
        
        return matches
    }
}

struct URLMatch {
    let url: URL
    let text: String
    let range: Range<String.Index>
}

// Mock AttributedString creation (simulating SwiftUI AttributedString)
struct MockAttributedString {
    var baseText: String
    var links: [URLMatch] = []
    
    init(_ text: String) {
        self.baseText = text
    }
    
    mutating func detectAndStyleLinks() {
        links = URLDetector.detectURLs(in: baseText)
    }
    
    var hasLinks: Bool {
        return !links.isEmpty
    }
    
    var linkCount: Int {
        return links.count
    }
    
    func getLinksText() -> [String] {
        return links.map { $0.text }
    }
}

// Test Case: URL Auto-Linking Functionality
struct Issue60ReproductionTest {
    
    func testSingleURLDetection() {
        print("🧪 Test Case: Single URL Detection")
        
        // Arrange
        let description = "参考資料はこちら: https://example.com をご確認ください。"
        var attributedString = MockAttributedString(description)
        
        print("  元のテキスト: \(description)")
        print("  期待されるURL: https://example.com")
        
        // Act
        attributedString.detectAndStyleLinks()
        
        // Assert
        print("  検出されたリンク数: \(attributedString.linkCount)")
        print("  リンクが存在: \(attributedString.hasLinks)")
        
        if attributedString.hasLinks {
            let detectedURLs = attributedString.getLinksText()
            print("  検出されたURL: \(detectedURLs)")
            
            let hasExpectedURL = detectedURLs.contains("https://example.com")
            print("  期待するURL検出: \(hasExpectedURL ? "✅" : "❌")")
            
            if hasExpectedURL && attributedString.linkCount == 1 {
                print("  ✅ PASS: Single URL detection works correctly")
            } else {
                print("  ❌ FAIL: Single URL detection is broken")
            }
        } else {
            print("  ❌ FAIL: No URLs detected")
        }
    }
    
    func testMultipleURLDetection() {
        print("\n🧪 Test Case: Multiple URL Detection")
        
        // Arrange
        let description = """
        複数のリンク:
        - ドキュメント: https://docs.example.com/guide
        - API参考: http://api.example.com/docs
        - サポート: https://support.example.com
        """
        var attributedString = MockAttributedString(description)
        
        print("  元のテキスト: \(description.replacingOccurrences(of: "\n", with: " "))")
        print("  期待されるURL数: 3")
        
        // Act
        attributedString.detectAndStyleLinks()
        
        // Assert
        print("  検出されたリンク数: \(attributedString.linkCount)")
        let detectedURLs = attributedString.getLinksText()
        print("  検出されたURL: \(detectedURLs)")
        
        let expectedURLs = [
            "https://docs.example.com/guide",
            "http://api.example.com/docs",
            "https://support.example.com"
        ]
        
        let allURLsDetected = expectedURLs.allSatisfy { detectedURLs.contains($0) }
        let correctCount = attributedString.linkCount == 3
        
        print("  全URL検出: \(allURLsDetected ? "✅" : "❌")")
        print("  正しい数: \(correctCount ? "✅" : "❌")")
        
        if allURLsDetected && correctCount {
            print("  ✅ PASS: Multiple URL detection works correctly")
        } else {
            print("  ❌ FAIL: Multiple URL detection is broken")
        }
    }
    
    func testNoURLInText() {
        print("\n🧪 Test Case: No URL in Text")
        
        // Arrange
        let description = "これはURLを含まないテキストです。参考資料やリンクはありません。"
        var attributedString = MockAttributedString(description)
        
        print("  元のテキスト: \(description)")
        print("  期待されるURL数: 0")
        
        // Act
        attributedString.detectAndStyleLinks()
        
        // Assert
        print("  検出されたリンク数: \(attributedString.linkCount)")
        print("  リンクが存在: \(attributedString.hasLinks)")
        
        let noLinksDetected = !attributedString.hasLinks
        let zeroCount = attributedString.linkCount == 0
        
        print("  リンクなし: \(noLinksDetected ? "✅" : "❌")")
        print("  ゼロ個数: \(zeroCount ? "✅" : "❌")")
        
        if noLinksDetected && zeroCount {
            print("  ✅ PASS: No URL detection works correctly")
        } else {
            print("  ❌ FAIL: No URL detection is broken")
        }
    }
    
    func testInvalidURLHandling() {
        print("\n🧪 Test Case: Invalid URL Handling")
        
        // Arrange
        let description = "無効なURL: htp://broken-url.com と正常なURL: https://valid.com"
        var attributedString = MockAttributedString(description)
        
        print("  元のテキスト: \(description)")
        print("  期待: 正常なURLのみ検出")
        
        // Act
        attributedString.detectAndStyleLinks()
        
        // Assert
        print("  検出されたリンク数: \(attributedString.linkCount)")
        let detectedURLs = attributedString.getLinksText()
        print("  検出されたURL: \(detectedURLs)")
        
        let hasValidURL = detectedURLs.contains("https://valid.com")
        let noInvalidURL = !detectedURLs.contains("htp://broken-url.com")
        
        print("  正常URL検出: \(hasValidURL ? "✅" : "❌")")
        print("  無効URL除外: \(noInvalidURL ? "✅" : "❌")")
        
        if hasValidURL && noInvalidURL {
            print("  ✅ PASS: Invalid URL handling works correctly")
        } else {
            print("  ❌ FAIL: Invalid URL handling is broken")
        }
    }
    
    func testPhaseTaskDetailViewIntegration() {
        print("\n🧪 Test Case: PhaseTaskDetailView Integration")
        
        // Arrange - Simulate task description with URLs
        let taskDescription = """
        このタスクの参考資料:
        - 仕様書: https://docs.company.com/spec
        - デザイン: https://figma.com/design/123
        
        問題が発生した場合は https://support.company.com にお問い合わせください。
        """
        
        print("  タスク説明文: \(taskDescription.replacingOccurrences(of: "\n", with: " "))")
        
        // Act - Simulate makeAttributedString function from PhaseTaskDetailView
        var attributedString = MockAttributedString(taskDescription)
        attributedString.detectAndStyleLinks()
        
        // Assert
        print("  検出されたリンク数: \(attributedString.linkCount)")
        print("  検出されたURL: \(attributedString.getLinksText())")
        
        let expectedURLs = [
            "https://docs.company.com/spec",
            "https://figma.com/design/123",
            "https://support.company.com"
        ]
        
        let correctDetection = expectedURLs.allSatisfy { url in
            attributedString.getLinksText().contains(url)
        }
        let correctCount = attributedString.linkCount >= 3
        
        print("  URL検出正確性: \(correctDetection ? "✅" : "❌")")
        print("  適切なリンク数: \(correctCount ? "✅" : "❌")")
        
        if correctDetection && correctCount {
            print("  ✅ PASS: PhaseTaskDetailView integration works correctly")
        } else {
            print("  ❌ FAIL: PhaseTaskDetailView integration is broken")
        }
    }
}

// Execute Tests
print("\n🚨 実行中: Issue #60 バグ再現テスト")
print("Expected: URL検出ロジック自体は正常だが、UI側で実装されていない可能性")
print("If tests PASS: バグはView層でのAttributedString実装不備")
print("If tests FAIL: URL検出ロジックの問題")

let testSuite = Issue60ReproductionTest()

print("\n" + String(repeating: "=", count: 50))
testSuite.testSingleURLDetection()
testSuite.testMultipleURLDetection()
testSuite.testNoURLInText()
testSuite.testInvalidURLHandling()
testSuite.testPhaseTaskDetailViewIntegration()

print("\n🔴 RED Phase Results:")
print("- このテストがPASSする場合、バグはUI実装層にある")
print("- バグの原因候補:")
print("  1. makeAttributedString関数の実装不備")
print("  2. AttributedStringのlink属性設定ミス")
print("  3. SwiftUI Textでのリンク表示サポート不備")
print("  4. タップイベントの処理不備")
print("  5. URL検出処理が呼ばれていない")

print("\n🎯 Next: PhaseTaskDetailView.swiftのmakeAttributedString実装確認")
print("========================================================")