//
//  PhaseTaskDetailView.swift
//  shigodeki
//

import SwiftUI
import PhotosUI

struct PhaseTaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project
    let phase: Phase
    @State var task: ShigodekiTask
    @StateObject private var taskManager = EnhancedTaskManager()
    @StateObject private var subtaskManager = SubtaskManager()
    @StateObject private var aiGenerator = AITaskGenerator()
    @StateObject private var sectionManager = PhaseSectionManager()
    @StateObject private var projectManager = ProjectManager()
    @State private var subtasks: [Subtask] = []
    @State private var newSubtaskTitle: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var localImages: [UIImage] = []
    @State private var projectMembers: [ProjectMember] = []
    @State private var selectedAssignee: String? = nil
    @State private var newTagText: String = ""
    @State private var selectedSectionId: String? = nil
    
    var body: some View {
        Form {
            Section("基本") {
                TextField("タイトル", text: Binding(get: { task.title }, set: { newValue in task.title = newValue; persistChanges() }))
                TextField("説明", text: Binding(get: { task.description ?? "" }, set: { newValue in task.description = newValue; persistChanges() }))
                Toggle("完了", isOn: Binding(get: { task.isCompleted }, set: { newValue in task.isCompleted = newValue; persistChanges() }))
                Picker("優先度", selection: Binding(get: { task.priority }, set: { newValue in task.priority = newValue; persistChanges() })) {
                    ForEach(TaskPriority.allCases, id: \.self) { p in Text(p.displayName).tag(p) }
                }
                .pickerStyle(.menu)
                DatePicker("締切", selection: Binding(get: { task.dueDate ?? Date() }, set: { newValue in task.dueDate = newValue; persistChanges() }), displayedComponents: [.date, .hourAndMinute])
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .opacity(task.dueDate == nil ? 0.6 : 1)
            }
            
            // Issues #57 & #60 Fix: Add scrollable description section with auto-linking
            if let description = task.description, !description.isEmpty {
                Section("詳細説明") {
                    ScrollView {
                        VStack(alignment: .leading) {
                            // Issue #60: Auto-link URLs in description text
                            Text(makeAttributedString(from: description))
                                .textSelection(.enabled)
                                .padding(.vertical, 8)
                        }
                    }
                    .frame(maxHeight: 150) // Issue #57: Scrollable with max height
                }
            }
            
            Section("担当・タグ・セクション") {
                AssigneeSectionView(
                    members: projectMembers,
                    selectedAssignee: $selectedAssignee,
                    assignedTo: $task.assignedTo,
                    onChange: persistChanges
                )
                TagsSectionView(
                    tags: $task.tags,
                    newTagText: $newTagText,
                    onAdd: { _ in addTag() },
                    onRemove: { tag in if let idx = task.tags.firstIndex(of: tag) { task.tags.remove(at: idx); persistChanges() } }
                )
                SectionPickerView(
                    sections: sectionManager.sections,
                    selectedSectionId: Binding(get: { selectedSectionId ?? task.sectionId }, set: { selectedSectionId = $0 }),
                    onChange: changeSection
                )
            }
            AttachmentsSectionView(
                selectedPhotos: $selectedPhotos,
                localImages: $localImages,
                onImageData: { data in
                    if let tid = task.id, let pid = project.id {
                        do {
                            let url = try await StorageManager.shared.uploadImage(data: data, projectId: pid, taskId: tid)
                            var atts = task.attachments ?? []
                            atts.append(url)
                            task.attachments = atts
                            _ = try await taskManager.updatePhaseTask(task)
                        } catch { print("Upload failed: \(error)") }
                    } else {
                        let base64 = data.base64EncodedString()
                        var atts = task.attachments ?? []
                        atts.append("data:image/jpeg;base64,\(base64)")
                        task.attachments = atts
                    }
                }
            )
            Section("サブタスク") {
                if subtasks.isEmpty {
                    Text("サブタスクはありません").foregroundColor(.secondary)
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
                                Button("削除", role: .destructive) { deleteSubtask(st) }
                            } label: { Image(systemName: "ellipsis.circle") }
                        }
                    }
                }
                HStack {
                    TextField("サブタスクを追加", text: $newSubtaskTitle)
                    Button("追加") { addSubtask() }
                        .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            // Issue #59 Fix: Add URL link section
            Section("関連リンク") {
                if let linkURL = task.linkURL, !linkURL.isEmpty {
                    Link(destination: URL(string: linkURL) ?? URL(string: "https://example.com")!) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                            Text(linkURL)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                } else {
                    Text("関連リンクがありません")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    TextField("https://example.com", text: Binding(
                        get: { task.linkURL ?? "" },
                        set: { newValue in 
                            task.linkURL = newValue.isEmpty ? nil : newValue
                            persistChanges()
                        }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                }
            }
            
            Section("AI支援") {
                Button {
                    aiSplit()
                } label: { Label("AIでサブタスク分割", systemImage: "wand.and.stars") }
                Button {
                    aiDetail()
                } label: { Label("AIで詳細提案", systemImage: "text.magnifyingglass") }
                if aiGenerator.isGenerating {
                    Text(aiGenerator.progressMessage).font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("タスク詳細")
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("保存") { save() } } }
        .task {
            await loadSubtasks()
            await loadMembers()
            sectionManager.startListening(phaseId: phase.id ?? "", projectId: project.id ?? "")
            selectedSectionId = task.sectionId
        }
    }
}

// MARK: - Tags wrap view
struct WrapTagsView: View {
    let tags: [String]
    let onRemove: (String) -> Void
    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 80), spacing: 6)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                HStack(spacing: 4) {
                    Text(tag).font(.caption)
                    Button(action: { onRemove(tag) }) { Image(systemName: "xmark.circle.fill").font(.caption2) }
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())
            }
        }
    }
}

