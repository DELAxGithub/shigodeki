//
//  ProjectSettingsView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

struct ProjectSettingsView: View {
    let project: Project
    @ObservedObject var projectManager: ProjectManager
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var authManager = SimpleAuthenticationManager.shared
    
    @State private var projectName: String
    @State private var projectDescription: String
    @State private var isCompleted: Bool
    @State private var isUpdating = false
    @State private var showingDeleteConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(project: Project, projectManager: ProjectManager) {
        self.project = project
        self.projectManager = projectManager
        self._projectName = State(initialValue: project.name)
        self._projectDescription = State(initialValue: project.description ?? "")
        self._isCompleted = State(initialValue: project.isCompleted)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "gear")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("プロジェクト設定")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(project.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                
                Form {
                    Section(header: Text("基本情報")) {
                        TextField("プロジェクト名", text: $projectName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(false)
                        
                        ZStack(alignment: .topLeading) {
                            if projectDescription.isEmpty {
                                VStack {
                                    HStack {
                                        Text("プロジェクトの説明")
                                            .foregroundColor(Color(.placeholderText))
                                        Spacer()
                                    }
                                    Spacer()
                                }
                                .padding(.top, 8)
                                .padding(.leading, 4)
                            }
                            
                            TextEditor(text: $projectDescription)
                                .frame(minHeight: 80)
                        }
                    }
                    
                    Section(header: Text("ステータス")) {
                        Toggle("完了済み", isOn: $isCompleted)
                        
                        if isCompleted {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("完了済みのプロジェクトは読み取り専用になります")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Section(header: Text("プロジェクト情報")) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("作成者")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("ID: \(project.ownerId)")
                                    .font(.subheadline)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("メンバー数")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(project.memberIds.count)人")
                                    .font(.subheadline)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("作成日")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatDate(project.createdAt))
                                    .font(.subheadline)
                            }
                        }
                        
                        if let lastModified = project.lastModifiedAt {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text("最終更新")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatDate(lastModified))
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                    
                    // Danger Zone
                    Section(header: Text("危険な操作")) {
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                Text("プロジェクトを削除")
                                    .foregroundColor(.red)
                            }
                        }
                        .disabled(isUpdating)
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(isUpdating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        updateProject()
                    }
                    .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUpdating || !hasChanges)
                }
            }
            .overlay(
                Group {
                    if isUpdating {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("更新中...")
                                .font(.headline)
                        }
                        .padding(24)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    }
                }
            )
            .confirmationDialog(
                "プロジェクトを削除",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    deleteProject()
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("このプロジェクトとすべてのデータが完全に削除されます。この操作は取り消せません。")
            }
            .alert("エラー", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var hasChanges: Bool {
        projectName.trimmingCharacters(in: .whitespacesAndNewlines) != project.name ||
        projectDescription.trimmingCharacters(in: .whitespacesAndNewlines) != (project.description ?? "") ||
        isCompleted != project.isCompleted
    }
    
    private func updateProject() {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "プロジェクト名を入力してください"
            showingError = true
            return
        }
        
        isUpdating = true
        
        Task {
            do {
                var updatedProject = project
                updatedProject.name = trimmedName
                
                let trimmedDescription = projectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                updatedProject.description = trimmedDescription.isEmpty ? nil : trimmedDescription
                updatedProject.isCompleted = isCompleted
                updatedProject.lastModifiedAt = Date()
                
                if isCompleted && !project.isCompleted {
                    updatedProject.completedAt = Date()
                } else if !isCompleted && project.isCompleted {
                    updatedProject.completedAt = nil
                }
                
                _ = try await projectManager.updateProject(updatedProject)
                
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func deleteProject() {
        guard let projectId = project.id else {
            errorMessage = "プロジェクトIDが見つかりません"
            showingError = true
            return
        }
        
        isUpdating = true
        
        Task {
            do {
                try await projectManager.deleteProject(id: projectId)
                
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "不明" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

#Preview {
    let sampleProject = Project(name: "Sample Project", description: "A sample project for preview", ownerId: "user1")
    ProjectSettingsView(project: sampleProject, projectManager: ProjectManager())
}