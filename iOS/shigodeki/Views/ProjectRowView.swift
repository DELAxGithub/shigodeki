//
//  ProjectRowView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI
import FirebaseFirestore

struct ProjectRowView: View {
    let project: Project
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var liveMemberCount: Int? = nil
    @State private var membersListener: ListenerRegistration? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and status
            HStack {
                Text(project.name)
                    .font(.headline)
                    .foregroundColor(.primaryText)
                    .fontWeight(.semibold)
                    .scaledFont(.headline, maxSize: 28)
                
                Spacer()
                
                StatusBadge(isCompleted: project.isCompleted)
            }
            
            // Description
            if let description = project.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .lineLimit(nil) // Allow unlimited lines for accessibility
                    .multilineTextAlignment(.leading)
                    .scaledFont(.subheadline, maxSize: 22)
            }
            
            // Metadata row
            HStack {
                MemberCountBadge(count: effectiveMemberCount)
                
                Spacer()
                
                // Creation date
                Text(formatDate(project.createdAt))
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
                    .scaledFont(.caption, maxSize: 18)
            }
        }
        .listCard(isSelected: isPressed)
        .contentShape(Rectangle())
        .accessibleCard(
            label: accessibilityLabel,
            hint: "プロジェクトの詳細を表示するにはダブルタップ"
        )
        .highContrastColors()
        .interactiveScale(isPressed: $isPressed)
        .task { startMembersListener() }
        .onDisappear { membersListener?.remove(); membersListener = nil }
    }
    
    private var accessibilityLabel: String {
        var label = "プロジェクト: \(project.name)"
        
        if let description = project.description, !description.isEmpty {
            label += "、説明: \(description)"
        }
        
        label += "、メンバー数: \(effectiveMemberCount)人"
        label += "、作成日: \(formatDate(project.createdAt))"
        label += project.isCompleted ? "、完了済み" : "、進行中"
        
        return label
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private var effectiveMemberCount: Int {
        liveMemberCount ?? project.memberIds.count
    }

    private func startMembersListener() {
        guard let projectId = project.id, !projectId.isEmpty else { return }
        membersListener?.remove(); membersListener = nil
        let docRef = Firestore.firestore().collection("projects").document(projectId)
        membersListener = docRef.collection("members").addSnapshotListener { snapshot, _ in
            Task { @MainActor in
                self.liveMemberCount = snapshot?.documents.count
            }
        }
        // Fallback for family-owned projects: derive from families/{ownerId}.members
        if project.ownerType == .family {
            Task {
                do {
                    let famDoc = try await Firestore.firestore().collection("families").document(project.ownerId).getDocument()
                    if let members = famDoc.data()? ["members"] as? [String] {
                        await MainActor.run { self.liveMemberCount = max(self.liveMemberCount ?? 0, members.count) }
                    }
                } catch {
                    // Ignore fallback errors
                }
            }
        }
    }
}

#Preview {
    let sampleProject = Project(name: "Sample Project", description: "A sample project for preview", ownerId: "user1")
    ProjectRowView(project: sampleProject)
        .padding()
}
