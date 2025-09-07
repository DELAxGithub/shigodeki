//
//  AccessibilityFocusManager.swift
//  shigodeki
//
//  Created from AccessibilitySystem split for CLAUDE.md compliance
//  Focus management and accessibility announcements
//

import SwiftUI

// MARK: - Focus Management

@MainActor
class AccessibilityFocusManager: ObservableObject {
    static let shared = AccessibilityFocusManager()
    
    private init() {}
    
    func announcementDelayed(_ message: String, delay: TimeInterval = 0.5) {
        // 🚨 CTO修正: アクセシビリティ通知の遅延を撤廃
        // 視覚障害者のユーザー体験を考慮し、即座にアナウンスを提供
        if delay <= 0 {
            UIAccessibility.post(notification: .announcement, argument: message)
            print("⚡ AccessibilitySystem: Immediate accessibility announcement")
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                UIAccessibility.post(notification: .announcement, argument: message)
                print("⏳ AccessibilitySystem: Delayed accessibility announcement (\(delay)s)")
            }
        }
    }
    
    // 🚨 CTO追加: 即座のアクセシビリティ通知メソッド
    func announcementImmediate(_ message: String) {
        announcementDelayed(message, delay: 0)
    }
    
    func screenChanged(to element: Any? = nil) {
        UIAccessibility.post(notification: .screenChanged, argument: element)
    }
    
    func layoutChanged(to element: Any? = nil) {
        UIAccessibility.post(notification: .layoutChanged, argument: element)
    }
}

// MARK: - Accessibility Testing Helper

#if DEBUG
struct AccessibilityTestingView: View {
    @State private var showingAccessibilityInfo = false
    
    var body: some View {
        VStack {
            Button("Toggle Accessibility Info") {
                showingAccessibilityInfo.toggle()
            }
            .padding()
            
            if showingAccessibilityInfo {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accessibility Status:")
                        .font(.headline)
                    
                    Text("VoiceOver: \(UIAccessibility.isVoiceOverRunning ? "ON" : "OFF")")
                    Text("Reduce Motion: \(UIAccessibility.isReduceMotionEnabled ? "ON" : "OFF")")
                    Text("Reduce Transparency: \(UIAccessibility.isReduceTransparencyEnabled ? "ON" : "OFF")")
                    Text("Differentiate Without Color: \(UIAccessibility.shouldDifferentiateWithoutColor ? "ON" : "OFF")")
                    Text("Darker Colors: \(UIAccessibility.isDarkerSystemColorsEnabled ? "ON" : "OFF")")
                }
                .font(.caption)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}
#endif