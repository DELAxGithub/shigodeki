//
//  CreatePhaseView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

struct CreatePhaseView: View {
    let project: Project
    @ObservedObject var phaseManager: PhaseManager
    @ObservedObject private var authManager = AuthenticationManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var phaseName = ""
    @State private var phaseDescription = ""
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "list.number")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("新しいフェーズ")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 4) {
                        Text("プロジェクト: \(project.name)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("フェーズを追加してプロジェクトを段階的に進めましょう")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Form
                Form {
                    Section(header: Text("基本情報")) {
                        TextField("フェーズ名", text: $phaseName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(false)
                        
                        ZStack(alignment: .topLeading) {
                            if phaseDescription.isEmpty {
                                VStack {
                                    HStack {
                                        Text("フェーズの説明（オプション）")
                                            .foregroundColor(Color(.placeholderText))
                                        Spacer()
                                    }
                                    Spacer()
                                }
                                .padding(.top, 8)
                                .padding(.leading, 4)
                            }
                            
                            TextEditor(text: $phaseDescription)
                                .frame(minHeight: 80)
                        }
                    }
                    
                    Section(header: Text("フェーズ情報")) {
                        HStack {
                            Image(systemName: "number.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("順序")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(phaseManager.phases.count + 1)番目")
                                    .font(.subheadline)
                            }
                        }
                        
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
                    
                    Section(footer: Text("フェーズを作成した後、タスクリストを追加できます。フェーズの順序は後で変更できます。")) {
                        EmptyView()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("フェーズ作成")
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
                        createPhase()
                    }
                    .disabled(phaseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
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
                            Text("フェーズを作成中...")
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
    
    private func createPhase() {
        guard let projectId = project.id else {
            errorMessage = "プロジェクトIDが見つかりません"
            showingError = true
            return
        }
        
        guard let userId = authManager.currentUser?.id else {
            errorMessage = "ユーザー情報が見つかりません"
            showingError = true
            return
        }
        
        let trimmedName = phaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "フェーズ名を入力してください"
            showingError = true
            return
        }
        
        isCreating = true
        
        Task {
            do {
                let description = phaseDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalDescription = description.isEmpty ? nil : description
                
                let created = try await phaseManager.createPhase(
                    name: trimmedName,
                    description: finalDescription,
                    projectId: projectId,
                    createdBy: userId,
                    order: nil // Let the manager assign the next order
                )
                // Optimistic local append so that the new phase appears immediately
                await MainActor.run {
                    if !(phaseManager.phases.contains { $0.id == created.id }) {
                        phaseManager.phases.append(created)
                        phaseManager.phases.sort { $0.order < $1.order }
                    }
                }
                
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
    let sampleProject = Project(name: "Sample Project", description: "A sample project for preview", ownerId: "user1")
    CreatePhaseView(project: sampleProject, phaseManager: PhaseManager())
}
