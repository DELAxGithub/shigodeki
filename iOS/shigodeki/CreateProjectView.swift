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
        guard let userId = authManager.currentUser?.id else {
            errorMessage = "ユーザー情報が見つかりません"
            showingError = true
            return
        }
        
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "プロジェクト名を入力してください"
            showingError = true
            return
        }
        
        isCreating = true
        
        Task {
            do {
                let description = projectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalDescription = description.isEmpty ? nil : description
                
                _ = try await projectManager.createProject(
                    name: trimmedName,
                    description: finalDescription,
                    ownerId: userId
                )
                
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                    showingError = true
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