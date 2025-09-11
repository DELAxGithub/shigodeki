//
//  TaskListDetailView.swift
//  shigodeki
//
//  Created by Claude on 2025-09-05.
//

import SwiftUI
import FirebaseFirestore

struct TaskListDetailView: View {
    let taskList: TaskList
    let phase: Phase
    let project: Project
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @StateObject private var viewModelHolder = _TaskListVMHolder()
    @ObservedObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss
    var onTapProject: (() -> Void)? = nil
    var onTapPhase: (() -> Void)? = nil
    @State private var showingCreateTask = false
    @State private var showingTaskEditor = false
    @State private var selectedTaskForEdit: ShigodekiTask?
    @State private var showAttachmentPreview = false
    @State private var previewURL: URL? = nil
    @State private var previewImage: UIImage? = nil
    
    var body: some View {
        VStack {
            BreadcrumbBar(items: [project.name, phase.name, taskList.name]) { idx in
                if idx == 0 {
                    if let onTapProject { onTapProject() } else { dismiss() }
                } else if idx == 1 {
                    if let onTapPhase { onTapPhase() } else { dismiss() }
                }
            }
                .padding(.horizontal)
            // Bootstrap VM once
            .task {
                if viewModelHolder.vm == nil, let listId = taskList.id, let phaseId = phase.id, let projectId = project.id {
                    let vm = TaskListDetailViewModel(listId: listId, phaseId: phaseId, projectId: projectId)
                    viewModelHolder.vm = vm
                    await vm.bootstrap(store: sharedManagers)
                }
            }
            let tasks = viewModelHolder.vm?.tasks ?? []
            if !tasks.isEmpty {
                List {
                    ForEach(tasks) { task in
                        HStack {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.isCompleted ? .green : .secondary)
                            VStack(alignment: .leading) {
                                Text(task.title)
                                    .font(.headline)
                                    .strikethrough(task.isCompleted, pattern: .solid, color: .secondary)
                                if let description = task.description, !description.isEmpty {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                // Attachments thumbnails (first 3)
                                if let atts = task.attachments, !atts.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(Array(atts.prefix(3).enumerated()), id: \.offset) { _, att in
                                                if att.hasPrefix("http") || att.hasPrefix("https") {
                                                    if let url = URL(string: att) {
                                                        AsyncImage(url: url) { phase in
                                                            switch phase {
                                                            case .empty: ProgressView().frame(width: 28, height: 28)
                                                            case .success(let image): image.resizable().scaledToFill()
                                                                .frame(width: 28, height: 28).clipped().cornerRadius(4)
                                                            case .failure: Image(systemName: "photo").frame(width: 28, height: 28)
                                                            @unknown default: EmptyView()
                                                            }
                                                        }
                                                    }
                                                } else if let dataRange = att.range(of: ","), let data = Data(base64Encoded: String(att[dataRange.upperBound...])) {
                                                    if let ui = UIImage(data: data) {
                                                        Image(uiImage: ui).resizable().scaledToFill().frame(width: 28, height: 28).clipped().cornerRadius(4)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleCompletion(task)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                toggleCompletion(task)
                            } label: {
                                Label(task.isCompleted ? "未完了" : "完了", systemImage: task.isCompleted ? "arrow.uturn.left.circle" : "checkmark.circle")
                            }
                            .tint(task.isCompleted ? .orange : .green)
                            Button {
                                selectedTaskForEdit = task
                                showingTaskEditor = true
                            } label: {
                                Label("編集", systemImage: "pencil")
                            }
                        }
                    }
                }
                .statusBarTapScrollToTop()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("タスクがありません")
                        .font(.title3)
                    Button("タスクを追加") {
                        showingCreateTask = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle(taskList.name)
        .navigationBarBackButtonHidden(true)
        .enableSwipeBack()
        .loadingOverlay(viewModelHolder.vm?.isLoading ?? false, message: "タスクを更新中...")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("追加") {
                    showingCreateTask = true
                }
            }
        }
        
        .sheet(isPresented: $showingCreateTask) {
            CreatePhaseTaskView(
                taskList: taskList,
                phase: phase, 
                project: project,
                taskManager: TaskManager()
            )
        }
        .sheet(isPresented: $showAttachmentPreview) {
            ZoomableView {
                VStack {
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
            }
            .padding()
        }
        .loadingOverlay(viewModelHolder.vm?.isLoading ?? false, message: "タスクを更新中...")
        .sheet(isPresented: $showingTaskEditor) {
            if let t = selectedTaskForEdit, let listId = taskList.id, let phaseId = phase.id, let projectId = project.id, let m = viewModelHolder.vm?.getManager() {
                TaskEditorView(task: t, listId: listId, phaseId: phaseId, projectId: projectId, enhancedTaskManager: m)
            }
        }
    }
    
    private func toggleCompletion(_ task: ShigodekiTask) {
        Task { await viewModelHolder.vm?.toggleCompletion(task) }
    }
    
    private func loadPhaseTasksFromFirestore(projectId: String, phaseId: String, taskListId: String) async throws -> [ShigodekiTask] {
        let db = Firestore.firestore()
        let tasksCollection = db.collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("lists").document(taskListId)
            .collection("tasks")
        
        let snapshot = try await tasksCollection.order(by: "order").getDocuments()
        
        return snapshot.documents.compactMap { document in
            let data = document.data()
            let title = data["title"] as? String ?? ""
            let description = data["description"] as? String
            let assignedTo = data["assignedTo"] as? String
            let createdBy = data["createdBy"] as? String ?? ""
            let dueDate = (data["dueDate"] as? Timestamp)?.dateValue()
            let priority = TaskPriority(rawValue: data["priority"] as? String ?? "medium") ?? .medium
            let order = data["order"] as? Int ?? 0
            
            var task = ShigodekiTask(
                title: title,
                description: description,
                assignedTo: assignedTo,
                createdBy: createdBy,
                dueDate: dueDate,
                priority: priority,
                listId: taskListId,
                phaseId: phaseId,
                projectId: projectId,
                order: order
            )
            
            task.id = document.documentID
            task.isCompleted = data["isCompleted"] as? Bool ?? false
            task.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
            task.completedAt = (data["completedAt"] as? Timestamp)?.dateValue()
            task.hasSubtasks = data["hasSubtasks"] as? Bool ?? false
            task.subtaskCount = data["subtaskCount"] as? Int ?? 0
            task.completedSubtaskCount = data["completedSubtaskCount"] as? Int ?? 0
            
            return task
        }
    }
}

private final class _TaskListVMHolder: ObservableObject {
    @Published var vm: TaskListDetailViewModel?
}
