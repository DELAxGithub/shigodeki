//
//  TaskEditorView.swift
//  shigodeki
//
//  Created by Claude on 2025-09-05.
//

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var task: ShigodekiTask
    let listId: String
    let phaseId: String
    let projectId: String
    @ObservedObject var enhancedTaskManager: EnhancedTaskManager
    @StateObject private var subtaskManager = SubtaskManager()
    @StateObject private var projectManager = ProjectManager()
    @ObservedObject private var authManager = AuthenticationManager.shared
    @State private var subtasks: [Subtask] = []
    @State private var isSaving = false
    @State private var newSubtaskTitle: String = ""
    @State private var projectMembers: [ProjectMember] = []
    @State private var selectedAssignee: String? = nil
    @State private var userNames: [String: String] = [:]
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var localImages: [UIImage] = []
    @StateObject private var aiGenerator = AITaskGenerator()
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本") {
                    TextField("タイトル", text: Binding(get: { task.title }, set: { task = ShigodekiTask(title: $0, description: task.description, assignedTo: task.assignedTo, createdBy: task.createdBy, dueDate: task.dueDate, priority: task.priority, listId: task.listId, phaseId: task.phaseId, projectId: task.projectId, order: task.order); task.id = task.id; task.isCompleted = task.isCompleted; task.linkURL = task.linkURL }))
                    TextField("説明", text: Binding(get: { task.description ?? "" }, set: { task.description = $0 }))
                    Picker("優先度", selection: Binding(get: { task.priority }, set: { task.priority = $0 })) {
                        ForEach(TaskPriority.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    DatePicker("締切", selection: Binding(get: { task.dueDate ?? Date() }, set: { task.dueDate = $0 }), displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .opacity(task.dueDate == nil ? 0.6 : 1)
                    TextField("リンクURL", text: Binding(get: { task.linkURL ?? "" }, set: { task.linkURL = $0 }))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
                
                Section("担当者") {
                    Picker("担当者", selection: Binding(get: { selectedAssignee ?? task.assignedTo }, set: { newVal in selectedAssignee = newVal; task = updateAssigned(to: newVal) })) {
                        Text("未指定").tag(String?.none)
                        if let myId = authManager.currentUserId {
                            Text("あなた（\(authManager.currentUser?.name ?? userNames[myId] ?? short(myId))）").tag(Optional(myId))
                        }
                        ForEach(projectMembers, id: \.userId) { member in
                            if member.userId != authManager.currentUserId {
                                Text(resolvedName(for: member)).tag(Optional(member.userId))
                            }
                        }
                    }
                }
                
                Section("添付画像") {
                    if !(localImages.isEmpty) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(localImages.enumerated()), id: \.offset) { _, img in
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipped()
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    PhotosPicker(selection: $selectedPhotos, matching: .images, photoLibrary: .shared()) {
                        Label("画像を追加", systemImage: "photo.on.rectangle")
                    }
                    .onChange(of: selectedPhotos) { _, items in
                        Task { @MainActor in
                            for item in items {
                                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                                    localImages.append(img)
                                    if let tid = task.id {
                                        do {
                                            let url = try await StorageManager.shared.uploadImage(data: data, projectId: projectId, taskId: tid)
                                            var atts = task.attachments ?? []
                                            atts.append(url)
                                            task.attachments = atts
                                        } catch {
                                            print("Upload failed: \(error)")
                                        }
                                    } else {
                                        // Fallback to inline data if no task id yet
                                        let base64 = data.base64EncodedString()
                                        var atts = task.attachments ?? []
                                        atts.append("data:image/jpeg;base64,\(base64)")
                                        task.attachments = atts
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section("AI支援") {
                    Button {
                        aiSplit()
                    } label: { Label("AIでサブタスク分割", systemImage: "wand.and.stars") }
                    Button {
                        aiDetail()
                    } label: { Label("AIで詳細調査", systemImage: "text.magnifyingglass") }
                }
                
                Section("サブタスク") {
                    if subtasks.isEmpty {
                        Text("サブタスクはありません")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(subtasks) { st in
                            HStack {
                                Button(action: { toggleSubtask(st) }) {
                                    Image(systemName: st.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(st.isCompleted ? .green : .secondary)
                                }
                                Text(st.title)
                                Spacer()
                                Menu {
                                    Button("タスクに昇格") { promoteToTask(st) }
                                    Button("削除", role: .destructive) { deleteSubtask(st) }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                            }
                        }
                    }
                    HStack {
                        TextField("サブタスクを追加", text: $newSubtaskTitle)
                        Button("追加") { addSubtask() }
                            .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle("タスクを編集")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button(isSaving ? "保存中…" : "保存") { save() }.disabled(isSaving) }
            }
            .onAppear { loadSubtasks(); loadMembers() }
        }
    }
    
    private func save() {
        isSaving = true
        Task { do { _ = try await enhancedTaskManager.updateTask(task); await MainActor.run { isSaving = false; dismiss() } } catch { isSaving = false; print("Task save error: \(error)") } }
    }
    
    private func loadSubtasks() {
        Task { do { let list = try await subtaskManager.getSubtasks(taskId: task.id ?? "", listId: listId, phaseId: phaseId, projectId: projectId); await MainActor.run { subtasks = list } } catch { print(error) } }
    }
    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let tid = task.id else { return }
        Task { do { _ = try await subtaskManager.createSubtask(title: title, description: nil, assignedTo: nil, createdBy: task.createdBy, dueDate: nil, taskId: tid, listId: listId, phaseId: phaseId, projectId: projectId, order: subtasks.count); newSubtaskTitle = ""; loadSubtasks() } catch { print(error) } }
    }
    private func deleteSubtask(_ st: Subtask) { Task { do { try await subtaskManager.deleteSubtask(id: st.id ?? "", taskId: task.id ?? "", listId: listId, phaseId: phaseId, projectId: projectId); loadSubtasks() } catch { print(error) } } }
    private func toggleSubtask(_ st: Subtask) { var tmp = st; tmp.isCompleted.toggle(); Task { do { _ = try await subtaskManager.updateSubtask(tmp); loadSubtasks() } catch { print(error) } } }
    private func promoteToTask(_ st: Subtask) {
        Task { do {
            _ = try await enhancedTaskManager.createTask(title: st.title, description: st.description, assignedTo: st.assignedTo, createdBy: task.createdBy, dueDate: st.dueDate, priority: .medium, listId: listId, phaseId: phaseId, projectId: projectId, order: (enhancedTaskManager.tasks.count))
            try await subtaskManager.deleteSubtask(id: st.id ?? "", taskId: task.id ?? "", listId: listId, phaseId: phaseId, projectId: projectId)
            loadSubtasks()
        } catch { print(error) } }
    }
    
    private func loadMembers() {
        Task {
            do {
                let members = try await projectManager.getProjectMembers(projectId: projectId)
                await MainActor.run {
                    self.projectMembers = members
                }
                await loadUserNamesIfNeeded(for: members)
            } catch {
                print(error)
            }
        }
    }
    
    @MainActor
    private func resolvedName(for member: ProjectMember) -> String {
        if let dn = member.displayName, !dn.isEmpty { return dn }
        if let cached = userNames[member.userId], !cached.isEmpty { return cached }
        return short(member.userId)
    }
    
    private func loadUserNamesIfNeeded(for members: [ProjectMember]) async {
        // Collect members missing displayName
        let ids = members.compactMap { m -> String? in
            if let dn = m.displayName, !dn.isEmpty { return nil }
            return m.userId
        }
        guard !ids.isEmpty else { return }
        let db = Firestore.firestore()
        for uid in ids {
            do {
                let doc = try await db.collection("users").document(uid).getDocument()
                if let data = doc.data(), let name = data["name"] as? String, !name.isEmpty {
                    await MainActor.run { userNames[uid] = name }
                }
            } catch {
                // Silent fail; keep fallback
                print("⚠️ TaskEditorView: Failed to resolve user name for \(uid): \(error)")
            }
        }
    }
    private func updateAssigned(to newVal: String?) -> ShigodekiTask { var t = task; t.assignedTo = newVal; return t }
    private func short(_ uid: String) -> String { String(uid.prefix(6)) }
    
    private func aiSplit() {
        let base = "次のタスクを3〜7個の実行可能なサブタスクに分割して、日本語で出力してください。\nタイトル: \(task.title)\n説明: \(task.description ?? "")"
        Task { @MainActor in
            await aiGenerator.generateTaskSuggestions(for: base, projectType: nil)
            if let suggestions = aiGenerator.generatedSuggestions {
                for s in suggestions.tasks { newSubtaskTitle = s.title; addSubtask() }
            }
        }
    }
    private func aiDetail() {
        let base = "次のタスクの詳細な実行手順や参考リンクを提案してください。日本語で簡潔に。\nタイトル: \(task.title)\n説明: \(task.description ?? "")"
        Task { @MainActor in
            await aiGenerator.generateTaskSuggestions(for: base, projectType: nil)
            if let suggestions = aiGenerator.generatedSuggestions, let first = suggestions.tasks.first {
                var desc = task.description ?? ""
                desc += "\n\nAI提案:\n" + first.description
                task.description = desc
            }
        }
    }
}
