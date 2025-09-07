//
//  AuthStatusComponents.swift
//  shigodeki
//
//  Created from AuthTestComponents split for CLAUDE.md compliance
//  Authentication status display components
//

import SwiftUI
import FirebaseAuth

// MARK: - Auth Status Card

struct AuthStatusCard: View {
    @ObservedObject var authManager: AuthenticationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundColor(.blue)
                Text("認証状態")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(authManager.isAuthenticated ? .green : .red)
                    .frame(width: 12, height: 12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                StatusRow(label: "認証済み", value: authManager.isAuthenticated ? "はい" : "いいえ")
                StatusRow(label: "ローディング中", value: authManager.isLoading ? "はい" : "いいえ")
                StatusRow(label: "Firebase UID", value: Auth.auth().currentUser?.uid ?? "未設定")
                StatusRow(label: "メール", value: authManager.currentUser?.email ?? "未設定")
                StatusRow(label: "表示名", value: authManager.currentUser?.name ?? "未設定")
                
                if let errorMessage = authManager.errorMessage {
                    StatusRow(label: "エラー", value: errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}