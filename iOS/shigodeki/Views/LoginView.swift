//
//  LoginView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-27.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App Logo/Title
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .scaleEffect(authManager.isLoading ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: authManager.isLoading)
                
                Text("シゴデキ")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .accessibilityAddTraits(.isHeader)
                
                Text("チームみんなでタスク管理")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("チーム全員でタスクを管理するアプリです")
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                // Apple Sign In Button - using custom implementation for better state control
                Button {
                    authManager.signInWithApple()
                } label: {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "applelogo")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        }
                        Text("Sign in with Apple")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black)
                    .cornerRadius(8)
                }
                .frame(maxWidth: 375)
                .disabled(authManager.isLoading)
                .scaleEffect(authManager.isLoading ? 0.98 : 1.0)
                .opacity(authManager.isLoading ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: authManager.isLoading)
                .accessibilityLabel("Sign in with Apple")
                .accessibilityHint("Apple IDでサインインします")
                
                // Demo Sign In Button (Secondary)
                Button {
                    Task {
                        await authManager.signInAnonymously()
                    }
                } label: {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "person.fill")
                        }
                        Text("デモとしてサインイン")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(.systemGray6))
                    .foregroundColor(.secondary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
                .scaleEffect(authManager.isLoading ? 0.98 : 1.0)
                .opacity(authManager.isLoading ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: authManager.isLoading)
                .disabled(authManager.isLoading)
                .accessibilityLabel("デモとしてサインイン")
                .accessibilityHint("匿名でサインインしてアプリをテストします")
                
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
                    .transition(.opacity.combined(with: .scale))
                    .accessibilityLabel("サインイン処理中です")
                }
                
                // Error message
                if let errorMessage = authManager.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .accessibilityLabel("エラー: \(errorMessage)")
                    .onAppear {
                        // Error haptic feedback
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.error)
                    }
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