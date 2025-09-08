//
//  AcceptProjectInviteView.swift
//  shigodeki
//
//  Created by Codex on 2025-08-30.
//

import SwiftUI

struct AcceptProjectInviteView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthenticationManager.shared
    @StateObject private var invitationManager = ProjectInvitationManager()
    @State private var code: String = ""
    @State private var isAccepting = false
    @State private var message: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("プロジェクト招待コード") {
                    TextField("例: ABC123 または INV-ABC123", text: $code)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: code) { _, newVal in 
                            // 統一システム対応：8桁まで許可、表示分離
                            if newVal.count > 8 { code = String(newVal.prefix(8)) }
                        }
                }
                if let msg = message { Section { Text(msg).font(.footnote).foregroundColor(.secondary) } }
            }
            .navigationTitle("プロジェクトに参加")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isAccepting ? "処理中…" : "参加") { accept() }
                        .disabled(isAccepting || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || authManager.currentUserId == nil)
                }
            }
        }
    }
    
    private func accept() {
        guard let uid = authManager.currentUserId else { return }
        let name = authManager.currentUser?.name
        isAccepting = true
        Task { @MainActor in
            do {
                // 統一システム経由で参加（正規化は内部で処理）
                _ = try await invitationManager.acceptInvitation(code: code, userId: uid, displayName: name)
                message = "プロジェクトに参加しました！（統一システム経由）"
                isAccepting = false
            } catch {
                message = error.localizedDescription
                isAccepting = false
            }
        }
    }
}

