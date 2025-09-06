//
//  TemplateValidationResultView.swift
//  shigodeki
//
//  Extracted from DocumentPickerView.swift for CLAUDE.md compliance
//  Template validation result display components
//

import SwiftUI

struct TemplateValidationResultView: View {
    let validationResult: TemplateImporter.ImportResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ValidationSummaryHeader(result: validationResult)
            
            if !validationResult.warnings.isEmpty {
                ValidationWarningsSection(warnings: validationResult.warnings)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Validation Summary Header

struct ValidationSummaryHeader: View {
    let result: TemplateImporter.ImportResult
    
    var body: some View {
        HStack {
            ValidationStatusIcon(isValid: true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("インポート完了")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Text(validationSummaryText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var validationSummaryText: String {
        let warningCount = result.warnings.count
        
        if warningCount > 0 {
            return "警告: \(warningCount)件"
        } else {
            return "問題なし"
        }
    }
}

struct ValidationStatusIcon: View {
    let isValid: Bool
    
    var body: some View {
        Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.title2)
            .foregroundColor(isValid ? .green : .red)
    }
}

// MARK: - Validation Sections

struct ValidationWarningsSection: View {
    let warnings: [String]
    
    var body: some View {
        DisclosureGroup("警告 (\(warnings.count)件)") {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(warnings.indices, id: \.self) { index in
                    ValidationIssueRow(
                        icon: "exclamationmark.triangle.fill",
                        color: .orange,
                        title: "警告",
                        message: warnings[index]
                    )
                }
            }
        }
        .font(.caption)
        .frame(maxHeight: 120)
    }
}