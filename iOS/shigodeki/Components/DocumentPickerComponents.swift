//
//  DocumentPickerComponents.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Template File Selection Area

struct TemplateFileSelectionArea: View {
    let onFileSelectionTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: onFileSelectionTapped) {
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
}

// MARK: - Drag & Drop Area

struct TemplateDragDropArea: View {
    @Binding var isDragOver: Bool
    
    var body: some View {
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
}

// MARK: - Processing View

struct TemplateProcessingView: View {
    let isImporting: Bool
    let isValidating: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            VStack(spacing: 4) {
                Text("ファイルを処理中...")
                    .font(.headline)
                
                if isImporting {
                    Text("JSONを解析しています")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if isValidating {
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
}

// MARK: - Validation Results View

struct TemplateValidationResultsView: View {
    let result: ValidationResult
    
    var body: some View {
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
}

// MARK: - Action Buttons

struct TemplateActionButtons: View {
    let onSampleTapped: () -> Void
    let onTemplateListTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button("サンプルを試す") {
                onSampleTapped()
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("テンプレート一覧") {
                onTemplateListTapped()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Import Button

struct TemplateImportButton: View {
    let importResult: TemplateImporter.ImportResult?
    let validationResult: ValidationResult?
    let onImportTapped: () -> Void
    
    var body: some View {
        Button("インポート") {
            onImportTapped()
        }
        .disabled(validationResult?.isValid != true)
    }
}

// MARK: - Validation Issue Row

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

// MARK: - Template File Picker Header

struct TemplateFilePickerHeader: View {
    var body: some View {
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
    }
}