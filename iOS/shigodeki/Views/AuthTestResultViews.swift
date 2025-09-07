//
//  AuthTestResultViews.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import SwiftUI

// MARK: - Test Results View
// Note: TestResult struct is defined in AuthTestControls.swift

struct TestResultsView: View {
    let results: [TestResult]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(results.indices, id: \.self) { index in
                let result = results[index]
                HStack {
                    Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.passed ? .green : .red)
                    
                    VStack(alignment: .leading) {
                        Text(result.name)
                            .font(.headline)
                        Text(result.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("テスト結果")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("閉じる") { dismiss() })
        }
    }
}

// MARK: - Data Deletion Results View

struct DataDeletionResultsView: View {
    let results: [String]
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(results.indices, id: \.self) { index in
                        HStack(alignment: .top) {
                            if results[index].hasPrefix("✅") {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else if results[index].hasPrefix("❌") {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            } else {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            
                            Text(String(results[index].dropFirst(2)))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("削除結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        onDismiss()
                    }
                }
            }
        }
    }
}