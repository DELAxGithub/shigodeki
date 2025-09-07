//
//  TagManager.swift
//  shigodeki
//
//  Refactored for CLAUDE.md compliance - Lightweight coordinator
//  Services extracted to TagCRUDService.swift, TagUsageService.swift, TagDataService.swift
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class TagManager: ObservableObject {
    @Published var tags: [TaskTag] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Service Dependencies
    
    private let crudService = TagCRUDService()
    private let usageService = TagUsageService()
    private let dataService = TagDataService()
    
    // MARK: - Lifecycle
    
    deinit {
        // Fix memory leak: Stop listening synchronously in deinit to avoid retain cycles
        dataService.stopListening()
    }
    
    func stopListening() {
        dataService.stopListening()
    }
    
    // MARK: - State Management
    
    private func updateLoadingState() {
        isLoading = dataService.isLoading
        errorMessage = dataService.errorMessage
    }
    
    // MARK: - Tag CRUD Operations
    
    func createTag(name: String, color: String? = nil, emoji: String? = nil, projectId: String, createdBy: String) async throws -> String {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let tagId = try await crudService.createTag(
                name: name,
                color: color,
                emoji: emoji,
                projectId: projectId,
                createdBy: createdBy
            )
            return tagId
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func updateTag(_ tag: TaskTag, name: String? = nil, color: String? = nil, emoji: String? = nil) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await crudService.updateTag(tag, name: name, color: color, emoji: emoji)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func deleteTag(_ tag: TaskTag) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await crudService.deleteTag(tag)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Usage Tracking
    
    func incrementUsage(for tagName: String, projectId: String) async {
        await usageService.incrementUsage(for: tagName, projectId: projectId)
    }
    
    func decrementUsage(for tagName: String, projectId: String) async {
        await usageService.decrementUsage(for: tagName, projectId: projectId)
    }
    
    func updateUsageCounts(projectId: String) async {
        await usageService.updateUsageCounts(projectId: projectId)
    }
    
    // MARK: - Data Loading
    
    func loadTags(projectId: String) async {
        isLoading = true
        errorMessage = nil
        
        let loadedTags = await dataService.loadTags(projectId: projectId)
        
        tags = loadedTags
        updateLoadingState()
    }
    
    func startListening(projectId: String) {
        dataService.startListening(projectId: projectId) { [weak self] updatedTags in
            Task { @MainActor in
                self?.tags = updatedTags
                self?.updateLoadingState()
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func getTagsForProject(_ projectId: String) -> [TaskTag] {
        return tags.filter { $0.projectId == projectId }
    }
    
    func getTag(name: String, projectId: String) -> TaskTag? {
        return dataService.getTag(name: name, from: getTagsForProject(projectId))
    }
    
    func getUnusedTags(projectId: String) -> [TaskTag] {
        let projectTags = getTagsForProject(projectId)
        return usageService.getUnusedTags(from: projectTags)
    }
    
    func cleanupUnusedTags(projectId: String) async throws {
        let projectTags = getTagsForProject(projectId)
        
        do {
            try await usageService.cleanupUnusedTags(projectId: projectId, tags: projectTags)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}