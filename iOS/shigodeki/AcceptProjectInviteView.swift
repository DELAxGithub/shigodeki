//
//  AcceptProjectInviteView.swift
//  shigodeki
//
//  Created by Codex on 2025-08-30.
//

import SwiftUI

struct AcceptProjectInviteView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var invitationManager = ProjectInvitationManager()
    @State private var code: String = ""
    @State private var isAccepting = false
    @State private var message: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("招待コード") {
                    TextField("6桁コード", text: $code)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: code) { _, newVal in if newVal.count > 6 { code = String(newVal.prefix(6)) } }
                }
                if let msg = message { Section { Text(msg).font(.footnote).foregroundColor(.secondary) } }
            }
            .navigationTitle("招待を受ける")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isAccepting ? "処理中…" : "参加") { accept() }
                        .disabled(isAccepting || code.count != 6 || authManager.currentUserId == nil)
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
                _ = try await invitationManager.acceptInvitation(code: code.uppercased(), userId: uid, displayName: name)
                message = "招待を受け付けました。プロジェクトに参加しました。"
                isAccepting = false
            } catch {
                message = error.localizedDescription
                isAccepting = false
            }
        }
    }
}

