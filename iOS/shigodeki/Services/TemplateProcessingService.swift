//
//  TemplateProcessingService.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import Foundation
import UniformTypeIdentifiers

struct TemplateProcessingService {
    
    // MARK: - File Processing
    
    /// ファイルURLからテンプレートをインポートして検証する
    static func processTemplateFile(
        url: URL,
        templateImporter: TemplateImporter,
        templateValidator: TemplateValidator
    ) async throws -> (importResult: TemplateImporter.ImportResult, validationResult: ValidationResult) {
        
        let importResult = try await templateImporter.importTemplateFromFile(url: url)
        let validationResult = await templateValidator.validate(importResult.projectTemplate)
        
        return (importResult, validationResult)
    }
    
    /// データからテンプレートをインポートして検証する
    static func processTemplateData(
        data: Data,
        templateImporter: TemplateImporter,
        templateValidator: TemplateValidator
    ) async throws -> (importResult: TemplateImporter.ImportResult, validationResult: ValidationResult) {
        
        let importResult = try await templateImporter.importTemplate(from: data)
        let validationResult = await templateValidator.validate(importResult.projectTemplate)
        
        return (importResult, validationResult)
    }
    
    // MARK: - Drag & Drop Handling
    
    /// ドラッグ&ドロップされたファイルを処理する
    static func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadDataRepresentation(forTypeIdentifier: UTType.json.identifier) { data, error in
            guard data != nil, error == nil else { return }
            // データの処理は呼び出し側で行う
        }
        
        return true
    }
    
    // MARK: - Sample Template Generation
    
    /// サンプルテンプレートデータを生成する
    static func generateSampleTemplateData() -> Data {
        let sampleData = """
        {
            "name": "シンプルなウェブサイト作成",
            "description": "基本的なウェブサイトを作成するためのテンプレート",
            "category": "software_development",
            "version": "1.0",
            "phases": [
                {
                    "title": "企画・設計",
                    "description": "ウェブサイトの企画と設計を行う",
                    "order": 0,
                    "prerequisites": [],
                    "taskLists": [
                        {
                            "name": "基本設計",
                            "color": "blue",
                            "order": 0,
                            "tasks": [
                                {
                                    "title": "要件定義",
                                    "description": "ウェブサイトの目的と要件を明確にする",
                                    "priority": "high",
                                    "tags": ["企画", "要件"],
                                    "isOptional": false,
                                    "subtasks": []
                                },
                                {
                                    "title": "ワイヤーフレーム作成",
                                    "description": "基本的なページ構成を設計する",
                                    "priority": "medium",
                                    "tags": ["設計", "UI"],
                                    "isOptional": false,
                                    "subtasks": []
                                }
                            ]
                        }
                    ]
                }
            ],
            "metadata": {
                "author": "Sample",
                "createdAt": "2025-08-29T00:00:00Z",
                "difficulty": "beginner",
                "tags": ["web", "sample"]
            }
        }
        """
        
        return sampleData.data(using: .utf8)!
    }
}
