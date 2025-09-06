//
//  TemplateImporter.swift
//  shigodeki
//
//  Refactored for CLAUDE.md compliance - Lightweight coordinator service
//  Validation logic extracted to TemplateImportValidation.swift
//  Conversion logic extracted to TemplateImportConversion.swift
//

import Foundation

class TemplateImporter: ObservableObject {
    
    enum ImportError: LocalizedError {
        case invalidJSON
        case unsupportedFormat
        case missingRequiredFields(String)
        case validationFailed(String)
        case conversionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidJSON:
                return "JSONファイルが無効です"
            case .unsupportedFormat:
                return "サポートされていない形式です"
            case .missingRequiredFields(let field):
                return "必須フィールド '\(field)' が見つかりません"
            case .validationFailed(let message):
                return "バリデーションエラー: \(message)"
            case .conversionFailed(let message):
                return "変換エラー: \(message)"
            }
        }
    }
    
    typealias ImportResult = TemplateImportValidation.ValidationResult
    
    @Published var isImporting = false
    @Published var lastImportResult: ImportResult?
    @Published var lastImportError: ImportError?
    
    @MainActor
    private lazy var validator = TemplateImportValidation()
    @MainActor
    private lazy var converter = TemplateImportConversion()
    
    // MARK: - Public Methods
    
    @MainActor
    func importTemplate(from jsonData: Data) async throws -> ImportResult {
        isImporting = true
        lastImportError = nil
        
        defer {
            isImporting = false
        }
        
        do {
            // まず標準形式を試す
            if let template = try? ModelJSONUtility.shared.importTemplate(from: jsonData) {
                let result = try validator.validateAndCreateResult(template: template)
                lastImportResult = result
                return result
            }
            
            // レガシー形式（steps形式）を試す
            if let legacyTemplate = try? ModelJSONUtility.shared.importLegacyTemplate(from: jsonData) {
                let template = try converter.convertFromLegacyFormat(legacyTemplate)
                let result = try validator.validateAndCreateResult(template: template)
                lastImportResult = result
                return result
            }
            
            throw ImportError.unsupportedFormat
            
        } catch let error as ImportError {
            lastImportError = error
            throw error
        } catch {
            let importError = ImportError.invalidJSON
            lastImportError = importError
            throw importError
        }
    }
    
    @MainActor
    func importTemplateFromFile(url: URL) async throws -> ImportResult {
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.conversionFailed("ファイルへのアクセス権限がありません")
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        let data = try Data(contentsOf: url)
        return try await importTemplate(from: data)
    }
    
    func createProject(from template: ProjectTemplate, ownerId: String, 
                      projectName: String? = nil, customizations: ProjectCustomizations? = nil) async throws -> Project {
        
        let finalProjectName = projectName ?? template.name
        var project = Project(name: finalProjectName, description: template.description, ownerId: ownerId)
        
        // カスタマイゼーションを適用
        if let customizations = customizations {
            if let settings = customizations.projectSettings {
                project.settings = settings
            }
        }
        
        return project
    }
    
    // MARK: - Validation and Conversion Delegation
    
    @MainActor
    func validateTemplate(_ template: ProjectTemplate) throws -> ImportResult {
        return try validator.validateAndCreateResult(template: template)
    }
    
    @MainActor
    func convertLegacyTemplate(_ legacy: LegacyJSONTemplate) throws -> ProjectTemplate {
        return try converter.convertFromLegacyFormat(legacy)
    }
}

// MARK: - Project Customizations

struct ProjectCustomizations {
    let projectSettings: ProjectSettings?
    let skipOptionalTasks: Bool
    let phaseStartDelays: [String: TimeInterval] // Phase title -> delay in seconds
    let taskPriorityOverrides: [String: TaskPriority] // Task title -> new priority
    let customPhaseColors: [String: TaskListColor] // Phase title -> color
    
    init(projectSettings: ProjectSettings? = nil,
         skipOptionalTasks: Bool = false,
         phaseStartDelays: [String: TimeInterval] = [:],
         taskPriorityOverrides: [String: TaskPriority] = [:],
         customPhaseColors: [String: TaskListColor] = [:]) {
        self.projectSettings = projectSettings
        self.skipOptionalTasks = skipOptionalTasks
        self.phaseStartDelays = phaseStartDelays
        self.taskPriorityOverrides = taskPriorityOverrides
        self.customPhaseColors = customPhaseColors
    }
}

// MARK: - Preview Support

extension TemplateImporter {
    static func previewImporter() -> TemplateImporter {
        let importer = TemplateImporter()
        
        let sampleTemplate = ProjectTemplate(
            name: "サンプルプロジェクト",
            description: "テンプレートのサンプル",
            goal: "基本的なワークフローの理解",
            category: .softwareDevelopment,
            version: "1.0",
            phases: [
                PhaseTemplate(
                    title: "準備フェーズ",
                    description: "プロジェクト開始前の準備",
                    order: 0,
                    taskLists: [
                        TaskListTemplate(
                            name: "初期設定",
                            tasks: [
                                TaskTemplate(
                                    title: "環境構築",
                                    description: "開発環境のセットアップ",
                                    priority: .high
                                )
                            ]
                        )
                    ]
                )
            ],
            metadata: TemplateMetadata(
                author: "System",
                difficulty: .beginner,
                tags: ["sample", "demo"]
            )
        )
        
        let stats = TemplateStats(template: sampleTemplate)
        importer.lastImportResult = TemplateImportValidation.ValidationResult(
            projectTemplate: sampleTemplate,
            warnings: ["これはサンプルデータです"],
            statistics: stats
        )
        
        return importer
    }
}