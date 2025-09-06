//
//  TemplateImportValidation.swift
//  shigodeki
//
//  Extracted from TemplateImporter.swift for CLAUDE.md compliance
//  Template validation and warning generation service
//

import Foundation

@MainActor
class TemplateImportValidation: ObservableObject {
    
    struct ValidationResult {
        let projectTemplate: ProjectTemplate
        let warnings: [String]
        let statistics: TemplateStats
    }
    
    // MARK: - Validation Methods
    
    func validateAndCreateResult(template: ProjectTemplate) throws -> ValidationResult {
        var warnings: [String] = []
        
        // 基本バリデーション
        try performBasicValidation(template: template)
        
        // フェーズの順序チェック
        warnings.append(contentsOf: validatePhaseOrdering(template: template))
        
        // タスクの依存関係チェック
        warnings.append(contentsOf: validateTaskDependencies(template: template))
        
        // 統計情報を計算
        let statistics = TemplateStats(template: template)
        
        // 複雑度の警告
        warnings.append(contentsOf: validateComplexity(statistics: statistics))
        
        return ValidationResult(
            projectTemplate: template,
            warnings: warnings,
            statistics: statistics
        )
    }
    
    // MARK: - Private Validation Methods
    
    private func performBasicValidation(template: ProjectTemplate) throws {
        if template.name.isEmpty {
            throw TemplateImporter.ImportError.missingRequiredFields("name")
        }
        
        if template.phases.isEmpty {
            throw TemplateImporter.ImportError.validationFailed("少なくとも1つのフェーズが必要です")
        }
    }
    
    private func validatePhaseOrdering(template: ProjectTemplate) -> [String] {
        var warnings: [String] = []
        
        let sortedPhases = template.phases.sorted { $0.order < $1.order }
        if sortedPhases != template.phases {
            warnings.append("フェーズの順序が正しくありません。自動で修正されます。")
        }
        
        return warnings
    }
    
    private func validateTaskDependencies(template: ProjectTemplate) -> [String] {
        var warnings: [String] = []
        
        let allTaskTitles = template.phases.flatMap { phase in
            phase.taskLists.flatMap { $0.tasks.map { $0.title } }
        }
        
        for phase in template.phases {
            for taskList in phase.taskLists {
                for task in taskList.tasks {
                    if !task.dependsOn.isEmpty {
                        for dependency in task.dependsOn {
                            if !allTaskTitles.contains(dependency) {
                                warnings.append("タスク '\(task.title)' の依存関係 '\(dependency)' が見つかりません")
                            }
                        }
                    }
                }
            }
        }
        
        return warnings
    }
    
    private func validateComplexity(statistics: TemplateStats) -> [String] {
        var warnings: [String] = []
        
        if statistics.totalTasks > 100 {
            warnings.append("タスク数が多いため（\(statistics.totalTasks)個）、プロジェクト管理が複雑になる可能性があります")
        }
        
        if statistics.estimatedCompletionHours > 1000 {
            warnings.append("推定作業時間が非常に長いです（\(Int(statistics.estimatedCompletionHours))時間）")
        }
        
        return warnings
    }
}

// MARK: - Additional Validation Rules

extension TemplateImportValidation {
    
    func validatePhaseStructure(template: ProjectTemplate) -> [String] {
        var warnings: [String] = []
        
        for phase in template.phases {
            if phase.taskLists.isEmpty {
                warnings.append("フェーズ '\(phase.title)' にタスクリストがありません")
            }
            
            for taskList in phase.taskLists {
                if taskList.tasks.isEmpty {
                    warnings.append("タスクリスト '\(taskList.name)' にタスクがありません")
                }
            }
        }
        
        return warnings
    }
    
    func validateMetadata(template: ProjectTemplate) -> [String] {
        var warnings: [String] = []
        
        if template.metadata.author.isEmpty {
            warnings.append("テンプレート作成者が設定されていません")
        }
        
        if template.metadata.estimatedDuration == nil {
            warnings.append("推定完了時間が設定されていません")
        }
        
        return warnings
    }
    
    func validateTaskStructure(template: ProjectTemplate) -> [String] {
        var warnings: [String] = []
        
        for phase in template.phases {
            for taskList in phase.taskLists {
                for task in taskList.tasks {
                    if task.title.isEmpty {
                        warnings.append("空のタスクタイトルが見つかりました")
                    }
                    
                    if task.estimatedHours != nil && task.estimatedHours! < 0 {
                        warnings.append("タスク '\(task.title)' の推定時間が負の値です")
                    }
                }
            }
        }
        
        return warnings
    }
}