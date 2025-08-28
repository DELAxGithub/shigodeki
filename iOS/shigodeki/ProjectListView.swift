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
                    ScrollView {
                        OptimizedList(items: projectManager.projects) { project in
                            NavigationLink(
                                destination: ProjectDetailView(project: project, projectManager: projectManager),
                                tag: project,
                                selection: $selectedProject
                            ) {
                                ProjectRowView(project: project)
                                    .buttonStyle(PlainButtonStyle())
                                    .optimizedForList()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .refreshable {
                        if let userId = authManager.currentUser?.id {
                            Task {
                                try await projectManager.getUserProjects(userId: userId)
                            }
                        }
                    }
                    .onMemoryWarning {
                        // Clear any local caches on memory warning
                        CacheManager.shared.clearAll()
                    }
                }
                
                if projectManager.isLoading {
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
                loadUserProjects()
            }
            .onDisappear {
                projectManager.removeAllListeners()
            }
            .sheet(isPresented: $showingCreateProject) {
                CreateProjectView(projectManager: projectManager)
            }
            .alert("エラー", isPresented: .constant(projectManager.error != nil)) {
                Button("OK") {
                    projectManager.error = nil
                }
            } message: {
                Text(projectManager.error?.localizedDescription ?? "")
            }
        }
    }
    
    private func loadUserProjects() {
        guard let userId = authManager.currentUser?.id else { return }
        
        Task {
            do {
                await projectManager.startListeningForUserProjects(userId: userId)
                _ = try await projectManager.getUserProjects(userId: userId)
            } catch {
                print("Error loading projects: \(error)")
            }
        }
    }
    
    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            let project = projectManager.projects[index]
            guard let projectId = project.id else { continue }
            
            Task {
                do {
                    try await projectManager.deleteProject(id: projectId)
                } catch {
                    print("Error deleting project: \(error)")
                }
            }
        }
    }
}


#Preview {
    ProjectListView()
}