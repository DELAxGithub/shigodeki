//
//  CreateProjectView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

struct CreateProjectView: View {
    @ObservedObject var projectManager: ProjectManager
    @StateObject private var authManager = AuthenticationManager()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var projectName = ""
    @State private var projectDescription = ""
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("新しいプロジェクト")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("プロジェクトを作成してタスクを整理しましょう")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Form
                Form {
                    Section(header: Text("基本情報")) {
                        TextField("プロジェクト名", text: $projectName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(false)
                        
                        ZStack(alignment: .topLeading) {
                            if projectDescription.isEmpty {
                                VStack {
                                    HStack {
                                        Text("プロジェクトの説明（オプション）")
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
                    
                    Section(header: Text("プロジェクト情報")) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("作成者")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(authManager.currentUser?.name ?? "Unknown User")
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
                                Text(formatDate(Date()))
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("プロジェクト作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        createProject()
                    }
                    .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
            .overlay(
                Group {
                    if isCreating {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("プロジェクトを作成中...")
                                .font(.headline)
                        }
                        .padding(24)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    }
                }
            )
            .alert("エラー", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createProject() {
        print("🎯 Create project button tapped")
        print("📝 Input - Name: '\(projectName)', Description: '\(projectDescription)'")
        
        guard let userId = authManager.currentUser?.id else {
            print("❌ No user ID found")
            errorMessage = "ユーザー情報が見つかりません"
            showingError = true
            return
        }
        
        print("👤 Current user ID: '\(userId)'")
        
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            print("❌ Project name is empty")
            errorMessage = "プロジェクト名を入力してください"
            showingError = true
            return
        }
        
        print("✅ Validation passed - proceeding with creation")
        isCreating = true
        
        Task {
            do {
                let description = projectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalDescription = description.isEmpty ? nil : description
                print("📋 Final inputs - Name: '\(trimmedName)', Description: '\(finalDescription ?? "nil")', Owner: '\(userId)'")
                
                let createdProject = try await projectManager.createProject(
                    name: trimmedName,
                    description: finalDescription,
                    ownerId: userId
                )
                
                print("🎉 Project creation successful in view! Project ID: \(createdProject.id ?? "NO_ID")")
                
                await MainActor.run {
                    print("📱 Dismissing create project view")
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                print("❌ Project creation failed in view: \(error)")
                print("❌ Error type: \(type(of: error))")
                print("❌ Error details: \(error.localizedDescription)")
                
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                    print("📱 Showing error to user: \(errorMessage)")
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

#Preview {
    CreateProjectView(projectManager: ProjectManager())
}