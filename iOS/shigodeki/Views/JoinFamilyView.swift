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
    @State private var inputError: String? = nil
    
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
                            
                            TextField("例: INV-V7DBKV または 915549", text: $inviteCode)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .textInputAutocapitalization(.characters)
                                .accessibilityIdentifier("invite_code_field")
                                .onChange(of: inviteCode) { _, newValue in
                                    validateInput(newValue)
                                }
                            
                            // 入力エラーメッセージ
                            if let error = inputError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.top, 4)
                            }
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
                                InfoRow(icon: "textformat", text: "'INV-英数6桁' または '数字6桁' のどちらの形式も使用できます")
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
                            
                            Text("家族グループの作成者に招待コードをお尋ねください。コードは家族グループの設定画面で確認できます。\nハイフンや大文字小文字は自動で補正されます。")
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
                            .frame(minHeight: 44) // 최소 높이 보장으로 NaN 방지
                            .padding()
                            .background(shouldDisableJoinButton ? Color.gray : Color.green)
                            .cornerRadius(12)
                        }
                        .disabled(shouldDisableJoinButton || isJoining)
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
    
    // MARK: - Helper Properties and Methods
    
    private var shouldDisableJoinButton: Bool {
        inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || inputError != nil
    }
    
    /// 統一招待システム対応の入力検証（INV-途中入力に対応）
    private func validateInput(_ input: String) {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 空文字列または短すぎる入力はエラー表示しない
        if trimmedInput.isEmpty {
            inputError = nil
            return
        }
        
        // INV-の途中入力はエラー表示を保留
        let upperInput = trimmedInput.uppercased()
        if upperInput == "I" || upperInput == "IN" || upperInput == "INV" || upperInput == "INV-" {
            inputError = nil
            print("ℹ️ [JoinFamilyView] INV- partial input detected, validation postponed: '\(input)'")
            return
        }
        
        // 6桁未満（INV-を除いた実質長）の場合もエラー表示を保留
        let withoutPrefix = upperInput.hasPrefix("INV-") ? String(upperInput.dropFirst(4)) : upperInput
        if withoutPrefix.count < 6 {
            inputError = nil
            print("ℹ️ [JoinFamilyView] Input too short, validation postponed: '\(input)' -> '\(withoutPrefix)'")
            return
        }
        
        // 6桁以上になったら正規化・検証を実行
        do {
            let normalizedCode = try InvitationCodeNormalizer.normalize(trimmedInput)
            let validationResult = InviteCodeSpec.validate(normalizedCode)
            
            switch validationResult {
            case .success(let codeType):
                inputError = nil
                let kind = codeType.isSafe ? "safe" : "legacy"
                print("✅ [JoinFamilyView] Validation success: input='\(input)', normalized='\(normalizedCode)', kind=\(kind)")
            case .failure(let error):
                inputError = error.localizedDescription
                print("❌ [JoinFamilyView] Validation error: \(error.localizedDescription)")
            }
        } catch let error as NormalizationError {
            inputError = error.localizedDescription
            print("❌ [JoinFamilyView] 正規化エラー: \(error.localizedDescription)")
        } catch {
            inputError = "予期しないエラーが発生しました"
            print("❌ [JoinFamilyView] 予期しないエラー: \(error)")
        }
    }
    
    private func joinFamily() {
        let rawInput = inviteCode
        guard !rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isJoining = true
        
        Task {
            let success = await viewModel.joinFamily(invitationCode: rawInput)
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