extension PhaseTaskDetailView {
    private func save() {
        // Issue #61 Fix: Proper save operation with user feedback
        Task {
            do {
                // Perform the save operation
                _ = try await taskManager.updatePhaseTask(task)
                
                // Only dismiss on successful save
                await MainActor.run {
                    // Provide success feedback (haptic)
                    let feedbackGenerator = UINotificationFeedbackGenerator()
                    feedbackGenerator.notificationOccurred(.success)
                    
                    // Dismiss the view after successful save
                    dismiss()
                }
            } catch {
                // Issue #61 Fix: Proper error handling with user feedback
                await MainActor.run {
                    print("保存エラー: \(error)")
                    
                    // Provide error feedback (haptic)
                    let feedbackGenerator = UINotificationFeedbackGenerator()
                    feedbackGenerator.notificationOccurred(.error)
                    
                    // TODO: Show error alert to user
                    // For now, do NOT dismiss - let user retry
                }
            }
        }
    }

    private func persistChanges() {
        Task { do { _ = try await taskManager.updatePhaseTask(task) } catch { } }
    }

    private func loadSubtasks() async {
        guard let tid = task.id, let pid = project.id, let phid = phase.id else { return }
        do { let list = try await subtaskManager.getPhaseSubtasks(taskId: tid, phaseId: phid, projectId: pid); await MainActor.run { subtasks = list } } catch { }
    }
    private func addSubtask() {
        guard let tid = task.id, let pid = project.id, let phid = phase.id else { return }
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        Task {
            do {
                _ = try await subtaskManager.createPhaseSubtask(title: title, description: nil, assignedTo: nil, createdBy: task.createdBy, dueDate: nil, taskId: tid, phaseId: phid, projectId: pid, order: nil)
                newSubtaskTitle = ""
                await loadSubtasks()
            } catch { }
        }
    }
    private func deleteSubtask(_ st: Subtask) {
        guard let tid = task.id, let pid = project.id, let phid = phase.id else { return }
        Task { do { try await subtaskManager.deletePhaseSubtask(id: st.id ?? "", taskId: tid, phaseId: phid, projectId: pid); await loadSubtasks() } catch { } }
    }
    private func toggleSubtask(_ st: Subtask) {
        var tmp = st; tmp.isCompleted.toggle()
        Task { do { _ = try await subtaskManager.updatePhaseSubtask(tmp); await loadSubtasks() } catch { } }
    }
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
            do {
                let text = try await aiGenerator.generateText(prompt: base)
                var desc = task.description ?? ""
                desc += "\n\nAI提案:\n" + text
                task.description = desc
                _ = try await taskManager.updatePhaseTask(task)
            } catch { }
        }
    }

    private func loadMembers() async {
        guard let pid = project.id else { return }
        do { let members = try await projectManager.getProjectMembers(projectId: pid); await MainActor.run { projectMembers = members } } catch { }
    }
    private func addTag() {
        let tag = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        if !task.tags.contains(tag) { task.tags.append(tag); persistChanges() }
        newTagText = ""
    }
    private func changeSection(to sectionId: String?) {
        guard let phid = phase.id, let pid = project.id else { return }
        if let sec = sectionManager.sections.first(where: { $0.id == sectionId ?? "" }) {
            Task { do { try await taskManager.updateTaskSection(task, toSectionId: sec.id, toSectionName: sec.name); await MainActor.run { task.sectionId = sec.id; task.sectionName = sec.name } } catch { } }
        } else {
            Task { do { try await taskManager.updateTaskSection(task, toSectionId: nil, toSectionName: nil); await MainActor.run { task.sectionId = nil; task.sectionName = nil } } catch { } }
        }
    }
    
    // Issue #60 Fix: Auto-link URLs in description text
    private func makeAttributedString(from text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Simple URL detection using NSDataDetector
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(location: 0, length: text.utf16.count)
        
        detector?.enumerateMatches(in: text, options: [], range: range) { (match, _, _) in
            guard let match = match, let urlRange = Range(match.range, in: text) else { return }
            
            if let url = match.url {
                // Convert to AttributedString range
                let startIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: match.range.location)
                let endIndex = attributedString.index(startIndex, offsetByCharacters: match.range.length)
                let attributedRange = startIndex..<endIndex
                
                // Apply link styling
                attributedString[attributedRange].foregroundColor = .blue
                attributedString[attributedRange].underlineStyle = .single
                attributedString[attributedRange].link = url
            }
        }
        
        return attributedString
    }
    
}
