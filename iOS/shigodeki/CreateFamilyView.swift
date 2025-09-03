//
//  CreateFamilyView.swift
//  shigodeki
//
//  Created by Claude on 2025-09-03.
//

import SwiftUI

struct CreateFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var familyName: String = ""
    @State private var description: String = ""
    @State private var isCreating = false
    @State private var showSuccess = false
    
    let viewModel: FamilyViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            
                            VStack(spacing: 8) {
                                Text("新しい家族グループ")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                
                                Text("家族みんなでタスクを共有し\n効率的に管理しましょう")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.bottom, 8)
                        
                        // Family Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("家族グループ名")
                                .font(.headline)
                            
                            TextField("例: 田中家", text: $familyName)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .accessibilityIdentifier("family_name_field")
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("説明（任意）")
                                .font(.headline)
                            
                            TextField("家族グループの説明を入力...", text: $description, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .lineLimit(3...6)
                                .accessibilityIdentifier("family_description_field")
                        }
                        
                        // Information Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("作成後について")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                InfoRow(icon: "key", text: "招待コードが自動生成されます")
                                InfoRow(icon: "person.badge.plus", text: "家族メンバーを簡単に招待できます")
                                InfoRow(icon: "checklist", text: "みんなでタスクを共有・管理できます")
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    Spacer(minLength: 32)
                    
                    VStack(spacing: 16) {
                        Button(action: createFamily) {
                            HStack {
                                if isCreating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 4)
                                }
                                Text(isCreating ? "作成中..." : "家族グループを作成")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                        .accessibilityIdentifier("create_family_button")
                        
                        Button("キャンセル") {
                            dismiss()
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("家族グループ作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .alert("家族グループ作成完了", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("家族グループ「\(familyName)」が作成されました。")
            }
        }
    }
    
    private func createFamily() {
        let trimmedName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        isCreating = true
        
        Task {
            let success = await viewModel.createFamily(name: trimmedName)
            await MainActor.run {
                isCreating = false
                if success {
                    showSuccess = true
                }
                // エラーはviewModel内でハンドリングされる
            }
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    // プレビューは簡略化
    CreateFamilyView(viewModel: FamilyViewModel(
        familyManager: FamilyManager(),
        authManager: AuthenticationManager.shared
    ))
}