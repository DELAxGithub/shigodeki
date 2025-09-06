//
//  TagCRUDService.swift
//  shigodeki
//
//  Extracted from TagManager.swift for CLAUDE.md compliance
//  Tag creation, update, and deletion operations
//

import Foundation
import FirebaseFirestore

@MainActor
class TagCRUDService: ObservableObject {
    private let db = Firestore.firestore()
    
    // MARK: - Helper Methods
    
    private func getTagCollection(projectId: String) -> CollectionReference {
        return db.collection("projects").document(projectId).collection("tags")
    }
    
    // MARK: - CRUD Operations
    
    func createTag(name: String, color: String? = nil, emoji: String? = nil, projectId: String, createdBy: String) async throws -> String {
        // 🚨 クラッシュ対策: IDが空文字の場合、Firestoreがクラッシュするため早期リターン
        guard !projectId.isEmpty else {
            throw TagCRUDError.invalidData
        }

        defer { }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw TagCRUDError.invalidName
        }
        
        // チェック: 同名のタグが存在するか
        let tagsCollection = getTagCollection(projectId: projectId)
        let existingQuery = try await tagsCollection.whereField("name", isEqualTo: trimmedName).getDocuments()
        
        if !existingQuery.documents.isEmpty {
            throw TagCRUDError.duplicateName
        }
        
        let tag = TaskTag(
            name: trimmedName,
            color: color ?? "#007AFF",
            emoji: emoji,
            projectId: projectId,
            createdBy: createdBy
        )
        
        let tagData: [String: Any] = [
            "name": tag.name,
            "color": tag.color,
            "emoji": tag.emoji ?? "",
            "projectId": tag.projectId,
            "createdBy": tag.createdBy,
            "createdAt": FieldValue.serverTimestamp(),
            "usageCount": tag.usageCount,
            "lastUsed": NSNull()
        ]
        
        do {
            let docRef = try await tagsCollection.addDocument(data: tagData)
            print("Tag created successfully with ID: \(docRef.documentID)")
            return docRef.documentID
        } catch {
            print("Error creating tag: \(error)")
            throw TagCRUDError.creationFailed(error.localizedDescription)
        }
    }
    
    func updateTag(_ tag: TaskTag, name: String? = nil, color: String? = nil, emoji: String? = nil) async throws {
        guard !tag.projectId.isEmpty else {
            throw TagCRUDError.invalidData
        }
        
        let tagsCollection = getTagCollection(projectId: tag.projectId)
        guard let tagId = tag.id else {
            throw TagCRUDError.notFound
        }
        
        var updateData: [String: Any] = [:]
        
        if let newName = name?.trimmingCharacters(in: .whitespacesAndNewlines), !newName.isEmpty, newName != tag.name {
            // Check for duplicate names
            let existingQuery = try await tagsCollection.whereField("name", isEqualTo: newName).getDocuments()
            let duplicates = existingQuery.documents.filter { $0.documentID != tagId }
            
            if !duplicates.isEmpty {
                throw TagCRUDError.duplicateName
            }
            updateData["name"] = newName
        }
        
        if let newColor = color, !newColor.isEmpty, newColor != tag.color {
            updateData["color"] = newColor
        }
        
        if let newEmoji = emoji, newEmoji != tag.emoji {
            updateData["emoji"] = newEmoji
        }
        
        guard !updateData.isEmpty else {
            return // 更新する内容がない
        }
        
        do {
            try await tagsCollection.document(tagId).updateData(updateData)
            print("Tag updated successfully")
        } catch {
            print("Error updating tag: \(error)")
            throw TagCRUDError.updateFailed(error.localizedDescription)
        }
    }
    
    func deleteTag(_ tag: TaskTag) async throws {
        guard !tag.projectId.isEmpty else {
            throw TagCRUDError.invalidData
        }
        
        guard let tagId = tag.id else {
            throw TagCRUDError.notFound
        }
        
        let tagsCollection = getTagCollection(projectId: tag.projectId)
        
        do {
            // Remove tag from all tasks first
            try await removeTagFromAllTasks(tagName: tag.name, projectId: tag.projectId)
            
            // Then delete the tag document
            try await tagsCollection.document(tagId).delete()
            print("Tag deleted successfully")
        } catch {
            print("Error deleting tag: \(error)")
            throw TagCRUDError.deletionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods
    
    private func removeTagFromAllTasks(tagName: String, projectId: String) async throws {
        let tasksQuery = db.collectionGroup("tasks")
            .whereField("tags", arrayContains: tagName)
        
        let snapshot = try await tasksQuery.getDocuments()
        
        for document in snapshot.documents {
            var tags = document.data()["tags"] as? [String] ?? []
            tags.removeAll { $0 == tagName }
            
            try await document.reference.updateData([
                "tags": tags
            ])
        }
    }
}

// MARK: - Error Types

enum TagCRUDError: LocalizedError {
    case invalidName
    case invalidData
    case duplicateName
    case creationFailed(String)
    case updateFailed(String)
    case deletionFailed(String)
    case notFound
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "タグ名が無効です"
        case .invalidData:
            return "無効なデータです"
        case .duplicateName:
            return "同名のタグが既に存在します"
        case .creationFailed(let message):
            return "タグの作成に失敗しました: \(message)"
        case .updateFailed(let message):
            return "タグの更新に失敗しました: \(message)"
        case .deletionFailed(let message):
            return "タグの削除に失敗しました: \(message)"
        case .notFound:
            return "タグが見つかりません"
        case .permissionDenied:
            return "この操作の権限がありません"
        }
    }
}