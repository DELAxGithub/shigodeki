//
//  TagManagementView.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import SwiftUI

struct TagManagementView: View {
    @StateObject private var tagManager = TagManager()
    @StateObject private var tagService = TagCreationService()
    @State private var showingCreateTag = false
    @State private var editingTag: TaskTag?
    @State private var tagToDelete: TaskTag?
    @State private var showingDeleteConfirmation = false
    @State private var searchText = ""

    let projectId: String
    let createdBy: String
    
    var filteredTags: [TaskTag] {
        tagManager.tags.filter { tag in
            tag.projectId == projectId && (searchText.isEmpty || tag.name.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    var sortedTags: [TaskTag] {
        filteredTags.sorted { $0.usageCount > $1.usageCount }
    }
    
    var unusedTags: [TaskTag] {
        sortedTags.filter { $0.isUnused }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TagSearchBar(searchText: $searchText)
                
                if tagManager.isLoading {
                    ProgressView("タグを読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sortedTags.isEmpty && !searchText.isEmpty {
                    TagEmptySearchView(searchText: searchText)
                } else if sortedTags.isEmpty {
                    TagEmptyStateView(onCreateTag: { showingCreateTag = true })
                } else {
                    tagListContent
                }
            }
            .navigationTitle("タグ管理")
            .navigationBarTitleDisplayMode(.large)
            // TODO: Fix toolbar ambiguity issue
            // .toolbar {
            //     ToolbarItem(placement: .navigationBarTrailing) {
            //         HStack {
            //             if !unusedTags.isEmpty {
            //                 TagCleanupButton(
            //                     hasUnusedTags: !unusedTags.isEmpty,
            //                     action: cleanupUnusedTags
            //                 )
            //             }
            //             TagCreateButton(action: { showingCreateTag = true })
            //         }
            //     }
            // }
            .onAppear {
                Task {
                    await tagManager.loadTags(projectId: projectId)
                    tagManager.startListening(projectId: projectId)
                }
            }
            .onDisappear {
                tagManager.stopListening()
            }
        }
        .sheet(isPresented: $showingCreateTag) {
            CreateTagView(
                projectId: projectId,
                createdBy: createdBy,
                tagService: tagService,
                onTagCreated: { _ in
                    // Tag will be automatically updated via listener
                }
            )
        }
        .sheet(item: $editingTag) { tag in
            EditTagView(tag: tag, onTagUpdated: { _ in
                // Tag will be automatically updated via listener 
            })
        }
        .alert("タグを削除しますか？", isPresented: $showingDeleteConfirmation, presenting: tagToDelete) { tag in
            deleteConfirmationAlert(for: tag)
        } message: { tag in
            deleteConfirmationMessage(for: tag)
        }
    }
    
    @ViewBuilder
    private var tagListContent: some View {
        if !searchText.isEmpty {
            searchResultsList
        } else {
            categorizedTagsList
        }
    }
    
    @ViewBuilder
    private var searchResultsList: some View {
        List {
            Section {
                TagListView(
                    tags: sortedTags,
                    onEdit: { tag in editingTag = tag },
                    onDelete: { tag in confirmDelete(tag) }
                )
            } header: {
                Text("\(sortedTags.count)件のタグが見つかりました")
            }
        }
        .listStyle(.insetGrouped)
    }
    
    @ViewBuilder
    private var categorizedTagsList: some View {
        List {
            let usedTags = sortedTags.filter { !$0.isUnused }
            let unusedTagsList = unusedTags
            
            if !usedTags.isEmpty {
                Section {
                    TagListView(
                        tags: usedTags,
                        onEdit: { tag in editingTag = tag },
                        onDelete: { tag in confirmDelete(tag) }
                    )
                } header: {
                    Text("使用中のタグ (\(usedTags.count))")
                }
            }
            
            if !unusedTagsList.isEmpty {
                Section {
                    TagListView(
                        tags: unusedTagsList,
                        onEdit: { tag in editingTag = tag },
                        onDelete: { tag in confirmDelete(tag) }
                    )
                } header: {
                    Text("未使用のタグ (\(unusedTagsList.count))")
                } footer: {
                    Text("未使用のタグは一括削除できます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func confirmDelete(_ tag: TaskTag) {
        tagToDelete = tag
        showingDeleteConfirmation = true
    }
    
    @ViewBuilder
    private func deleteConfirmationAlert(for tag: TaskTag) -> some View {
        Group {
            Button("削除", role: .destructive) {
                Task {
                    do {
                        try await tagManager.deleteTag(tag)
                    } catch {
                        print("Failed to delete tag: \(error)")
                    }
                }
            }
            
            Button("キャンセル", role: .cancel) {
                tagToDelete = nil
            }
        }
    }
    
    @ViewBuilder
    private func deleteConfirmationMessage(for tag: TaskTag) -> some View {
        if tag.usageCount > 0 {
            Text("このタグは\(tag.usageCount)個のタスクで使用されています。削除すると、これらのタスクからタグが解除されます。")
        } else {
            Text("このタグを削除してもよろしいですか？")
        }
    }
    
    private func cleanupUnusedTags() {
        Task {
            do {
                try await tagManager.cleanupUnusedTags(projectId: projectId)
            } catch {
                print("Failed to cleanup unused tags: \(error)")
            }
        }
    }
}

#Preview {
    TagManagementView(
        projectId: "project1",
        createdBy: "user1"
    )
}