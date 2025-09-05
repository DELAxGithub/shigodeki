//
//  TaskDetailComponents.swift
//  shigodeki
//
//  Created by Claude on 2025-09-05.
//

import SwiftUI

struct WrapTagsView: View {
    let tags: [String]
    let onRemove: (String) -> Void
    
    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 80), spacing: 6)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                HStack(spacing: 4) {
                    Text(tag).font(.caption)
                    Button(action: { onRemove(tag) }) { 
                        Image(systemName: "xmark.circle.fill").font(.caption2) 
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())
            }
        }
    }
}

struct TaskTagEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTags: [String]
    
    let availableTags: [TaskTag]
    let projectId: String
    let createdBy: String
    let onSave: ([String]) -> Void
    
    init(currentTags: [String], availableTags: [TaskTag], projectId: String, createdBy: String, onSave: @escaping ([String]) -> Void) {
        self._selectedTags = State(initialValue: currentTags)
        self.availableTags = availableTags
        self.projectId = projectId
        self.createdBy = createdBy
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("タスクのタグを編集")
                    .font(.headline)
                    .padding(.top)
                
                TagInputView(
                    selectedTags: $selectedTags,
                    availableTags: availableTags,
                    projectId: projectId,
                    ownerId: createdBy,
                    ownerType: .individual,
                    createdBy: createdBy,
                    onTagCreated: { _ in
                        // Tag will be automatically updated via listener
                    }
                )
                .frame(maxHeight: 300)
                
                Spacer()
            }
            .padding()
            .navigationTitle("タグ編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(selectedTags)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func makeAttributedString(from text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Simple URL detection using NSDataDetector
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(location: 0, length: text.utf16.count)
        
        detector?.enumerateMatches(in: text, options: [], range: range) { (match, _, _) in
            guard let match = match, let _ = Range(match.range, in: text) else { return }
            
            if let url = match.url {
                // Convert to AttributedString range
                let startIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: match.range.location)
                let endIndex = attributedString.index(startIndex, offsetByCharacters: match.range.length)
                let attributedRange = startIndex..<endIndex
                
                // Apply link styling
                attributedString[attributedRange].foregroundColor = .blue
                attributedString[attributedRange].underlineStyle = .single
                attributedString[attributedRange].link = url
            }
        }
        
        return attributedString
    }
}