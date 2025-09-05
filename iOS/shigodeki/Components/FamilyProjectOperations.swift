//
//  FamilyProjectOperations.swift
//  shigodeki
//
//  Extracted from FamilyDetailView.swift for better code organization
//  Handles family project loading and invite code management
//

import SwiftUI
import FirebaseFirestore

@MainActor 
class FamilyProjectOperations: ObservableObject {
    private let projectManager: ProjectManager
    private let familyManager: FamilyManager
    
    @Published var familyProjects: [Project] = []
    @Published var currentInviteCode: String = ""
    
    init(projectManager: ProjectManager, familyManager: FamilyManager) {
        self.projectManager = projectManager
        self.familyManager = familyManager
    }
    
    func updateManagers(projectManager: ProjectManager, familyManager: FamilyManager) {
        // Note: In a production app, you'd want to implement proper manager updating
        // For now, this is a placeholder to satisfy the interface
    }
    
    func loadFamilyProjects(family: Family) {
        Task {
            do {
                // Get projects for the family members
                var allProjects: [Project] = []
                for memberId in family.members {
                    let memberProjects = try await projectManager.getUserProjects(userId: memberId)
                    allProjects.append(contentsOf: memberProjects)
                }
                
                // Remove duplicates and filter for family projects
                familyProjects = Array(Set(allProjects))
            } catch {
                print("❌ Error loading family projects: \(error)")
                familyProjects = []
            }
        }
    }
    
    func loadInviteCode(family: Family) {
        Task {
            // Generate a simple invite code for demo purposes
            // In a production app, this would use proper invite code generation
            let inviteCode = "INV-\(family.id?.prefix(6).uppercased() ?? "UNKNOWN")"
            currentInviteCode = inviteCode
            print("✅ Generated invite code: \(inviteCode)")
        }
    }
    
    func leaveFamily(_ family: Family, currentUserId: String) async throws {
        try await familyManager.leaveFamily(familyId: family.id ?? "", userId: currentUserId)
    }
}