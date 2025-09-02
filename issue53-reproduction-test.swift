#!/usr/bin/env swift

//
// Issue #53 Reproduction Test: 全データ削除後にナビボタン操作で削除済みカードが再出現する
//
// TDD RED Phase: データ削除後のキャッシュ・状態管理問題を検証
// Expected: FAIL (deleted cards reappear after navigation operations)
//

import Foundation

print("🔴 RED Phase: Issue #53 データ削除後のカード再出現問題の検証")
print("========================================================")

// Mock Project data structure
struct MockProject {
    var id: String
    var name: String
    var isDeleted: Bool
    
    init(id: String = UUID().uuidString, name: String, isDeleted: Bool = false) {
        self.id = id
        self.name = name
        self.isDeleted = isDeleted
    }
}

// Mock data state management that simulates the cache/sync issue
class MockDataManager {
    // Simulated remote (Firestore) data
    var remoteProjects: [MockProject] = []
    
    // Simulated local cache (the problematic layer)
    var localCache: [MockProject] = []
    
    // Simulated ViewModel displayed data
    var displayedProjects: [MockProject] = []
    
    // State tracking
    var hasDeletedAllData = false
    var navigationOperations = 0
    var cacheInvalidationCount = 0
    var dataReloadCount = 0
    
    init() {
        // Setup initial test data
        let initialProjects = [
            MockProject(name: "Webアプリプロジェクト"),
            MockProject(name: "モバイルアプリ開発"),  
            MockProject(name: "AIチャットボット作成")
        ]
        
        remoteProjects = initialProjects
        localCache = initialProjects  // Initially synced
        displayedProjects = initialProjects
    }
    
    // Mock "delete all data" operation (test environment cleanup)
    func deleteAllData() {
        print("  🗑️ deleteAllData() called - simulating test environment cleanup")
        
        // Remote data (Firestore) is properly cleared
        remoteProjects.removeAll()
        hasDeletedAllData = true
        
        print("  ✅ Remote data cleared: \(remoteProjects.count) projects remain")
        print("  🔍 Local cache state: \(localCache.count) projects remain (ISSUE!)")
        print("  🔍 Displayed data: \(displayedProjects.count) projects remain")
        
        // Issue #53 Bug: Local cache is not properly cleared
        // localCache.removeAll()  // This should happen but doesn't
        
        // Issue #53 Bug: Displayed data may not be immediately updated
        // displayedProjects.removeAll() // This should happen but might not
    }
    
    // Mock navigation operation that triggers data loading/refresh
    func performNavigationOperation(_ operation: String) {
        navigationOperations += 1
        print("  🧭 Navigation operation \(navigationOperations): \(operation)")
        
        // Simulate various data loading scenarios during navigation
        switch operation {
        case "tab_switch":
            // Tab switching often triggers data refresh
            refreshDataFromCache()
            
        case "detail_view":
            // Going to detail view and back
            refreshDataFromCache()
            
        case "pull_refresh":  
            // User pull-to-refresh action
            refreshDataFromRemote()
            
        case "app_resume":
            // App becoming active from background
            refreshDataFromCache() // Often uses cache first for performance
            
        default:
            refreshDataFromCache()
        }
        
        print("  📊 After \(operation): \(displayedProjects.count) projects displayed")
    }
    
    // Mock cache-based data refresh (problematic method)
    func refreshDataFromCache() {
        print("    🔄 refreshDataFromCache() called")
        
        // Issue #53 Bug: Uses stale cache data instead of remote source
        if !localCache.isEmpty {
            displayedProjects = localCache.filter { !$0.isDeleted }
            print("    ❌ Loaded from cache: \(displayedProjects.count) projects")
            print("    🐛 Cache contains deleted projects that should not exist!")
        } else {
            displayedProjects = []
            print("    ✅ Cache is empty, no projects loaded")
        }
    }
    
