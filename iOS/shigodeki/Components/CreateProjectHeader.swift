import SwiftUI

// MARK: - Create Project Header

struct CreateProjectHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("新しいプロジェクト")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("プロジェクトを作成してタスクを整理しましょう")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Create Project Toolbar

struct CreateProjectToolbar: View {
    let isCreating: Bool
    let isCreateButtonDisabled: Bool
    let onCancel: () -> Void
    let onCreate: () -> Void
    
    var body: some View {
        HStack {
            Button("キャンセル") {
                onCancel()
            }
            .disabled(isCreating)
            
            Spacer()
            
            Button("作成") {
                onCreate()
            }
            .disabled(isCreateButtonDisabled || isCreating)
        }
        .padding()
    }
}

// MARK: - Create Project Loading Overlay

struct CreateProjectLoadingOverlay: View {
    let isShowing: Bool
    
    var body: some View {
        if isShowing {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("プロジェクトを作成中...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }
}
