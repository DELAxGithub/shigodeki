//
//  AuthHelperViews.swift
//  shigodeki
//
//  Created from AuthTestComponents split for CLAUDE.md compliance
//  Authentication test helper UI components
//

import SwiftUI

// MARK: - Helper Views

struct StatusRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct DebugRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct TestButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(color.opacity(isLoading ? 0.3 : 1.0))
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(isLoading ? 0.95 : 1.0)
            .opacity(isLoading ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
        .disabled(isLoading)
    }
}