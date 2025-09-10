//
//  ProjectHeaderView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI
import FirebaseFirestore

struct ProjectHeaderView: View {
    let project: Project
    @ObservedObject var projectManager: ProjectManager
    @State private var liveMemberCount: Int? = nil
    @State private var membersListener: ListenerRegistration? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let description = project.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if project.isCompleted {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        Text("完了")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(memberCountText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(formatDate(project.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let lastModified = project.lastModifiedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("更新: \(formatDate(lastModified))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { startMembersListener() }
        .onDisappear { membersListener?.remove(); membersListener = nil }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private var memberCountText: String {
        if let c = liveMemberCount { return "\(c)人" }
        return "読み込み中..."
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
        // Fallback for family-owned projects
        if project.ownerType == .family {
            Task {
                do {
                    let famDoc = try await Firestore.firestore().collection("families").document(project.ownerId).getDocument()
                    if let members = famDoc.data()? ["members"] as? [String] {
                        await MainActor.run { self.liveMemberCount = max(self.liveMemberCount ?? 0, members.count) }
                    }
                } catch { }
            }
        }
    }
}

#Preview {
    let sampleProject = Project(name: "Sample Project", description: "A sample project for preview", ownerId: "user1")
    ProjectHeaderView(project: sampleProject, projectManager: ProjectManager())
        .padding()
}
