//
//  TagUsageService.swift
//  shigodeki
//
//  Extracted from TagManager.swift for CLAUDE.md compliance
//  Tag usage tracking and analytics
//

import Foundation
import FirebaseFirestore

@MainActor
class TagUsageService: ObservableObject {
    private let db = Firestore.firestore()
    
    // MARK: - Helper Methods
    
    private func getTagCollection(projectId: String) -> CollectionReference {
        return db.collection("projects").document(projectId).collection("tags")
    }
    
    // MARK: - Usage Tracking
    
    func incrementUsage(for tagName: String, projectId: String) async {
        guard !projectId.isEmpty, !tagName.isEmpty else { return }
        
        do {
            let tagsCollection = getTagCollection(projectId: projectId)
            let query = try await tagsCollection.whereField("name", isEqualTo: tagName).getDocuments()
            
            if let document = query.documents.first {
                try await document.reference.updateData([
                    "usageCount": FieldValue.increment(Int64(1)),
                    "lastUsed": FieldValue.serverTimestamp()
                ])
            }
        } catch {
            print("Error incrementing tag usage: \(error)")
        }
    }
    
    func decrementUsage(for tagName: String, projectId: String) async {
        guard !projectId.isEmpty, !tagName.isEmpty else { return }
        
        do {
            let tagsCollection = getTagCollection(projectId: projectId)
            let query = try await tagsCollection.whereField("name", isEqualTo: tagName).getDocuments()
            
            if let document = query.documents.first {
                let currentCount = document.data()["usageCount"] as? Int ?? 0
                let newCount = max(0, currentCount - 1)
                
                try await document.reference.updateData([
                    "usageCount": newCount
                ])
            }
        } catch {
            print("Error decrementing tag usage: \(error)")
        }
    }
    
    func updateUsageCounts(projectId: String) async {
        guard !projectId.isEmpty else { return }
        
        do {
            // Get all tags for this project
            let tagsSnapshot = try await getTagCollection(projectId: projectId).getDocuments()
            
            for tagDoc in tagsSnapshot.documents {
                let tagName = tagDoc.data()["name"] as? String ?? ""
                if tagName.isEmpty { continue }
                
                // Count usage in tasks
                let tasksQuery = db.collectionGroup("tasks")
                    .whereField("tags", arrayContains: tagName)
                let tasksSnapshot = try await tasksQuery.getDocuments()
                let actualCount = tasksSnapshot.documents.count
                
                // Update the usage count
                try await tagDoc.reference.updateData([
                    "usageCount": actualCount
                ])
                
                print("Updated usage count for tag '\(tagName)': \(actualCount)")
            }
        } catch {
            print("Error updating usage counts: \(error)")
        }
    }
    
    // MARK: - Analytics and Utilities
    
    func getUnusedTags(from tags: [TaskTag]) -> [TaskTag] {
        return tags.filter { $0.usageCount == 0 }
    }
    
    func cleanupUnusedTags(projectId: String, tags: [TaskTag]) async throws {
        let unusedTags = getUnusedTags(from: tags)
        
        for tag in unusedTags {
            guard let tagId = tag.id else { continue }
            
            do {
                try await getTagCollection(projectId: projectId).document(tagId).delete()
                print("Deleted unused tag: \(tag.name)")
            } catch {
                print("Error deleting unused tag \(tag.name): \(error)")
                throw TagCRUDError.deletionFailed(error.localizedDescription)
            }
        }
    }
}