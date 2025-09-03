//
//  LoadingOverlay.swift
//  shigodeki
//
//  Adds a non-intrusive loading overlay that keeps prior content visible
//

import SwiftUI

struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    let message: String?
    let minShowDelay: TimeInterval
    @State private var shouldShow = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
            if shouldShow {
                Color.black.opacity(0.05).ignoresSafeArea().allowsHitTesting(false)
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primaryBlue))
                    if let message = message, !message.isEmpty {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isLoading)
        .task(id: isLoading) {
            // 🚨 CTO修正: ローディング表示の人工的遅延を撤廃
            // 即座にローディング状態を反映し、レスポンシブなユーザー体験を提供
            if isLoading {
                shouldShow = true
                print("⚡ LoadingOverlay: 即座にローディング表示開始")
            } else {
                shouldShow = false
                print("✅ LoadingOverlay: 即座にローディング表示終了")
            }
        }
    }
}

extension View {
    func loadingOverlay(_ isLoading: Bool, message: String? = nil, minShowDelay: TimeInterval = 0.15) -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, message: message, minShowDelay: minShowDelay))
    }
}
