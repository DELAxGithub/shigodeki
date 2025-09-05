//
//  TagManager.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class TagManager: ObservableObject {
    @Published var tags: [TaskTag] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var tagsListener: ListenerRegistration?
    private let listenerQueue = DispatchQueue(label: "com.shigodeki.tagManager.listeners", qos: .userInteractive)
    
    // MARK: - Lifecycle
    
    deinit {
        tagsListener?.remove()
        tagsListener = nil
    }
    
    func stopListening() {
        tagsListener?.remove()
        tagsListener = nil
    }
    
    // MARK: - Tag CRUD Operations
    
    func createTag(name: String, color: String? = nil, emoji: String? = nil, familyId: String, createdBy: String) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw TagError.invalidName
        }
        
        // Check for duplicate names in the same family
        if tags.contains(where: { $0.name.lowercased() == trimmedName.lowercased() && $0.familyId == familyId }) {
            throw TagError.duplicateName
        }
        
        let tag = TaskTag(
            name: trimmedName,
            color: color ?? TaskTag.randomColor(),
            emoji: emoji,
            familyId: familyId,
            createdBy: createdBy
        )
        
        let tagData = tag.toFirestoreData()
        
        do {
            let tagRef = try await db.collection("families").document(familyId)
                .collection("tagMasters").addDocument(data: tagData)
            
            print("Tag created successfully with ID: \(tagRef.documentID)")
            return tagRef.documentID
            
        } catch {
            print("Error creating tag: \(error)")
            errorMessage = "タグの作成に失敗しました"
            throw TagError.creationFailed(error.localizedDescription)
        }
    }
    
    func updateTag(_ tag: TaskTag, name: String? = nil, color: String? = nil, emoji: String? = nil) async throws {
        guard let tagId = tag.id, let familyId = tag.familyId as String? else {
            throw TagError.notFound
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        var updateData: [String: Any] = [:]
        
        if let newName = name {
            let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                throw TagError.invalidName
            }
            
            // Check for duplicate names (excluding current tag)
            if tags.contains(where: { $0.name.lowercased() == trimmedName.lowercased() && $0.familyId == familyId && $0.id != tagId }) {
                throw TagError.duplicateName
            }
            
            updateData["name"] = trimmedName
        }
        
        if let newColor = color {
            updateData["color"] = newColor
        }
        
        if let newEmoji = emoji {
            updateData["emoji"] = newEmoji
        }
        
        // Update displayName only when name or emoji changes
        // Only update if we're actually changing name or emoji to prevent duplication
        if name != nil || emoji != nil {
            let finalName = name ?? tag.name
            let finalEmoji = emoji ?? tag.emoji
            // Generate new displayName based on the updated values
            updateData["displayName"] = finalEmoji != nil ? "\(finalEmoji!) \(finalName)" : finalName
        }
        
        guard !updateData.isEmpty else { return }
        
        do {
            try await db.collection("families").document(familyId)
                .collection("tagMasters").document(tagId)
                .updateData(updateData)
            
            print("Tag updated successfully")
            
        } catch {
            print("Error updating tag: \(error)")
            errorMessage = "タグの更新に失敗しました"
            throw TagError.updateFailed(error.localizedDescription)
        }
    }
    
    func deleteTag(_ tag: TaskTag) async throws {
        guard let tagId = tag.id, let familyId = tag.familyId as String? else {
            throw TagError.notFound
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            // Remove tag from all tasks that use it
            if tag.usageCount > 0 {
                try await removeTagFromAllTasks(tagName: tag.name, familyId: familyId)
            }
            
            // Delete the tag master
            try await db.collection("families").document(familyId)
                .collection("tagMasters").document(tagId)
                .delete()
            
            print("Tag deleted successfully")
            
        } catch {
            print("Error deleting tag: \(error)")
            errorMessage = "タグの削除に失敗しました"
            throw TagError.deletionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Usage Tracking
    
    func incrementUsage(for tagName: String, familyId: String) async {
        guard let tag = tags.first(where: { $0.name == tagName && $0.familyId == familyId }),
              let tagId = tag.id else {
            return
        }
        
        let updateData: [String: Any] = [
            "usageCount": FieldValue.increment(Int64(1)),
            "lastUsedAt": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("families").document(familyId)
                .collection("tagMasters").document(tagId)
                .updateData(updateData)
        } catch {
            print("Error incrementing tag usage: \(error)")
        }
    }
    
    func decrementUsage(for tagName: String, familyId: String) async {
        guard let tag = tags.first(where: { $0.name == tagName && $0.familyId == familyId }),
              let tagId = tag.id,
              tag.usageCount > 0 else {
            return
        }
        
        let updateData: [String: Any] = [
            "usageCount": FieldValue.increment(Int64(-1))
        ]
        
        do {
            try await db.collection("families").document(familyId)
                .collection("tagMasters").document(tagId)
                .updateData(updateData)
        } catch {
            print("Error decrementing tag usage: \(error)")
        }
    }
    
    func updateUsageCounts(familyId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get all tasks for the family
            let tasksSnapshot = try await db.collectionGroup("tasks")
                .whereField("projectId", in: await getProjectIds(familyId: familyId))
                .getDocuments()
            
            // Count tag usage
            var tagUsage: [String: Int] = [:]
            
            for document in tasksSnapshot.documents {
                if let tags = document.data()["tags"] as? [String] {
                    for tag in tags {
                        tagUsage[tag, default: 0] += 1
                    }
                }
            }
            
            // Update tag masters with actual usage counts
            for tag in self.tags.filter({ $0.familyId == familyId }) {
                guard let tagId = tag.id else { continue }
                
                let actualCount = tagUsage[tag.name] ?? 0
                if actualCount != tag.usageCount {
                    try await db.collection("families").document(familyId)
                        .collection("tagMasters").document(tagId)
                        .updateData(["usageCount": actualCount])
                }
            }
            
        } catch {
            print("Error updating tag usage counts: \(error)")
        }
    }
    
    // MARK: - Data Loading
    
    func loadTags(familyId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Try the optimized query first (requires composite index)
            let tagsSnapshot = try await db.collection("families").document(familyId)
                .collection("tagMasters")
                .order(by: "usageCount", descending: true)
                .order(by: "name")
                .getDocuments()
            
            var loadedTags: [TaskTag] = []
            
            for document in tagsSnapshot.documents {
                if let tag = TaskTag.fromFirestoreData(document.data(), documentId: document.documentID) {
                    loadedTags.append(tag)
                }
            }
            
            tags = loadedTags
            
        } catch {
            print("Error loading tags with composite index: \(error)")
            
            // Fallback to simple query without ordering if composite index doesn't exist
            do {
                print("Attempting fallback query without ordering...")
                let tagsSnapshot = try await db.collection("families").document(familyId)
                    .collection("tagMasters")
                    .getDocuments()
                
                var loadedTags: [TaskTag] = []
                
                for document in tagsSnapshot.documents {
                    if let tag = TaskTag.fromFirestoreData(document.data(), documentId: document.documentID) {
                        loadedTags.append(tag)
                    }
                }
                
                // Sort locally if Firestore sorting failed
                tags = loadedTags.sorted { tag1, tag2 in
                    if tag1.usageCount == tag2.usageCount {
                        return tag1.name < tag2.name
                    }
                    return tag1.usageCount > tag2.usageCount
                }
                
                print("Fallback query succeeded. Please create the composite index for better performance.")
                
            } catch {
                print("Error with fallback query: \(error)")
                errorMessage = "タグの読み込みに失敗しました。インデックスの作成が必要です。"
            }
        }
        
        isLoading = false
    }
    
    func startListening(familyId: String) {
        stopListening()
        
        // Try composite index query first
        tagsListener = db.collection("families").document(familyId)
            .collection("tagMasters")
            .order(by: "usageCount", descending: true)
            .order(by: "name")
            .addSnapshotListener { [weak self] querySnapshot, error in
                
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error listening to tags with composite index: \(error)")
                        
                        // Try fallback listener without ordering
                        self.startFallbackListening(familyId: familyId)
                        return
                    }
                    
                    guard let snapshot = querySnapshot else { return }
                    
                    var updatedTags: [TaskTag] = []
                    
                    for document in snapshot.documents {
                        if let tag = TaskTag.fromFirestoreData(document.data(), documentId: document.documentID) {
                            updatedTags.append(tag)
                        }
                    }
                    
                    self.tags = updatedTags
                }
            }
    }
    
    private func startFallbackListening(familyId: String) {
        stopListening()
        
        print("Starting fallback listener without ordering...")
        tagsListener = db.collection("families").document(familyId)
            .collection("tagMasters")
            .addSnapshotListener { [weak self] querySnapshot, error in
                
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error with fallback listener: \(error)")
                        self.errorMessage = "タグの同期に失敗しました"
                        return
                    }
                    
                    guard let snapshot = querySnapshot else { return }
                    
                    var updatedTags: [TaskTag] = []
                    
                    for document in snapshot.documents {
                        if let tag = TaskTag.fromFirestoreData(document.data(), documentId: document.documentID) {
                            updatedTags.append(tag)
                        }
                    }
                    
                    // Sort locally
                    self.tags = updatedTags.sorted { tag1, tag2 in
                        if tag1.usageCount == tag2.usageCount {
                            return tag1.name < tag2.name
                        }
                        return tag1.usageCount > tag2.usageCount
                    }
                }
            }
    }
    
    // MARK: - Helper Methods
    
    private func removeTagFromAllTasks(tagName: String, familyId: String) async throws {
        let projectIds = try await getProjectIds(familyId: familyId)
        
        // Query all tasks that contain this tag
        let tasksSnapshot = try await db.collectionGroup("tasks")
            .whereField("projectId", in: projectIds)
            .whereField("tags", arrayContains: tagName)
            .getDocuments()
        
        // Remove tag from each task
        let batch = db.batch()
        
        for document in tasksSnapshot.documents {
            let taskRef = document.reference
            batch.updateData(["tags": FieldValue.arrayRemove([tagName])], forDocument: taskRef)
        }
        
        try await batch.commit()
    }
    
    private func getProjectIds(familyId: String) async throws -> [String] {
        let projectsSnapshot = try await db.collection("families").document(familyId)
            .collection("projects")
            .getDocuments()
        
        return projectsSnapshot.documents.map { $0.documentID }
    }
    
    // MARK: - Utility Methods
    
    func getTagsForFamily(_ familyId: String) -> [TaskTag] {
        return tags.filter { $0.familyId == familyId }
    }
    
    func getTag(name: String, familyId: String) -> TaskTag? {
        return tags.first { $0.name == name && $0.familyId == familyId }
    }
    
    func getUnusedTags(familyId: String) -> [TaskTag] {
        return tags.filter { $0.familyId == familyId && $0.isUnused }
    }
    
    func cleanupUnusedTags(familyId: String) async throws {
        let unusedTags = getUnusedTags(familyId: familyId)
        
        for tag in unusedTags {
            try await deleteTag(tag)
        }
    }
}