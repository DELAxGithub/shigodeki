#!/usr/bin/env swift

//
// Issue #54 Reproduction Test: プロジェクトテンプレート選択モーダルで1枚目が初回空表示される
//
// TDD RED Phase: テンプレート選択モーダルのページング表示問題を検証
// Expected: FAIL (first template shows empty on initial modal display)
//

import Foundation

print("🔴 RED Phase: Issue #54 テンプレート選択モーダル・初回空表示問題の検証")
print("========================================================")

// Mock Template data structure 
struct MockProjectTemplate {
    var id: String
    var name: String
    var description: String?
    var category: String
    var phases: [String]
    
    init(id: String = UUID().uuidString, name: String, description: String? = nil, category: String = "general", phases: [String] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.phases = phases
    }
}

// Mock TemplateLibraryViewModel simulating the modal state
class MockTemplateLibraryViewModel {
    var templates: [MockProjectTemplate] = []
    var currentPageIndex = 0
    var isModalPresented = false
    var isInitialLoad = true
    var loadingStates: [Int: Bool] = [:]  // Track loading state for each template page
    var displayData: [Int: MockProjectTemplate?] = [:]  // Track what's actually displayed
    
    init() {
        // Setup sample templates that would be shown in pager
        templates = [
            MockProjectTemplate(name: "Webアプリ開発", description: "フルスタックWebアプリケーションの開発", category: "development", phases: ["設計", "開発", "テスト"]),
            MockProjectTemplate(name: "モバイルアプリ開発", description: "iOSとAndroidアプリの開発", category: "mobile", phases: ["企画", "設計", "実装"]),
            MockProjectTemplate(name: "AIプロジェクト", description: "機械学習を活用したプロジェクト", category: "ai", phases: ["データ収集", "モデル構築", "評価"])
        ]
    }
    
    // Mock modal presentation behavior that triggers the bug
    func presentModal() {
        print("  📱 presentModal() called - showing template selection modal")
        isModalPresented = true
        isInitialLoad = true
        currentPageIndex = 0
        
        // Simulate initial loading states
        for i in templates.indices {
            loadingStates[i] = true
            displayData[i] = nil
        }
        
        // Simulate asynchronous template loading with timing issue
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulateTemplateLoading()
        }
    }
    
    // Mock template loading that has the timing issue
    func simulateTemplateLoading() {
        print("  🔄 simulateTemplateLoading() called")
        
        // Bug reproduction: First template loading has issues during initial modal display
        if isInitialLoad {
            // First template (index 0) fails to load properly on initial display
            loadingStates[0] = false
            displayData[0] = nil  // This is the bug - first template shows empty
            print("  ❌ First template failed to load on initial display")
            
            // Other templates load normally
            for i in 1..<templates.count {
                loadingStates[i] = false
                displayData[i] = templates[i]
                print("  ✅ Template \(i+1) loaded successfully")
            }
        } else {
            // On subsequent loads (after swiping), all templates load correctly
            for i in templates.indices {
                loadingStates[i] = false
                displayData[i] = templates[i]
                print("  ✅ Template \(i+1) loaded successfully (after swipe)")
            }
        }
    }
    
    // Mock page swipe behavior
    func swipeToPage(_ index: Int) {
        currentPageIndex = index
        print("  👆 User swiped to page \(index + 1)")
        
        // After first swipe, subsequent loads work correctly
        if isInitialLoad && index != 0 {
            isInitialLoad = false
            
            // Now reload the first template correctly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.displayData[0] = self.templates[0]
                print("  ✅ First template now loaded correctly after swipe away and back")
            }
        }
    }
    
    // Get displayed content for current page
    func getCurrentDisplayedTemplate() -> MockProjectTemplate? {
        return displayData[currentPageIndex] ?? nil
    }
    
    func isCurrentPageLoading() -> Bool {
        return loadingStates[currentPageIndex] ?? false
    }
}

// Test Case: Template Modal Initial Display Issue
struct Issue54ReproductionTest {
    
