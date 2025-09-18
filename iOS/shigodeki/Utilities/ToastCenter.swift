//
//  ToastCenter.swift
//  shigodeki
//
//  Simple toast presenter with optional undo action hook.
//

import SwiftUI

@MainActor
final class ToastCenter: ObservableObject {
    @Published var message: String?
    private(set) var action: (() -> Void)?

    func show(_ message: String, action: (() -> Void)? = nil, duration: TimeInterval = 5) {
        self.message = message
        self.action = action
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self?.message == message {
                    self?.message = nil
                    self?.action = nil
                }
            }
        }
    }

    func dismiss() {
        message = nil
        action = nil
    }
}

struct ToastOverlayView: View {
    @EnvironmentObject private var toast: ToastCenter

    var body: some View {
        ZStack {
            if let message = toast.message {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Text(message)
                            .foregroundColor(.white)
                        if let action = toast.action {
                            Button("取り消す", action: action)
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(12)
                    .padding(.bottom, 24)
                    .padding(.horizontal, 20)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("ToastOverlay")
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toast.message)
        .allowsHitTesting(false)
    }
}

