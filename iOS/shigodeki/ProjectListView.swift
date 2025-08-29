//
//  ProjectListView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

struct ProjectListView: View {
    @StateObject private var projectManager = ProjectManager()
    @StateObject private var authManager = AuthenticationManager()
    @State private var showingCreateProject = false
    @State private var selectedProject: Project?
    
    var body: some View {
        NavigationView {
            VStack {
                if projectManager.projects.isEmpty && !projectManager.isLoading {
                    ProjectEmptyStateView {
                        showingCreateProject = true
                    }
                    
                } else {
                    List {
                        ForEach(projectManager.projects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project, projectManager: projectManager)) {
                                ProjectRowView(project: project)
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: deleteProjects)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        if let userId = authManager.currentUser?.id {
                            Task {
                                do {
                                    _ = try await projectManager.getUserProjects(userId: userId)
                                } catch {
                                    print("❌ ProjectListView: Refresh error: \(error)")
                                }
                            }
                        }
                    }
                    .onMemoryWarning {
                        // Clear any local caches on memory warning
                        CacheManager.shared.clearAll()
                    }
                }
                
                // Loading states with better feedback
                if authManager.isLoading {
                    LoadingStateView(message: "認証中...")
                        .padding()
                } else if isWaitingForAuth {
                    LoadingStateView(message: "ユーザー情報を取得中...")
                        .padding()
                } else if projectManager.isLoading {
                    LoadingStateView(message: "プロジェクトを読み込み中...")
                        .padding()
                }
            }
            .navigationTitle("プロジェクト")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreateProject = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                print("📱 ProjectListView: onAppear triggered")
                loadUserProjects()
            }
            .onReceive(authManager.$isAuthenticated) { isAuthenticated in
                print("📱 ProjectListView: Authentication state changed: \(isAuthenticated)")
                if isAuthenticated {
                    print("🔄 ProjectListView: User authenticated, loading projects")
                    retryCount = 0 // Reset retry count on auth state change
                    loadUserProjects()
                } else {
                    // Reset states when user signs out
                    retryCount = 0
                    isWaitingForAuth = false
                }
            }
            .onDisappear {
                print("👋 ProjectListView: Disappearing, cleaning up listeners")
                projectManager.removeAllListeners()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                print("🔚 ProjectListView: App terminating, cleaning up")
                projectManager.removeAllListeners()
            }
            .sheet(isPresented: $showingCreateProject) {
                CreateProjectView(projectManager: projectManager)
            }
            .alert("エラー", isPresented: Binding(
                get: { projectManager.error != nil },
                set: { _ in projectManager.error = nil }
            )) {
                Button("OK") {
                    projectManager.error = nil
                }
            } message: {
                if let error = projectManager.error {
                    Text(error.localizedDescription)
                } else {
                    Text("不明なエラーが発生しました")
                }
            }
        }
    }
    
    @State private var retryCount = 0
    @State private var isWaitingForAuth = false
    private let maxRetries = 3  // Reduced from 5 to 3
    
    private func loadUserProjects() {
        print("📱 ProjectListView: loadUserProjects called (attempt \(retryCount + 1))")
        
        guard let userId = authManager.currentUserId else {
            // If user is authenticated but userId is nil, wait briefly
            if authManager.isAuthenticated && retryCount < maxRetries {
                isWaitingForAuth = true
                let delay = exponentialBackoffDelay(for: retryCount)
                print("⏳ ProjectListView: User authenticated but ID loading, retry in \(String(format: "%.1f", delay))s")
                retryCount += 1
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    print("🔄 ProjectListView: Retrying loadUserProjects after delay (\(self.retryCount)/\(self.maxRetries))")
                    self.loadUserProjects()
                }
                return
            } else if !authManager.isAuthenticated {
                print("🔐 ProjectListView: User not authenticated, waiting for sign in")
                isWaitingForAuth = false
                retryCount = 0
                return
            } else {
                print("❌ ProjectListView: Max retries reached, stopping")
                isWaitingForAuth = false
                return
            }
        }
        
        retryCount = 0 // Reset on successful user ID
        isWaitingForAuth = false // Clear waiting state
        
        print("👤 ProjectListView: Loading projects for user: \(userId)")
        
        Task {
            do {
                print("🔄 ProjectListView: Starting project listener and fetching projects")
                await projectManager.startListeningForUserProjects(userId: userId)
                let projects = try await projectManager.getUserProjects(userId: userId)
                
                await MainActor.run {
                    print("✨ ProjectListView: Successfully loaded \(projects.count) projects")
                    print("📊 ProjectListView: Current projectManager.projects count: \(projectManager.projects.count)")
                }
            } catch {
                print("❌ ProjectListView: Error loading projects: \(error)")
                print("❌ ProjectListView: Error details: \(error.localizedDescription)")
            }
        }
    }
    
    /// Exponential backoff delay calculation
    private func exponentialBackoffDelay(for attempt: Int) -> TimeInterval {
        let baseDelay: TimeInterval = 0.1  // Start with 100ms (reduced from 250ms)
        let maxDelay: TimeInterval = 1.0   // Cap at 1 second (reduced from 2s)
        let delay = baseDelay * pow(2.0, Double(attempt))
        return min(delay, maxDelay)
    }
    
    private func deleteProjects(at offsets: IndexSet) {
        guard !projectManager.projects.isEmpty else { return }
        
        let projectsToDelete = offsets.compactMap { index -> Project? in
            guard index < projectManager.projects.count else { return nil }
            return projectManager.projects[index]
        }
        
        for project in projectsToDelete {
            guard let projectId = project.id else { continue }
            
            Task {
                do {
                    try await projectManager.deleteProject(id: projectId)
                } catch {
                    await MainActor.run {
                        projectManager.error = FirebaseError.from(error)
                    }
                    print("❌ ProjectListView: Error deleting project: \(error)")
                }
            }
        }
    }
}


#Preview {
    ProjectListView()
}