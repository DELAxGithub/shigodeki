//
//  AccessibilitySystem.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//  Refactored for CLAUDE.md compliance - accessibility system orchestrator
//

import SwiftUI

// MARK: - Re-export all accessibility modules for backward compatibility

// VoiceOver and basic accessibility extensions
@_exported import VoiceOverExtensions

// Dynamic Type, motion, and visual accessibility
@_exported import DynamicTypeExtensions

// Accessibility-optimized UI components  
@_exported import AccessibilityComponents

// Focus management and announcements
@_exported import AccessibilityFocusManager