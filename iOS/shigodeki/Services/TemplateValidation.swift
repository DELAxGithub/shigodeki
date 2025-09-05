//
//  TemplateValidation.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import Foundation

class TemplateValidator: ObservableObject {
    
    private let config: ValidationConfig
    @Published var lastValidationResult: ValidationResult?
    @Published var isValidating = false
    
    init(config: ValidationConfig = .default) {
        self.config = config
    }
    
    // MARK: - Public Methods
    
    func validate(_ template: ProjectTemplate) async -> ValidationResult {
        await MainActor.run {
            isValidating = true
        }
        
        defer {
            Task { @MainActor in
                isValidating = false
            }
        }
        
        var errors: [ValidationError] = []
        var warnings: [ValidationError] = []
        var suggestions: [ValidationSuggestion] = []
        
        // Basic validation
        TemplateValidationLogic.validateBasicStructure(template, errors: &errors, warnings: &warnings)
        
        // Phase validation
        TemplateValidationLogic.validatePhases(template.phases, errors: &errors, warnings: &warnings)
        
        // Task validation
        TemplateValidationLogic.validateTasks(template.phases, errors: &errors, warnings: &warnings)
        
        // Dependency validation
        TemplateValidationLogic.validateDependencies(template.phases, errors: &errors, warnings: &warnings)
        
        // Calculate complexity metrics
        let complexity = TemplateComplexityCalculator.calculateComplexity(template)
        
        // Check complexity limits
        if complexity.totalTasks > config.maxTasksPerTemplate {
            errors.append(.exceedsMaxComplexity(current: complexity.totalTasks, max: config.maxTasksPerTemplate))
        }
        
        // Generate optimization suggestions
        let optimizationSuggestions = TemplateComplexityCalculator.generateOptimizationSuggestions(template, complexity: complexity)
        suggestions.append(contentsOf: optimizationSuggestions)
        
        let result = ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            suggestions: suggestions,
            complexity: complexity
        )
        
        await MainActor.run {
            self.lastValidationResult = result
        }
        
        return result
    }
    
    func validateJSON(_ jsonData: Data) async -> ValidationResult {
        await MainActor.run {
            isValidating = true
        }
        
        defer {
            Task { @MainActor in
                isValidating = false
            }
        }
        
        do {
            // Try to decode as current ProjectTemplate format first
            if let template = try? JSONDecoder().decode(ProjectTemplate.self, from: jsonData) {
                return await validate(template)
            }
            
            // Try legacy format
            let legacy = try JSONDecoder().decode(LegacyJSONTemplate.self, from: jsonData)
            let convertedTemplate = try TemplateValidationHelpers.convertLegacyForValidation(legacy)
            
            var result = await validate(convertedTemplate)
            
            // Add version warning for legacy format
            var warnings = result.warnings
            if let version = legacy.version, version != "2.0" {
                warnings.append(.unsupportedVersion(version))
            }
            
            let updatedResult = ValidationResult(
                isValid: result.errors.isEmpty,
                errors: result.errors,
                warnings: warnings,
                suggestions: result.suggestions,
                complexity: result.complexity
            )
            
            await MainActor.run {
                self.lastValidationResult = updatedResult
            }
            
            return updatedResult
            
        } catch {
            let validationError = ValidationError.invalidDateFormat(field: "JSON", value: error.localizedDescription)
            
            let result = ValidationResult(
                isValid: false,
                errors: [validationError],
                warnings: [],
                suggestions: [],
                complexity: ComplexityMetrics(
                    totalTasks: 0,
                    totalSubtasks: 0,
                    averageTasksPerPhase: 0,
                    dependencyCount: 0,
                    estimatedTotalHours: 0,
                    complexityScore: 0,
                    maxRecommendedTasks: 0
                )
            )
            
            await MainActor.run {
                self.lastValidationResult = result
            }
            
            return result
        }
    }
}

// MARK: - Preview Support

extension TemplateValidator {
    static func previewValidator() -> TemplateValidator {
        return TemplateValidator(config: .default)
    }
}