    // Mock remote-based data refresh (correct method)  
    func refreshDataFromRemote() {
        dataReloadCount += 1
        print("    🌐 refreshDataFromRemote() called (reload #\(dataReloadCount))")
        
        // Simulate network delay
        Thread.sleep(forTimeInterval: 0.05)
        
        // Correct behavior: Load from remote source
        displayedProjects = remoteProjects.filter { !$0.isDeleted }
        
        // Update local cache with fresh data
        localCache = remoteProjects
        
        print("    ✅ Loaded from remote: \(displayedProjects.count) projects")
        print("    ✅ Cache synchronized with remote data")
    }
    
    // Simulate cache invalidation (potential fix)
    func invalidateCache() {
        cacheInvalidationCount += 1
        localCache.removeAll()
        print("    💥 Cache invalidated (operation #\(cacheInvalidationCount))")
    }
}

// Test Case: Deleted Data Reappearance
struct Issue53ReproductionTest {
    
    func testDeletedDataReappearsAfterNavigation() {
        print("🧪 Test Case: Deleted Data Reappears After Navigation")
        
        // Arrange
        let dataManager = MockDataManager()
        
        print("  Initial state:")
        print("    Remote projects: \(dataManager.remoteProjects.count)")
        print("    Local cache: \(dataManager.localCache.count)")
        print("    Displayed: \(dataManager.displayedProjects.count)")
        
        // Act: Delete all data (test environment cleanup)
        dataManager.deleteAllData()
        
        print("  After data deletion:")
        print("    Remote projects: \(dataManager.remoteProjects.count)")
        print("    Local cache: \(dataManager.localCache.count)")
        print("    Displayed: \(dataManager.displayedProjects.count)")
        
        // Act: Perform navigation operations that trigger data refresh
        let navigationOperations = ["tab_switch", "detail_view", "tab_switch", "app_resume"]
        
        for operation in navigationOperations {
            dataManager.performNavigationOperation(operation)
            
            // Check if deleted data reappears
            if !dataManager.displayedProjects.isEmpty {
                print("  ❌ DELETED DATA REAPPEARED after \(operation)!")
                print("    Projects now showing: \(dataManager.displayedProjects.map { $0.name })")
                break
            }
        }
        
        // Assert
        let dataReappeared = !dataManager.displayedProjects.isEmpty
        let remoteDataDeleted = dataManager.remoteProjects.isEmpty
        let cacheContainsStaleData = !dataManager.localCache.isEmpty
        
        print("  Final results:")
        print("    Remote data properly deleted: \(remoteDataDeleted ? "✅" : "❌")")
        print("    Cache contains stale data: \(cacheContainsStaleData ? "❌" : "✅")")  
        print("    Deleted data reappeared: \(dataReappeared ? "❌" : "✅")")
        print("    Navigation operations performed: \(dataManager.navigationOperations)")
        
        if dataReappeared && remoteDataDeleted && cacheContainsStaleData {
            print("  ❌ FAIL: Issue #53 reproduced - deleted data reappears due to cache")
        } else if !dataReappeared {
            print("  ✅ PASS: Deleted data stays deleted")
        } else {
            print("  ⚠️ PARTIAL: Some aspects of the issue reproduced")
        }
    }
    
    func testCacheInvalidationFixesIssue() {
        print("\n🧪 Test Case: Cache Invalidation Fixes Issue")
        
        // Arrange
        let dataManager = MockDataManager()
        dataManager.deleteAllData()
        
        print("  Testing cache invalidation fix:")
        
        // Act: Invalidate cache after data deletion
        dataManager.invalidateCache()
        
        // Act: Perform navigation operations
        dataManager.performNavigationOperation("tab_switch")
        
        // Assert
        let dataStaysDeleted = dataManager.displayedProjects.isEmpty
        let cacheEmpty = dataManager.localCache.isEmpty
        
        print("  Results after cache invalidation:")
        print("    Cache empty: \(cacheEmpty ? "✅" : "❌")")
        print("    Data stays deleted: \(dataStaysDeleted ? "✅" : "✅")")
        
        if dataStaysDeleted && cacheEmpty {
            print("  ✅ PASS: Cache invalidation prevents data reappearance")
        } else {
            print("  ❌ FAIL: Cache invalidation doesn't fully resolve issue")
        }
    }
    
