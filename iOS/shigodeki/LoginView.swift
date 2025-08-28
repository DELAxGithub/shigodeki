//
//  LoginView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-27.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App Logo/Title
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("シゴデキ")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("家族みんなでタスク管理")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                // Apple Sign In Button
                SignInWithAppleButton(
                    onRequest: { request in
                        // This is handled in AuthenticationManager
                    },
                    onCompletion: { result in
                        // This is handled in AuthenticationManager
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .onTapGesture {
                    Task.detached {
                        await authManager.signInWithApple()
                    }
                }
                .disabled(authManager.isLoading)
                
                // Loading indicator
                if authManager.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("サインイン中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
                
                // Error message
                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Terms and Privacy
            VStack(spacing: 8) {
                Text("続行することで利用規約とプライバシーポリシーに")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("同意したものとみなされます")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    LoginView()
}