//
//  TabNavigationManager.swift
//  shigodeki
//
//  Extracted from MainTabView.swift for CLAUDE.md compliance
//  Tab navigation logic and state management
//

import SwiftUI
import Foundation

@MainActor
class TabNavigationManager: ObservableObject {
    @Published var selectedTab: Int = 0
    
    private var tabSwitchDebounceTask: Task<Void, Never>?
    // Tab indices (with a dedicated Home proxy tab at index 0)
    let homeTabIndex = 0
    let projectTabIndex = 1
    let familyTabIndex = 2
    
    #if DEBUG
    let testTabIndex = 3
    let settingsTabIndex = 4
    #else
    let settingsTabIndex = 3
    #endif
    
    deinit {
        tabSwitchDebounceTask?.cancel()
    }
    
    // MARK: - Tab Navigation
    
    func handleTabChange(oldValue: Int, newValue: Int) {
        let timestamp = Date()
        print("🔄 Issue #50 Debug: Tab changed from \(oldValue) to \(newValue) at \(timestamp)")
        
        // Cancel previous debounce task to prevent overlapping operations
        if tabSwitchDebounceTask != nil {
            print("⏹️ Issue #50 Debug: Cancelling previous tab switch task")
            tabSwitchDebounceTask?.cancel()
        }
        
        // Debounce tab notifications to prevent rapid-fire data loading
        tabSwitchDebounceTask = Task {
            let debounceStart = Date()
            print("⚡ Issue #50 優化: 即座にタブ切り替え通知を送信 at \(debounceStart)")
            
            // Check if task was cancelled
            guard !Task.isCancelled else {
                print("🔄 Issue #50 Debug: Tab notification cancelled due to new tab switch")
                return
            }
            
            let debounceEnd = Date()
            print("✅ Issue #50 優化: 即座実行完了 at \(debounceEnd), elapsed: \(Int((debounceEnd.timeIntervalSince(debounceStart)) * 1000))ms")
            
            await MainActor.run {
                // Issue #46 Fix: Only reset navigation when re-selecting same tab
                handleSameTabReselection(oldValue: oldValue, newValue: newValue)
            }
        }
    }
    
    /// Always return to Project list root from anywhere
    func goHome() {
        // Switch to Projects tab
        selectedTab = projectTabIndex
        // Post reset notification on next runloop to allow TabView selection to apply
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .projectTabSelected, object: nil)
        }
    }
    
    private func handleSameTabReselection(oldValue: Int, newValue: Int) {
        guard oldValue == newValue else { return }
        
        switch newValue {
        case projectTabIndex:
            print("📱 Issue #46: Same Project tab re-selected, resetting navigation")
            NotificationCenter.default.post(name: .projectTabSelected, object: nil)
            
        case familyTabIndex:
            print("📱 Issue #46: Same Family tab re-selected, resetting navigation")
            NotificationCenter.default.post(name: .familyTabSelected, object: nil)
            
        case settingsTabIndex:
            print("📱 Issue #46: Same Settings tab re-selected, resetting navigation")
            NotificationCenter.default.post(name: .settingsTabSelected, object: nil)
            
        #if DEBUG
        case testTabIndex:
            print("📱 Issue #46: Same Test tab re-selected, resetting navigation")
            NotificationCenter.default.post(name: .testTabSelected, object: nil)
        #endif
        
        default:
            break
        }
    }
}

extension Notification.Name {
    static let projectTabSelected = Notification.Name("ProjectTabSelectedNotification")
    static let familyTabSelected = Notification.Name("FamilyTabSelectedNotification")
    static let settingsTabSelected = Notification.Name("SettingsTabSelectedNotification")
    
    #if DEBUG
    static let testTabSelected = Notification.Name("TestTabSelectedNotification")
    #endif
}