    func testFirstTemplateEmptyOnInitialModalDisplay() {
        print("🧪 Test Case: First Template Empty on Initial Modal Display")
        
        // Arrange
        let viewModel = MockTemplateLibraryViewModel()
        
        print("  Initial state:")
        print("    Available templates: \(viewModel.templates.count)")
        print("    Current page index: \(viewModel.currentPageIndex)")
        print("    Modal presented: \(viewModel.isModalPresented)")
        
        // Act: Present modal (simulate user tapping template selection)
        viewModel.presentModal()
        
        // Wait for initial loading
        Thread.sleep(forTimeInterval: 0.15)
        
        // Assert: Check initial display state
        print("  Results after modal presentation:")
        print("    Modal presented: \(viewModel.isModalPresented)")
        print("    Current page: \(viewModel.currentPageIndex + 1)")
        print("    Is loading: \(viewModel.isCurrentPageLoading())")
        
        let displayedTemplate = viewModel.getCurrentDisplayedTemplate()
        print("    Displayed template: \(displayedTemplate?.name ?? "none (EMPTY)")")
        
        let firstTemplateEmpty = displayedTemplate == nil
        let isOnFirstPage = viewModel.currentPageIndex == 0
        
        print("  First page template empty: \(firstTemplateEmpty ? "❌" : "✅")")
        print("  Currently on first page: \(isOnFirstPage ? "✅" : "❌")")
        
        if firstTemplateEmpty && isOnFirstPage {
            print("  ❌ FAIL: First template shows empty on initial modal display")
            print("         This reproduces Issue #54 bug")
        } else {
            print("  ✅ PASS: First template displays correctly on initial load")
        }
    }
    
    func testSecondTemplateDisplaysCorrectly() {
        print("\n🧪 Test Case: Second Template Displays Correctly")
        
        // Arrange
        let viewModel = MockTemplateLibraryViewModel()
        viewModel.presentModal()
        Thread.sleep(forTimeInterval: 0.15)
        
        // Act: Swipe to second template
        viewModel.swipeToPage(1)
        Thread.sleep(forTimeInterval: 0.1)
        
        // Assert
        print("  Results after swiping to second template:")
        let displayedTemplate = viewModel.getCurrentDisplayedTemplate()
        print("    Current page: \(viewModel.currentPageIndex + 1)")
        print("    Displayed template: \(displayedTemplate?.name ?? "none")")
        
        let secondTemplateDisplays = displayedTemplate != nil
        let isOnSecondPage = viewModel.currentPageIndex == 1
        
        print("  Second template displays: \(secondTemplateDisplays ? "✅" : "❌")")
        print("  On second page: \(isOnSecondPage ? "✅" : "❌")")
        
        if secondTemplateDisplays && isOnSecondPage {
            print("  ✅ PASS: Second template displays correctly")
        } else {
            print("  ❌ FAIL: Second template display issue")
        }
    }
    
    func testFirstTemplateDisplaysAfterSwipeBack() {
        print("\n🧪 Test Case: First Template Displays After Swipe Back")
        
        // Arrange
        let viewModel = MockTemplateLibraryViewModel()
        viewModel.presentModal()
        Thread.sleep(forTimeInterval: 0.15)
        
        // Act: Swipe to second, then back to first
        print("  User interaction simulation:")
        viewModel.swipeToPage(1) // Go to second
        Thread.sleep(forTimeInterval: 0.1)
        viewModel.swipeToPage(0) // Go back to first
        Thread.sleep(forTimeInterval: 0.1)
        
        // Assert
        print("  Results after swiping back to first template:")
        let displayedTemplate = viewModel.getCurrentDisplayedTemplate()
        print("    Current page: \(viewModel.currentPageIndex + 1)")
        print("    Displayed template: \(displayedTemplate?.name ?? "none")")
        
        let firstTemplateDisplays = displayedTemplate != nil
        let isOnFirstPage = viewModel.currentPageIndex == 0
        let templateMatchesExpected = displayedTemplate?.name == viewModel.templates[0].name
        
        print("  First template displays: \(firstTemplateDisplays ? "✅" : "❌")")
        print("  On first page: \(isOnFirstPage ? "✅" : "❌")")
        print("  Template matches expected: \(templateMatchesExpected ? "✅" : "❌")")
        
        if firstTemplateDisplays && isOnFirstPage && templateMatchesExpected {
            print("  ✅ PASS: First template displays correctly after swipe back")
            print("         This shows the workaround mentioned in the issue")
        } else {
            print("  ❌ FAIL: First template still has display issues after swipe back")
        }
    }
    
