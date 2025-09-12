//
//  TemplateFilePickerView.swift
//  shigodeki
//
//  Extracted from DocumentPickerView.swift for CLAUDE.md compliance
//  Main template file picker interface using extracted components
//

import SwiftUI

struct TemplateFilePickerView: View {
    @Binding var isPresented: Bool
    @Binding var selectedTemplate: ProjectTemplate?
    
    @StateObject private var importService = TemplateImportService()
    @State private var showDocumentPicker = false
    @State private var isDragOver = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
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
                
                TemplateFilePickerContent(
                    importService: importService,
                    isDragOver: $isDragOver,
                    showDocumentPicker: $showDocumentPicker,
                    onDismiss: { isPresented = false },
                    onTemplateSelected: { template in
                        selectedTemplate = template
                        isPresented = false
                    }
                )
                
                Spacer()
            }
            .navigationTitle("テンプレートをインポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView(
                isPresented: $showDocumentPicker,
                allowedTypes: [.json],
                allowsMultipleSelection: false
            ) { url in
                Task {
                    await importService.processTemplateFile(url: url)
                }
            }
        }
        .toolbar { // Dev helper: quick import from bundled Torontomoving.json if present
            ToolbarItem(placement: .navigationBarTrailing) {
                #if DEBUG
                Button("Torontomoving.json") {
                    Task { await importService.processTemplateFromBundle(fileName: "Torontomoving.json") }
                }
                .accessibilityLabel("バンドル内のTorontomoving.jsonを読み込む")
                #endif
            }
        }
    }
}

// MARK: - Content Component

struct TemplateFilePickerContent: View {
    @ObservedObject var importService: TemplateImportService
    @Binding var isDragOver: Bool
    @Binding var showDocumentPicker: Bool
    let onDismiss: () -> Void
    let onTemplateSelected: (ProjectTemplate) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            TemplateFileSelectionArea {
                showDocumentPicker = true
            }
            
            if let validationResult = importService.validationResult {
                TemplateValidationResultView(validationResult: validationResult)
            }
            
            Button("サンプルを試す") {
                importService.loadSampleTemplate()
            }
            .buttonStyle(.bordered)
            
            Button("インポート") {
                if let template = importService.importResult?.projectTemplate {
                    onTemplateSelected(template)
                }
            }
            .disabled(importService.validationResult == nil)
            .buttonStyle(.borderedProminent)
        }
        .disabled(importService.isProcessing)
        .alert("エラー", isPresented: Binding<Bool>(
            get: { importService.errorMessage != nil },
            set: { _ in importService.errorMessage = nil }
        )) {
            Button("OK") {}
        } message: {
            Text(importService.errorMessage ?? "")
        }
    }
}

// MARK: - Preview

#Preview {
    TemplateFilePickerView(
        isPresented: .constant(true),
        selectedTemplate: .constant(nil)
    )
}
