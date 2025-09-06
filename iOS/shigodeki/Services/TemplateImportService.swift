//
//  TemplateImportService.swift
//  shigodeki
//
//  Extracted from DocumentPickerView.swift for CLAUDE.md compliance
//  Service for handling template import operations and validation
//

import Foundation

// MARK: - Template Import Processing

@MainActor
class TemplateImportService: ObservableObject {
    @Published var importResult: TemplateImporter.ImportResult?
    @Published var validationResult: TemplateImporter.ImportResult?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    private let templateImporter = TemplateImporter()
    
    // MARK: - File Processing
    
    func processTemplateFile(url: URL) async {
        isProcessing = true
        errorMessage = nil
        
        do {
            let data = try Data(contentsOf: url)
            await processTemplateData(data: data)
        } catch {
            isProcessing = false
            errorMessage = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }
    
    func processTemplateData(data: Data) async {
        isProcessing = true
        
        do {
            // Import template
            let result = try await templateImporter.importTemplate(from: data)
            importResult = result
            validationResult = result // Same result for now
            
            isProcessing = false
            
        } catch {
            isProcessing = false
            errorMessage = "テンプレートの処理に失敗しました: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Drag & Drop Support
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    if let url = url {
                        await self.processTemplateFile(url: url)
                    } else if let error = error {
                        self.errorMessage = "ドラッグ＆ドロップの処理に失敗しました: \(error.localizedDescription)"
                    }
                }
            }
            return true
        }
        
        return false
    }
    
    // MARK: - Sample Data
    
    func loadSampleTemplate() {
        let sampleData = createSampleTemplateData()
        Task {
            await processTemplateData(data: sampleData)
        }
    }
    
    private func createSampleTemplateData() -> Data {
        let sampleJSON = """
        {
            "name": "サンプルプロジェクト",
            "description": "基本的なプロジェクトのサンプルテンプレート",
            "category": "general",
            "phases": [
                {
                    "name": "企画フェーズ",
                    "description": "プロジェクトの基本設計を行う",
                    "tasks": [
                        {
                            "name": "要件定義",
                            "description": "プロジェクトの要件を整理する",
                            "priority": "high",
                            "tags": ["企画", "要件"],
                            "isOptional": false,
                            "subtasks": [
                                {
                                    "name": "ユーザーストーリー作成",
                                    "description": "ユーザーの視点でストーリーを作成する",
                                    "priority": "medium",
                                    "tags": ["企画"],
                                    "isOptional": false,
                                    "subtasks": []
                                }
                            ]
                        }
                    ]
                },
                {
                    "name": "開発フェーズ",
                    "description": "実装作業を行う",
                    "tasks": [
                        {
                            "name": "基本設計",
                            "description": "基本的なページ構成を設計する",
                            "priority": "medium",
                            "tags": ["設計", "UI"],
                            "isOptional": false,
                            "subtasks": []
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
        
        return sampleJSON.data(using: .utf8) ?? Data()
    }
    
    // MARK: - Reset
    
    func reset() {
        importResult = nil
        validationResult = nil
        isProcessing = false
        errorMessage = nil
    }
}