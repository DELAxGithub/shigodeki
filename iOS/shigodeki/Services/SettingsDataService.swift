//
//  SettingsDataService.swift
//  shigodeki
//
//  Extracted from MainTabView.swift for CLAUDE.md compliance
//  Settings data loading and user management service
//

import Foundation

@MainActor
class SettingsDataService: ObservableObject {
    @Published var authManager: AuthenticationManager?
    @Published var taskListManager: TaskListManager?
    @Published var aiGenerator: AITaskGenerator?
    @Published var isUpdatingUsername = false
    
    private let sharedManagers: SharedManagerStore
    
    init(sharedManagers: SharedManagerStore) {
        self.sharedManagers = sharedManagers
    }
    
    // MARK: - Initialization
    
    func initializeManagers() async {
        authManager = await sharedManagers.getAuthManager()
        taskListManager = await sharedManagers.getTaskListManager()
        aiGenerator = await sharedManagers.getAiGenerator()
        
        // Load tasks for improvement suggestions when settings appear
        if let userId = authManager?.currentUser?.id {
            await loadUserTasks(userId: userId)
        }
    }
    
    // MARK: - User Management
    
    func updateUsername(_ newUsername: String) async {
        guard let authManager = authManager else { return }
        
        isUpdatingUsername = true
        await authManager.updateUserName(newUsername)
        isUpdatingUsername = false
    }
    
    // MARK: - Task Loading
    
    private func loadUserTasks(userId: String) async {
        let familyManager = await sharedManagers.getFamilyManager()
        await familyManager.loadFamiliesForUser(userId: userId)
        
        let families = familyManager.families
        
        for family in families {
            if let familyId = family.id, let taskListManager = taskListManager {
                do {
                    let taskLists = try await taskListManager.getTaskLists(familyId: familyId)
                    print("✅ Loaded \(taskLists.count) task lists for AI improvement analysis")
                } catch {
                    print("❌ Failed to load task lists for family \(familyId): \(error)")
                }
            }
        }
    }
}