//
//  TemplateExportOptions.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import Foundation

enum TemplateExportError: LocalizedError {
    case noPhases
    case noTasks
    case encodingFailed
    case fileWriteFailed(String)
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .noPhases:
            return "プロジェクトにフェーズがありません"
        case .noTasks:
            return "エクスポートするタスクがありません"
        case .encodingFailed:
            return "JSONエンコードに失敗しました"
        case .fileWriteFailed(let path):
            return "ファイルの書き込みに失敗しました: \(path)"
        case .permissionDenied:
            return "ファイルへの書き込み権限がありません"
        }
    }
}

struct TemplateExportOptions {
    let includeCompletedTasks: Bool
    let includeOptionalTasks: Bool
    let includeSubtasks: Bool
    let includeEstimates: Bool
    let includeStatistics: Bool
    let anonymizeData: Bool
    let exportFormat: TemplateExportFormat
    
    init(includeCompletedTasks: Bool = true,
         includeOptionalTasks: Bool = true,
         includeSubtasks: Bool = true,
         includeEstimates: Bool = true,
         includeStatistics: Bool = false,
         anonymizeData: Bool = false,
         exportFormat: TemplateExportFormat = .projectTemplate) {
        self.includeCompletedTasks = includeCompletedTasks
        self.includeOptionalTasks = includeOptionalTasks
        self.includeSubtasks = includeSubtasks
        self.includeEstimates = includeEstimates
        self.includeStatistics = includeStatistics
        self.anonymizeData = anonymizeData
        self.exportFormat = exportFormat
    }
    
    static let `default` = TemplateExportOptions()
    static let minimal = TemplateExportOptions(
        includeCompletedTasks: false,
        includeSubtasks: false,
        includeEstimates: false
    )
    static let anonymous = TemplateExportOptions(
        includeStatistics: false,
        anonymizeData: true
    )
}

enum TemplateExportFormat {
    case projectTemplate    // 標準のProjectTemplate形式
    case legacySteps       // 旧形式のsteps形式（ツルツルテンプレート互換）
    case minimal           // 最小限のデータのみ
}