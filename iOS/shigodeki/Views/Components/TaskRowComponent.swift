//
//  TaskRowComponent.swift
//  shigodeki
//
//  Extracted from TaskDetailView.swift for CLAUDE.md compliance
//  Task row display and interaction component
//

import SwiftUI
import UIKit

struct TaskRowView: View {
    let task: ShigodekiTask
    let taskList: TaskList
    let family: Family
    let taskManager: TaskManager
    let familyMembers: [User]
    @State private var showAttachPicker = false
    @State private var showPreview = false
    @State private var previewURL: URL?
    @State private var previewImage: UIImage?
    
    private var assignedMember: User? {
        guard let assignedTo = task.assignedTo else { return nil }
        return familyMembers.first { $0.id == assignedTo }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion button
            Button(action: {
                toggleCompletion()
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .green : .gray)
                    .scaleEffect(task.isCompleted ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: task.isCompleted)
            }
            .buttonStyle(.plain)
            .interactiveEffect()
            .accessibilityLabel(task.isCompleted ? "完了したタスク" : "未完了のタスク")
            .accessibilityHint(task.isCompleted ? "タップして未完了にします" : "タップして完了にします")
            
            VStack(alignment: .leading, spacing: 4) {
                // Task title
                HStack {
                    Text(task.title)
                        .font(.headline)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
                        .accessibilityLabel("タスク: \(task.title)")
                    
                    Spacer()
                    
                    // Priority indicator
                    Circle()
                        .fill(task.priority.swiftUIColor)
                        .frame(width: 8, height: 8)
                }
                
                // Task description
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Attachments thumbnails (show up to 3)
                if let atts = task.attachments, !atts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(atts.prefix(3).enumerated()), id: \.offset) { _, att in
                                if att.hasPrefix("http") || att.hasPrefix("https") {
                                    if let url = URL(string: att) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView().frame(width: 28, height: 28)
                                            case .success(let image):
                                                image.resizable().scaledToFill()
                                                    .frame(width: 28, height: 28)
                                                    .clipped()
                                                    .cornerRadius(4)
                                                    .onTapGesture { previewURL = url; previewImage = nil; showPreview = true }
                                            case .failure:
                                                Image(systemName: "photo")
                                                    .frame(width: 28, height: 28)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                    }
                                } else if let dataRange = att.range(of: ","),
                                          let data = Data(base64Encoded: String(att[dataRange.upperBound...])),
                                          let ui = UIImage(data: data) {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 28, height: 28)
                                        .clipped()
                                        .cornerRadius(4)
                                        .onTapGesture { previewImage = ui; previewURL = nil; showPreview = true }
                                }
                            }
                        }
                    }
                }
                
                // Task metadata
                HStack {
                    // Assigned member
                    if let assignedMember = assignedMember {
                        HStack(spacing: 4) {
                            Image(systemName: "person")
                                .font(.caption)
                            Text(assignedMember.name)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    // Due date
                    if let dueDate = task.dueDateFormatted {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text(dueDate)
                        }
                        .font(.caption)
                        .foregroundColor(task.isOverdue ? .red : .secondary)
                    }
                    
                    Spacer()
                    
                    // Completion date
                    if task.isCompleted, let completedAt = task.completedAt {
                        Text("完了: \(DateFormatter.taskDateTime.string(from: completedAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                showAttachPicker = true
            } label: {
                Label("画像を添付", systemImage: "photo.on.rectangle")
            }
        }
        .sheet(isPresented: $showAttachPicker) {
            CameraPicker(source: .photoLibrary) { image in
                Task { await addAttachment(image: image) }
            }
        }
        .sheet(isPresented: $showPreview) {
            ZoomableView {
                if let url = previewURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty: ProgressView()
                        case .success(let image): image.resizable().scaledToFit()
                        case .failure: Image(systemName: "photo")
                        @unknown default: EmptyView()
                        }
                    }
                } else if let img = previewImage {
                    Image(uiImage: img).resizable().scaledToFit()
                }
            }
            .padding()
        }
    }
    
    private func toggleCompletion() {
        guard let taskId = task.id,
              let taskListId = taskList.id,
              let familyId = family.id else { return }
        
        // Haptic feedback based on completion state
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        let notificationFeedback = UINotificationFeedbackGenerator()
        
        if task.isCompleted {
            impactFeedback.impactOccurred()
        } else {
            notificationFeedback.notificationOccurred(.success)
        }
        
        Task {
            do {
                try await taskManager.toggleTaskCompletion(
                    taskId: taskId,
                    taskListId: taskListId,
                    familyId: familyId
                )
            } catch {
                print("Error toggling task completion: \(error)")
                // Error feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
        }
    }

    private func addAttachment(image: UIImage) async {
        guard let taskId = task.id, let listId = taskList.id, let familyId = family.id,
              let data = image.jpegData(compressionQuality: 0.7) else { return }
        var atts = task.attachments ?? []
        atts.append("data:image/jpeg;base64,\(data.base64EncodedString())")
        do {
            try await taskManager.updateTaskAttachments(taskId: taskId, taskListId: listId, familyId: familyId, attachments: atts)
        } catch {
            print("Error updating attachments: \(error)")
        }
    }
}
