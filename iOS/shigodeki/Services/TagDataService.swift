//
//  TagDataService.swift
//  shigodeki
//
//  Extracted from TagManager.swift for CLAUDE.md compliance
//  Tag data loading and real-time synchronization
//

import Foundation
import FirebaseFirestore

@MainActor
class TagDataService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var tagsListener: ListenerRegistration?
    private let listenerQueue = DispatchQueue(label: "com.shigodeki.tagDataService.listeners", qos: .userInteractive)
    
    // MARK: - Lifecycle
    
    deinit {
        tagsListener?.remove()
        tagsListener = nil
    }
    
    func stopListening() {
        tagsListener?.remove()
        tagsListener = nil
    }
    
    // MARK: - Helper Methods
    
    private func getTagCollection(projectId: String) -> CollectionReference {
        return db.collection("projects").document(projectId).collection("tags")
    }
    
    // MARK: - Data Loading
    
    func loadTags(projectId: String) async -> [TaskTag] {
        guard !projectId.isEmpty else {
            errorMessage = "Invalid project ID"
            return []
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let snapshot = try await getTagCollection(projectId: projectId)
                .order(by: "usageCount", descending: true)
                .order(by: "name")
                .getDocuments()
            
            var loadedTags: [TaskTag] = []
            
            for document in snapshot.documents {
                if let tag = parseTaskTag(from: document) {
                    loadedTags.append(tag)
                }
            }
            
            return loadedTags
            
        } catch {
            print("Error loading tags: \(error)")
            errorMessage = "タグの読み込みに失敗しました"
            return []
        }
    }
    
    func startListening(projectId: String, onUpdate: @escaping ([TaskTag]) -> Void) {
        guard !projectId.isEmpty else {
            errorMessage = "Invalid project ID"
            return
        }
        
        // Stop existing listener
        stopListening()
        
        let tagsCollection = getTagCollection(projectId: projectId)
        
        tagsListener = tagsCollection
            .order(by: "usageCount", descending: true)
            .order(by: "name")
            .addSnapshotListener { [weak self] querySnapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Tags listener error: \(error)")
                        self.errorMessage = "タグの同期中にエラーが発生しました"
                        
                        // Start fallback polling
                        self.startFallbackListening(projectId: projectId, onUpdate: onUpdate)
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else { return }
                    
                    var updatedTags: [TaskTag] = []
                    for document in documents {
                        if let tag = self.parseTaskTag(from: document) {
                            updatedTags.append(tag)
                        }
                    }
                    
                    onUpdate(updatedTags)
                }
            }
    }
    
    private func startFallbackListening(projectId: String, onUpdate: @escaping ([TaskTag]) -> Void) {
        // Implement polling fallback
        Task {
            while tagsListener != nil {
                let tags = await loadTags(projectId: projectId)
                onUpdate(tags)
                
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }
    }
    
    // MARK: - Data Parsing
    
    private func parseTaskTag(from document: QueryDocumentSnapshot) -> TaskTag? {
        let data = document.data()
        
        guard let name = data["name"] as? String,
              let color = data["color"] as? String,
              let projectId = data["projectId"] as? String,
              let createdBy = data["createdBy"] as? String else {
            return nil
        }
        
        let emoji = data["emoji"] as? String
        let usageCount = data["usageCount"] as? Int ?? 0
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        
        var tag = TaskTag(
            name: name,
            color: color,
            emoji: emoji?.isEmpty == true ? nil : emoji,
            projectId: projectId,
            createdBy: createdBy
        )
        
        tag.id = document.documentID
        tag.usageCount = usageCount
        tag.createdAt = createdAt
        
        return tag
    }
    
    // MARK: - Utility Methods
    
    func getTag(name: String, from tags: [TaskTag]) -> TaskTag? {
        return tags.first { $0.name.lowercased() == name.lowercased() }
    }
}