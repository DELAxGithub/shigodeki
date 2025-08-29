//
//  DocumentPickerView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {
    
    @Binding var isPresented: Bool
    let onDocumentPicked: (URL) -> Void
    let allowedTypes: [UTType]
    let allowsMultipleSelection: Bool
    
    init(isPresented: Binding<Bool>, 
         allowedTypes: [UTType] = [.json], 
         allowsMultipleSelection: Bool = false,
         onDocumentPicked: @escaping (URL) -> Void) {
        self._isPresented = isPresented
        self.allowedTypes = allowedTypes
        self.allowsMultipleSelection = allowsMultipleSelection
        self.onDocumentPicked = onDocumentPicked
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.shouldShowFileExtensions = true
        
        // iOS 14以降でのカスタマイゼーション
        if #available(iOS 14.0, *) {
            picker.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // 必要に応じてアップデート処理
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.isPresented = false
            
            guard let url = urls.first else { return }
            parent.onDocumentPicked(url)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Template File Picker Component

struct TemplateFilePickerView: View {
    @StateObject private var templateImporter = TemplateImporter()
    @StateObject private var templateValidator = TemplateValidator()
    
    @Binding var isPresented: Bool
    @Binding var selectedTemplate: ProjectTemplate?
    
    @State private var showDocumentPicker = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showValidationResults = false
    @State private var validationResult: TemplateValidator.ValidationResult?
    @State private var importResult: TemplateImporter.ImportResult?
    @State private var isProcessing = false
    
    // ドラッグ&ドロップ用
    @State private var isDragOver = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // ヘッダー
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.largeTitle)
                        .foregroundColor(.primaryBlue)
                    
                    Text("テンプレートファイルを選択")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("JSONまたはTemplateファイル (.json, .template) をインポートできます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                Spacer()
                
                // ファイル選択エリア
                fileSelectionArea
                
                // ドラッグ&ドロップエリア
                dragDropArea
                
                // 処理中表示
                if isProcessing {
                    processingView
                } else if let result = validationResult {
                    validationResultsView(result)
                }
                
                Spacer()
                
                // アクションボタン
                actionButtons
            }
            .padding()
            .navigationTitle("テンプレートインポート")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    isPresented = false
                },
                trailing: importButton
            )
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView(isPresented: $showDocumentPicker) { url in
                processTemplateFile(url: url)
            }
        }
        .alert("エラー", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onDrop(of: [.json], isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
        }
    }
    
    // MARK: - Views
    
    private var fileSelectionArea: some View {
        VStack(spacing: 16) {
            Button(action: {
                showDocumentPicker = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ファイルを選択")
                            .font(.headline)
                        Text("デバイスから選択")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                
                Text("または")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
            }
        }
    }
    
    private var dragDropArea: some View {
        VStack(spacing: 12) {
            Image(systemName: isDragOver ? "doc.badge.plus.fill" : "doc.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(isDragOver ? .primaryBlue : .secondary)
                .scaleEffect(isDragOver ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isDragOver)
            
            VStack(spacing: 4) {
                Text(isDragOver ? "ファイルをドロップ" : "ファイルをドラッグ&ドロップ")
                    .font(.headline)
                    .foregroundColor(isDragOver ? .primaryBlue : .primary)
                
                Text("JSON, Templateファイル対応")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isDragOver ? Color.primaryBlue : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: isDragOver ? [] : [5, 5])
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isDragOver ? Color.primaryBlue.opacity(0.05) : Color.clear)
                )
        )
    }
    
    private var processingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            VStack(spacing: 4) {
                Text("ファイルを処理中...")
                    .font(.headline)
                
                if templateImporter.isImporting {
                    Text("JSONを解析しています")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if templateValidator.isValidating {
                    Text("テンプレートを検証しています")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func validationResultsView(_ result: TemplateValidator.ValidationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(result.isValid ? .success : .warning)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.isValid ? "検証完了" : "問題が見つかりました")
                        .font(.headline)
                    
                    Text("タスク数: \(result.complexity.totalTasks), 複雑度: \(result.complexity.complexityLevel)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if result.hasErrors || result.hasWarnings {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(result.errors, id: \.localizedDescription) { error in
                            ValidationIssueRow(
                                icon: "xmark.circle.fill",
                                color: .error,
                                title: "エラー",
                                message: error.localizedDescription
                            )
                        }
                        
                        ForEach(result.warnings, id: \.localizedDescription) { warning in
                            ValidationIssueRow(
                                icon: "exclamationmark.triangle.fill",
                                color: .warning,
                                title: "警告",
                                message: warning.localizedDescription
                            )
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
            
            if !result.suggestions.isEmpty {
                DisclosureGroup("提案 (\(result.suggestions.count)件)") {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(result.suggestions.indices, id: \.self) { index in
                            let suggestion = result.suggestions[index]
                            ValidationIssueRow(
                                icon: "lightbulb.fill",
                                color: .primaryBlue,
                                title: "提案",
                                message: suggestion.message
                            )
                        }
                    }
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("サンプルを試す") {
                loadSampleTemplate()
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("テンプレート一覧") {
                // テンプレート一覧を表示
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var importButton: some View {
        Button("インポート") {
            if let result = importResult {
                selectedTemplate = result.projectTemplate
                isPresented = false
            }
        }
        .disabled(validationResult?.isValid != true)
    }
    
    // MARK: - Methods
    
    @MainActor
    private func processTemplateFile(url: URL) {
        isProcessing = true
        validationResult = nil
        
        Task {
            do {
                let result = try await templateImporter.importTemplateFromFile(url: url)
                let validation = await templateValidator.validate(result.projectTemplate)
                
                importResult = result
                validationResult = validation
                isProcessing = false
                
                // Auto-select template if validation passed
                if validation.isValid {
                    selectedTemplate = result.projectTemplate
                    isPresented = false
                }
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
                isProcessing = false
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadDataRepresentation(forTypeIdentifier: UTType.json.identifier) { data, error in
            guard let data = data, error == nil else { return }
            
            DispatchQueue.main.async {
                processTemplateData(data: data)
            }
        }
        
        return true
    }
    
    @MainActor
    private func processTemplateData(data: Data) {
        isProcessing = true
        validationResult = nil
        
        Task {
            do {
                let importResult = try await templateImporter.importTemplate(from: data)
                let validation = await templateValidator.validate(importResult.projectTemplate)
                
                validationResult = validation
                isProcessing = false
                
                // Auto-select template if validation passed
                if validation.isValid {
                    selectedTemplate = importResult.projectTemplate
                    isPresented = false
                }
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
                isProcessing = false
            }
        }
    }
    
    private func loadSampleTemplate() {
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
        """.data(using: .utf8)!
        
        processTemplateData(data: sampleData)
    }
}

// MARK: - Supporting Views

struct ValidationIssueRow: View {
    let icon: String
    let color: Color
    let title: String
    let message: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

struct DocumentPickerView_Previews: PreviewProvider {
    static var previews: some View {
        TemplateFilePickerView(
            isPresented: .constant(true),
            selectedTemplate: .constant(nil)
        )
        .preferredColorScheme(.light)
    }
}