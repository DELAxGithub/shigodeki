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
            if isLoading {
                try? await Task.sleep(nanoseconds: UInt64((minShowDelay) * 1_000_000_000))
                if isLoading { shouldShow = true }
            } else {
                shouldShow = false
            }
        }
    }
}

extension View {
    func loadingOverlay(_ isLoading: Bool, message: String? = nil, minShowDelay: TimeInterval = 0.15) -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, message: message, minShowDelay: minShowDelay))
    }
}
