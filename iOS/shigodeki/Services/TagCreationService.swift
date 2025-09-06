//
//  TagCreationService.swift
//  shigodeki
//
//  Extracted from TagInputView.swift for CLAUDE.md compliance
//  Tag creation business logic and validation service
//

import Foundation

@MainActor
class TagCreationService: ObservableObject {
    @Published var isCreating = false
    @Published var errorMessage: String?
    
    private let tagManager = TagManager()
    
    // MARK: - Tag Validation
    
    func validateTagName(_ tagName: String, availableTags: [TaskTag]) -> String? {
        let trimmedName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            return "タグ名を入力してください"
        }
        
        if availableTags.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            return "このタグ名は既に使用されています"
        }
        
        if trimmedName.count > 20 {
            return "タグ名は20文字以内で入力してください"
        }
        
        return nil
    }
    
    func canCreateTag(searchText: String, availableTags: [TaskTag]) -> Bool {
        return !searchText.isEmpty && !availableTags.contains { 
            $0.name.lowercased() == searchText.lowercased() 
        }
    }
    
    // MARK: - Tag Creation
    
    func createTag(
        name: String,
        color: String,
        emoji: String?,
        projectId: String,
        createdBy: String
    ) async throws -> TaskTag {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw TagCreationError.invalidInput("タグ名を入力してください")
        }
        
        isCreating = true
        errorMessage = nil
        
        defer {
            isCreating = false
        }
        
        do {
            let tagId = try await tagManager.createTag(
                name: trimmedName,
                color: color,
                emoji: emoji?.isEmpty == false ? emoji : nil,
                projectId: projectId,
                createdBy: createdBy
            )
            
            var newTag = TaskTag(
                name: trimmedName,
                color: color,
                emoji: emoji?.isEmpty == false ? emoji : nil,
                projectId: projectId,
                createdBy: createdBy
            )
            newTag.id = tagId
            
            return newTag
            
        } catch {
            if let tagError = error as? TagCreationError {
                errorMessage = tagError.errorDescription
                throw tagError
            } else {
                let createError = TagCreationError.creationFailed("タグの作成に失敗しました")
                errorMessage = createError.errorDescription
                throw createError
            }
        }
    }
    
    // MARK: - Tag Filtering and Sorting
    
    func filterTags(_ tags: [TaskTag], searchText: String) -> [TaskTag] {
        if searchText.isEmpty {
            return tags.sorted { $0.usageCount > $1.usageCount }
        }
        return tags.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.usageCount > $1.usageCount }
    }
    
    func sortTagsByUsage(_ tags: [TaskTag]) -> [TaskTag] {
        return tags.sorted { lhs, rhs in
            if lhs.usageCount == rhs.usageCount {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.usageCount > rhs.usageCount
        }
    }
    
    // MARK: - Tag Selection Management
    
    func toggleTagSelection(_ tagName: String, in selectedTags: inout [String]) {
        if let index = selectedTags.firstIndex(of: tagName) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tagName)
        }
    }
    
    func removeTagFromSelection(_ tagName: String, from selectedTags: inout [String]) {
        selectedTags.removeAll { $0 == tagName }
    }
    
    func addTagToSelection(_ tagName: String, to selectedTags: inout [String]) {
        if !selectedTags.contains(tagName) {
            selectedTags.append(tagName)
        }
    }
}

// MARK: - Tag Error Handling

enum TagCreationError: LocalizedError {
    case invalidInput(String)
    case creationFailed(String)
    case networkError(String)
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return message
        case .creationFailed(let message):
            return message
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .permissionDenied:
            return "タグ作成の権限がありません"
        }
    }
}