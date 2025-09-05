//
//  JoinFamilyView.swift
//  shigodeki
//
//  Created by Claude on 2025-09-03.
//

import SwiftUI

struct JoinFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCode: String = ""
    @State private var isJoining = false
    @State private var showSuccess = false
    @State private var successMessage = ""
    
    let viewModel: FamilyViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            VStack(spacing: 8) {
                                Text("家族グループに加入")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                
                                Text("招待コードを入力して\n家族グループのメンバーになりましょう")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.bottom, 8)
                        
                        // Invite Code
                        VStack(alignment: .leading, spacing: 8) {
                            Text("招待コード")
                                .font(.headline)
                            
                            TextField("招待コードを入力", text: $inviteCode)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .textInputAutocapitalization(.characters)
                                .accessibilityIdentifier("invite_code_field")
                        }
                        
                        // Information Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("招待コードについて")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                InfoRow(icon: "key", text: "家族グループの作成者から招待コードを受け取ってください")
                                InfoRow(icon: "shield", text: "招待コードは安全に管理されています")
                                InfoRow(icon: "person.3", text: "加入後は家族みんなでタスクを共有できます")
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Tips Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("💡 コードが見つからない場合")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            
                            Text("家族グループの作成者に招待コードをお尋ねください。コードは家族グループの設定画面で確認できます。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    Spacer(minLength: 32)
                    
                    VStack(spacing: 16) {
                        Button(action: joinFamily) {
                            HStack {
                                if isJoining {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 4)
                                }
                                Text(isJoining ? "加入中..." : "家族グループに加入")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.green)
                            .cornerRadius(12)
                        }
                        .disabled(inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isJoining)
                        .accessibilityIdentifier("join_family_button")
                        
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
            .navigationTitle("家族グループ加入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .alert("家族グループ加入完了", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(successMessage)
            }
        }
    }
    
    private func joinFamily() {
        let trimmedCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else { return }
        
        isJoining = true
        
        Task {
            let success = await viewModel.joinFamily(invitationCode: trimmedCode)
            await MainActor.run {
                isJoining = false
                if success {
                    successMessage = "家族グループに加入しました！"
                    showSuccess = true
                }
                // エラーはviewModel内でハンドリングされる
            }
        }
    }
}

#Preview {
    // プレビューは簡略化 - 新しい即時初期化パターンを使用
    JoinFamilyView(viewModel: FamilyViewModel())
}