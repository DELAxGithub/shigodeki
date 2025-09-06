//
//  BuiltInTemplates.swift
//  shigodeki
//
//  Refactored to follow CLAUDE.md principles: Composition over large files
//  This class now coordinates specialized template classes
//

import Foundation

/// Main coordinator for all built-in project templates
/// Delegates to specialized template classes for better organization
@MainActor
class BuiltInTemplates {
    
    static var allTemplates: [ProjectTemplate] {
        return [
            // Software Development Templates
            SoftwareDevTemplates.allTemplates,
            
            // Business & Project Management Templates  
            BusinessTemplates.allTemplates,
            
            // Event Planning Templates
            EventTemplates.allTemplates,
            
            // Personal & Lifestyle Templates
            LifestyleTemplates.allTemplates,
            
            // Education & Learning Templates
            EducationTemplates.allTemplates
        ].flatMap { $0 }
    }
    
    // MARK: - Category-specific Accessors
    
    static var softwareDevelopmentTemplates: [ProjectTemplate] {
        return SoftwareDevTemplates.allTemplates
    }
    
    static var businessTemplates: [ProjectTemplate] {
        return BusinessTemplates.allTemplates
    }
    
    static var eventTemplates: [ProjectTemplate] {
        return EventTemplates.allTemplates
    }
    
    static var lifestyleTemplates: [ProjectTemplate] {
        return LifestyleTemplates.allTemplates
    }
    
    static var educationTemplates: [ProjectTemplate] {
        return EducationTemplates.allTemplates
    }
    
    // MARK: - Template Search and Filtering
    
    static func templates(for category: TemplateCategory) -> [ProjectTemplate] {
        return allTemplates.filter { $0.category == category }
    }
    
    static func templates(withTag tag: String) -> [ProjectTemplate] {
        return allTemplates.filter { template in
            template.metadata.tags.contains(tag)
        }
    }
    
    static func template(named name: String) -> ProjectTemplate? {
        return allTemplates.first { $0.name == name }
    }
    
    // MARK: - Template Statistics
    
    static var templateCount: Int {
        return allTemplates.count
    }
    
    static var categoryCounts: [TemplateCategory: Int] {
        var counts: [TemplateCategory: Int] = [:]
        for template in allTemplates {
            counts[template.category, default: 0] += 1
        }
        return counts
    }
}