    func testRemoteRefreshWorksCorrectly() {
        print("\n🧪 Test Case: Remote Refresh Works Correctly")
        
        // Arrange
        let dataManager = MockDataManager()
        dataManager.deleteAllData()
        
        print("  Testing remote data refresh:")
        
        // Act: Force refresh from remote instead of cache
        dataManager.refreshDataFromRemote()
        
        // Assert
        let correctlyEmpty = dataManager.displayedProjects.isEmpty
        let cacheUpdated = dataManager.localCache.isEmpty
        
        print("  Results after remote refresh:")
        print("    Displayed data correct: \(correctlyEmpty ? "✅" : "❌")")
        print("    Cache synchronized: \(cacheUpdated ? "✅" : "❌")")
        print("    Data reload count: \(dataManager.dataReloadCount)")
        
        if correctlyEmpty && cacheUpdated {
            print("  ✅ PASS: Remote refresh maintains data integrity")
        } else {
            print("  ❌ FAIL: Remote refresh doesn't work properly")
        }
    }
    
    func testNavigationPatternsAndDataConsistency() {
        print("\n🧪 Test Case: Navigation Patterns and Data Consistency")
        
        // Arrange
        let dataManager = MockDataManager()
        let initialCount = dataManager.displayedProjects.count
        
        print("  Testing various navigation patterns:")
        print("    Initial project count: \(initialCount)")
        
        // Act: Delete data and test different navigation patterns
        dataManager.deleteAllData()
        
        let testPatterns = [
            ("Fast tab switching", ["tab_switch", "tab_switch", "tab_switch"]),
            ("View navigation", ["detail_view", "tab_switch", "detail_view"]), 
            ("Mixed operations", ["tab_switch", "pull_refresh", "app_resume", "tab_switch"])
        ]
        
        for (patternName, operations) in testPatterns {
            print("  Testing pattern: \(patternName)")
            
            for operation in operations {
                dataManager.performNavigationOperation(operation)
                
                if !dataManager.displayedProjects.isEmpty {
                    print("    ❌ Data reappeared during \(operation)")
                    print("    🐛 Pattern '\(patternName)' triggered the bug")
                    break
                }
            }
        }
        
        // Assert
        let finalConsistency = dataManager.displayedProjects.isEmpty
        let totalOperations = dataManager.navigationOperations
        
        print("  Navigation pattern test results:")
        print("    Total navigation operations: \(totalOperations)")
        print("    Final data consistency: \(finalConsistency ? "✅" : "❌")")
        
        if !finalConsistency {
            print("  ❌ FAIL: Navigation patterns trigger data reappearance")
            print("         Issue #53 confirmed across multiple scenarios")
        } else {
            print("  ✅ PASS: Data consistency maintained across navigation patterns")
        }
    }
}

// Execute Tests
print("\n🚨 実行中: Issue #53 バグ再現テスト")
print("Expected: データ削除後のナビゲーション操作でカードが再出現する") 
print("If tests FAIL: Issue #53の症状が再現される")
print("If tests PASS: データ整合性とキャッシュ管理は正常")

let testSuite = Issue53ReproductionTest()

print("\n" + String(repeating: "=", count: 50))
testSuite.testDeletedDataReappearsAfterNavigation()
testSuite.testCacheInvalidationFixesIssue()
testSuite.testRemoteRefreshWorksCorrectly() 
testSuite.testNavigationPatternsAndDataConsistency()

print("\n🔴 RED Phase Results:")
print("- このテストでバグが再現される場合、問題は以下にある:")
print("  1. ローカルキャッシュの不適切な管理とクリア不足")
print("  2. データ削除時のキャッシュ無効化処理の欠如")
print("  3. ナビゲーション時のキャッシュ優先ロードロジック")
print("  4. Firestoreリアルタイムリスナーと本ローカル状態の同期問題")
print("  5. ViewModelでの古いデータ保持と状態管理不備")

print("\n🎯 Next: ProjectManager/ViewModelのキャッシュ管理を改善し、削除データ再出現を防止")
print("========================================================")