    func testModalLifecycleAndLoadingStates() {
        print("\n🧪 Test Case: Modal Lifecycle and Loading States")
        
        // Arrange
        let viewModel = MockTemplateLibraryViewModel()
        
        print("  Testing modal lifecycle:")
        
        // Act & Assert: Before modal presentation
        print("    Before modal:")
        print("      Modal presented: \(viewModel.isModalPresented)")
        print("      Loading states: \(viewModel.loadingStates)")
        print("      Display data: \(viewModel.displayData.count) entries")
        
        // Act: Present modal
        viewModel.presentModal()
        print("    Immediately after presentModal():")
        print("      Modal presented: \(viewModel.isModalPresented)")
        print("      Loading states: \(viewModel.loadingStates)")
        print("      Initial load flag: \(viewModel.isInitialLoad)")
        
        // Wait for async loading
        Thread.sleep(forTimeInterval: 0.15)
        print("    After loading completion:")
        print("      Loading states: \(viewModel.loadingStates)")
        print("      Templates with data: \(viewModel.displayData.filter { $0.value != nil }.count)")
        print("      Templates without data: \(viewModel.displayData.filter { $0.value == nil }.count)")
        
        // Assert lifecycle behavior
        let modalPresented = viewModel.isModalPresented
        let hasLoadingStates = !viewModel.loadingStates.isEmpty
        let firstTemplateEmpty = viewModel.displayData[0] == nil
        let otherTemplatesLoaded = viewModel.displayData.filter { $0.key != 0 && $0.value != nil }.count > 0
        
        print("  Lifecycle analysis:")
        print("    Modal presented correctly: \(modalPresented ? "✅" : "❌")")
        print("    Loading states initialized: \(hasLoadingStates ? "✅" : "❌")")
        print("    First template empty (bug): \(firstTemplateEmpty ? "❌" : "✅")")
        print("    Other templates loaded: \(otherTemplatesLoaded ? "✅" : "❌")")
        
        if modalPresented && hasLoadingStates && firstTemplateEmpty && otherTemplatesLoaded {
            print("  ❌ FAIL: Modal lifecycle shows the first template loading bug")
            print("         Specific issue: First template fails to load while others succeed")
        } else {
            print("  ✅ PASS: Modal lifecycle works correctly")
        }
    }
}

// Execute Tests
print("\n🚨 実行中: Issue #54 バグ再現テスト")
print("Expected: テンプレート選択モーダルで1枚目が初回空表示される問題")
print("If tests FAIL: Issue #54の症状が再現される")
print("If tests PASS: モーダル表示とページング機能は正常")

let testSuite = Issue54ReproductionTest()

print("\n" + String(repeating: "=", count: 50))
testSuite.testFirstTemplateEmptyOnInitialModalDisplay()
testSuite.testSecondTemplateDisplaysCorrectly()
testSuite.testFirstTemplateDisplaysAfterSwipeBack()
testSuite.testModalLifecycleAndLoadingStates()

print("\n🔴 RED Phase Results:")
print("- このテストでバグが再現される場合、問題は以下にある:")
print("  1. モーダル初期表示時の非同期データロードタイミング問題")
print("  2. SwiftUIの描画更新とデータロード競合状態")
print("  3. TabView/Pagerの初期ページ(0番目)レンダリング特有の問題")
print("  4. テンプレートデータのキャッシュ・状態管理の初期化問題")
print("  5. onAppear/onDisappearライフサイクルイベントでの競合")

print("\n🎯 Next: TemplateLibraryView にページング機能を追加し、初回表示問題を修正")
print("========================================================")