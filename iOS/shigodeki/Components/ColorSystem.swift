//
//  ColorSystem.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

// MARK: - Brand Color System

extension Color {
    // MARK: - Primary Brand Colors
    static let primaryBlue = Color(red: 0.0, green: 0.48, blue: 0.8) // #007ACC
    static let primaryDark = Color(red: 0.0, green: 0.4, blue: 0.7) // #0066B3
    static let primaryLight = Color(red: 0.2, green: 0.6, blue: 0.9) // #3399E5
    
    // MARK: - Semantic Colors
    static let success = Color(red: 0.0, green: 0.7, blue: 0.0) // #00B300
    static let warning = Color(red: 1.0, green: 0.6, blue: 0.0) // #FF9900
    static let error = Color(red: 0.9, green: 0.0, blue: 0.0) // #E60000
    static let info = primaryBlue
    
    // MARK: - Status Colors
    static let completed = success
    static let inProgress = Color(red: 0.0, green: 0.6, blue: 0.8) // #009ACC
    static let pending = Color(red: 0.6, green: 0.6, blue: 0.6) // #999999
    static let overdue = error
    
    // MARK: - UI Element Colors
    static let cardBackground = Color(.systemBackground)
    static let secondaryCardBackground = Color(.secondarySystemBackground)
    static let tertiaryCardBackground = Color(.tertiarySystemBackground)
    
    // MARK: - Text Colors
    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let tertiaryText = Color(.tertiaryLabel)
    static let quaternaryText = Color(.quaternaryLabel)
    
    // MARK: - Border Colors
    static let primaryBorder = Color(.separator)
    static let secondaryBorder = Color(.separator).opacity(0.5)
    
    // MARK: - Gradient Definitions
    static let primaryGradient = LinearGradient(
        colors: [primaryBlue, primaryDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let successGradient = LinearGradient(
        colors: [success, Color(red: 0.0, green: 0.6, blue: 0.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let warningGradient = LinearGradient(
        colors: [warning, Color(red: 0.9, green: 0.5, blue: 0.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Theme Management

class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .system
    
    enum AppTheme: String, CaseIterable {
        case light = "Light"
        case dark = "Dark"
        case system = "System"
        
        var displayName: String {
            switch self {
            case .light: return "ライト"
            case .dark: return "ダーク"
            case .system: return "システム"
            }
        }
        
        var colorScheme: ColorScheme? {
            switch self {
            case .light: return .light
            case .dark: return .dark
            case .system: return nil
            }
        }
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        // Save to UserDefaults
        UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme")
    }
    
    init() {
        // Load saved theme
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        }
    }
}

// MARK: - Accessibility Colors

extension Color {
    // High contrast colors for accessibility
    static let accessibleBlue = Color(red: 0.0, green: 0.3, blue: 0.7)
    static let accessibleGreen = Color(red: 0.0, green: 0.6, blue: 0.0)
    static let accessibleRed = Color(red: 0.8, green: 0.0, blue: 0.0)
    
    // Dynamic colors that adjust based on accessibility settings
    static var dynamicPrimary: Color {
        UIAccessibility.isDarkerSystemColorsEnabled ? accessibleBlue : primaryBlue
    }
    
    static var dynamicSuccess: Color {
        UIAccessibility.isDarkerSystemColorsEnabled ? accessibleGreen : success
    }
    
    static var dynamicError: Color {
        UIAccessibility.isDarkerSystemColorsEnabled ? accessibleRed : error
    }
}

// MARK: - Color Extensions

extension View {
    func primaryBackground() -> some View {
        self.background(Color.cardBackground)
    }
    
    func secondaryBackground() -> some View {
        self.background(Color.secondaryCardBackground)
    }
    
    func primaryBorder() -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primaryBorder, lineWidth: 0.5)
        )
    }
    
    func statusColor(for isCompleted: Bool, isOverdue: Bool = false) -> Color {
        if isCompleted {
            return .completed
        } else if isOverdue {
            return .overdue
        } else {
            return .inProgress
        }
    }
}