//
//  TaskRelatedSections.swift
//  shigodeki
//
//  Extracted from PhaseTaskDetailSections.swift for CLAUDE.md compliance
//  Task related functionality UI components
//

import SwiftUI

// MARK: - Related Links Section

struct TaskRelatedLinksSection: View {
    let task: ShigodekiTask
    
    var body: some View {
        Section("関連リンク") {
            if let linkURL = task.linkURL, !linkURL.isEmpty {
                Link(destination: URL(string: linkURL) ?? URL(string: "https://example.com")!) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                        Text(linkURL)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            } else {
                Text("関連リンクがありません")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                TextField("https://example.com", text: Binding(
                    get: { task.linkURL ?? "" },
                    set: { _ in }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            }
        }
    }
}