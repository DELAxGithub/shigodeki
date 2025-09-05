//
//  ProjectValidationHelpers.swift
//  shigodeki
//
//  Extracted from ProjectManager.swift for better code organization
//

import Foundation
import FirebaseFirestore

/// Handles project validation and synchronization utilities
@MainActor
class ProjectValidationHelpers: ObservableObject {
    @Published var error: FirebaseError?
    
    private let projectOperations = FirebaseOperationBase<Project>(collectionPath: "projects")
    
    // MARK: - Validation Helpers
    
    func validateProjectHierarchy(project: Project) async throws {
        guard let projectId = project.id, !projectId.isEmpty else {
            throw FirebaseError.operationFailed("Project ID is required for hierarchy validation")
        }
        
        let phaseManager = PhaseManager()
        do {
            let phases = try await phaseManager.getPhases(projectId: projectId)
            try ModelRelationships.validateProjectHierarchy(project: project, phases: phases)
        } catch {
            throw FirebaseError.from(error)
        }
    }
    
    // MARK: - Synchronization Helpers
    
    /// Waits for a newly created project's data to be synchronized back to the local `projects` array.
    /// This prevents UI glitches where a new project disappears briefly after creation.
    /// - Parameter projectId: The ID of the project to wait for.
    func waitForDataSynchronization(projectId: String, currentProjects: [Project]) async throws {
        guard !projectId.isEmpty else { return }
        
        let timeout = 2.0 // seconds
        let interval: UInt64 = 100_000_000 // 100ms in nanoseconds
        let startTime = Date()
        
        print("⏳ Waiting for project \(projectId) to synchronize...")
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Check if the project exists in the local @Published array
            if currentProjects.contains(where: { $0.id == projectId }) {
                // Additionally, check if its statistics have been populated
                if let project = currentProjects.first(where: { $0.id == projectId }), project.statistics != nil, project.statistics!.totalTasks > 0 {
                    let duration = Date().timeIntervalSince(startTime)
                    print("✅ Project \(projectId) synchronized successfully in \(String(format: "%.2f", duration))s.")
                    return
                }
            }
            try await Task.sleep(nanoseconds: interval)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        print("⚠️ Synchronization timed out for project \(projectId) after \(String(format: "%.2f", duration))s. Proceeding anyway.")
    }
    
    // MARK: - Statistics Updates
    
    func updateProjectStatistics(projectId: String, stats: ProjectStats) async throws {
        guard var project = try await projectOperations.read(id: projectId) else {
            throw FirebaseError.documentNotFound
        }
        
        project.statistics = stats
        project.lastModifiedAt = Date()
        
        _ = try await updateProject(project)
    }
    
    // MARK: - Helper Methods
    
    private func updateProject(_ project: Project) async throws -> Project {
        try project.validate()
        return try await projectOperations.update(project)
    }
}