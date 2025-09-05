//
//  ProjectCreationHelpers.swift
//  shigodeki
//
//  Extracted from ProjectManager.swift for better code organization
//

import Foundation
import FirebaseAuth

/// Handles project creation utilities and debugging
@MainActor
class ProjectCreationHelpers: ObservableObject {
    
    // MARK: - Authentication Debugging
    
    static func debugFirebaseAuthState() async throws {
        print("🔍 Firebase Auth Debug before Firestore create:")
        if let currentUser = Auth.auth().currentUser {
            print("   Firebase Auth UID: \(currentUser.uid)")
            print("   Firebase Auth isAnonymous: \(currentUser.isAnonymous)")
            print("   Firebase Auth providerData count: \(currentUser.providerData.count)")
            
            // Get auth token to verify it's valid
            do {
                let token = try await currentUser.getIDToken()
                print("   Auth token obtained: \(token.prefix(20))...")
                
                // Force refresh token for TestFlight reliability
                let freshToken = try await currentUser.getIDToken(forcingRefresh: true)
                print("   Fresh auth token obtained: \(freshToken.prefix(20))...")
            } catch {
                print("❌ Failed to get auth token: \(error)")
                throw FirebaseError.operationFailed("認証トークンの取得に失敗しました。再度サインインしてください。")
            }
        } else {
            print("❌ No Firebase Auth currentUser found")
        }
    }
    
    // MARK: - Optimistic UI Helpers
    
    static func createOptimisticProject(name: String, description: String?, ownerId: String, ownerType: ProjectOwnerType) -> (project: Project, temporaryId: String) {
        var optimisticProject = Project(name: name, description: description, ownerId: ownerId, ownerType: ownerType)
        let temporaryId = optimisticProject.id ?? UUID().uuidString
        optimisticProject.id = temporaryId
        print("📝 Creating optimistic project object with temporary ID: \(temporaryId)")
        return (optimisticProject, temporaryId)
    }
    
    static func replaceOptimisticProject(in projects: inout [Project], temporaryId: String, with createdProject: Project) {
        if let index = projects.firstIndex(where: { $0.id == temporaryId }) {
            projects[index] = createdProject
            print("🔄 Replaced optimistic project with real project ID: \(createdProject.id ?? "NO_ID")")
        }
    }
    
    static func rollbackOptimisticProject(from projects: inout [Project], temporaryId: String) {
        projects.removeAll { $0.id == temporaryId }
        print("🔄 Rolled back optimistic UI update")
    }
}