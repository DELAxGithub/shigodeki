//
//  PhaseTaskViewComponents.swift
//  shigodeki
//
//  Extracted from PhaseTaskView.swift for CLAUDE.md compliance
//  Phase task view UI components and sheets
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

// MARK: - Task Creation Sheet

struct TaskCreationSheet: View {
    @Binding var isPresented: Bool
    @Binding var newTaskTitle: String
    @Binding var newTaskSectionId: String?
    let groupedSections: [PhaseSection]
    let onCreate: (String, PhaseSection?) -> Void
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var isGeneratingFromPhoto = false
    @State private var genError: String?
    @EnvironmentObject private var toastCenter: ToastCenter
    
    var body: some View {
        NavigationView {
            Form {
                Section("タイトル") {
                    TextField("新しいタスク", text: $newTaskTitle)
                        .submitLabel(.done)
                }
                Section("写真から提案（任意）") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Button {
                                showCamera = true
                            } label: {
                                Label("カメラで提案", systemImage: "camera")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                showLibrary = true
                            } label: {
                                Label("写真を選択", systemImage: "photo.on.rectangle")
                            }
                            .buttonStyle(.bordered)
                        }

                        if isGeneratingFromPhoto {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("写真を解析して提案を生成中…")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let genError {
                            Text(genError)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }

                        // 内蔵のプランナーを使用します
                    }
                }
                Section("セクション") {
                    Picker("セクション", selection: Binding(
                        get: { newTaskSectionId ?? "" }, 
                        set: { newTaskSectionId = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("未分類").tag("")
                        ForEach(groupedSections, id: \.id) { sec in
                            if let sid = sec.id { 
                                Text(sec.name).tag(sid) 
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(source: .camera) { image in
                    process(image: image)
                }
            }
            .sheet(isPresented: $showLibrary) {
                CameraPicker(source: .photoLibrary) { image in
                    process(image: image)
                }
            }
            .navigationTitle("タスクを追加")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { 
                    Button("キャンセル") { 
                        isPresented = false
                        newTaskTitle = ""
                    } 
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !title.isEmpty else { return }
                        let section = groupedSections.first(where: { $0.id == newTaskSectionId })
                        onCreate(title, section)
                        newTaskTitle = ""
                        isPresented = false
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCamera = true
                    } label: {
                        Image(systemName: "camera")
                    }
                    .accessibilityLabel("写真から提案")
                }
            }
        }
    }

    private func process(image: UIImage) {
        genError = nil
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            genError = "画像の処理に失敗しました"
            return
        }
        generate(from: data)
    }

    private func generate(from imageData: Data) {
        isGeneratingFromPhoto = true
        Task {
            defer { isGeneratingFromPhoto = false }
            let hasProvider = KeychainManager.APIProvider.allCases.contains { provider in
                KeychainManager.shared.getAPIKeyIfAvailable(for: provider)?.isEmpty == false
            }
            let allowNetwork = hasProvider
            let planner = VisionPlanCoordinator()
            let regionCode = Locale.current.region?.identifier ?? "JP"
            let locale = UserLocale(
                country: regionCode,
                city: regionCode == "JP" ? "Tokyo" : "Toronto"
            )
            let context = VisionPlanContextBuilder.build(
                project: nil,
                phase: nil,
                taskList: nil,
                additionalNotes: ["コンテクスト未設定: セクション追加用の写真解析"]
            )
            let plan = await planner.generatePlan(from: imageData, locale: locale, allowNetwork: allowNetwork, context: context)
            if plan.project == "Fallback Moving Plan" {
                await MainActor.run {
                    genError = nil
                    toastCenter.show("AIが混雑中のため、テンプレート候補を表示しました")
                }
            }
            if let first = plan.tasks.first {
                await MainActor.run {
                    newTaskTitle = first.title
                }
            } else {
                await MainActor.run { genError = "写真から提案を生成できませんでした" }
            }
        }
    }
}

// MARK: - Section Creation Sheet

struct SectionCreationSheet: View {
    @Binding var isPresented: Bool
    @Binding var newSectionName: String
    let onCreate: (String) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("セクション名") {
                    TextField("例: 企画", text: $newSectionName)
                }
            }
            .navigationTitle("セクションを追加")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { 
                    Button("キャンセル") { 
                        isPresented = false
                        newSectionName = ""
                    } 
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        let name = newSectionName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        onCreate(name)
                        newSectionName = ""
                        isPresented = false
                    }
                    .disabled(newSectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Rename Section Sheet

struct RenameSectionSheet: View {
    let section: PhaseSection
    @State var name: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    init(section: PhaseSection, initialName: String, onSave: @escaping (String) -> Void) {
        self.section = section
        self._name = State(initialValue: initialName)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form { 
                TextField("セクション名", text: $name) 
            }
            .navigationTitle("名称変更")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { 
                    Button("キャンセル") { dismiss() } 
                }
                ToolbarItem(placement: .navigationBarTrailing) { 
                    Button("保存") { 
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss() 
                    } 
                }
            }
        }
    }
}

// MARK: - Task Row View

struct PhaseTaskRowView: View {
    let task: ShigodekiTask
    let groupedSections: [PhaseSection]
    let onTap: () -> Void
    let onMove: (PhaseSection?) -> Void
    
    var body: some View {
        HStack {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isCompleted ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).font(.headline)
                if let desc = task.description, !desc.isEmpty {
                    Text(desc).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            if let due = task.dueDateFormatted { 
                Text(due).font(.caption).foregroundColor(.secondary) 
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onDrag { NSItemProvider(object: NSString(string: task.id ?? "")) }
        .contextMenu {
            Menu("セクションへ移動") {
                ForEach(groupedSections, id: \.id) { target in
                    Button(target.name) {
                        onMove(target)
                    }
                }
                Button("未分類") {
                    onMove(nil)
                }
            }
        }
    }
}

// MARK: - Section Header View

struct PhaseSectionHeaderView: View {
    let section: PhaseSection
    let taskCount: Int
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text(section.name).font(.subheadline).fontWeight(.semibold)
            Spacer()
            Text("\(taskCount)件").font(.caption).foregroundColor(.secondary)
            Menu { 
                Button("名称変更") { onRename() }
                Button("削除", role: .destructive) { onDelete() }
            } label: { 
                Image(systemName: "ellipsis.circle") 
            }
        }
    }
}

// MARK: - Quick Add Row View

struct QuickAddRowView: View {
    @Binding var inlineNewTitle: String
    let onAdd: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "plus.circle.fill").foregroundColor(.blue)
            TextField("新規タスク…", text: $inlineNewTitle)
                .submitLabel(.done)
                .onSubmit { onAdd() }
            Button("追加") { onAdd() }
                .disabled(inlineNewTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

// MARK: - Phase Task Content View

struct PhaseTaskContentView: View {
    let tasks: [ShigodekiTask]
    let groupedSections: [PhaseSection]
    let selectedTaskId: Binding<String?>
    @Binding var inlineNewTitle: String
    let tasksInSection: (String?) -> [ShigodekiTask]
    let onTaskTap: (ShigodekiTask) -> Void
    let onTaskMove: (ShigodekiTask, PhaseSection?) -> Void
    let onTaskReorder: (PhaseSection, IndexSet, Int) -> Void
    let onSectionRename: (PhaseSection) -> Void
    let onSectionDelete: (PhaseSection) -> Void
    let onQuickAdd: () -> Void
    let onDrop: ([NSItemProvider], PhaseSection) -> Bool
    
    var body: some View {
        if tasks.isEmpty {
            AccessibleEmptyStateView(
                title: "タスクがありません",
                subtitle: "セクションを選んでタスクを作成しましょう",
                systemImage: "checkmark.circle",
                actionTitle: nil,
                action: nil
            )
            .padding()
        } else {
            List {
                ForEach(groupedSections, id: \.id) { section in
                    let sectionTasks = tasksInSection(section.id)
                    
                    Section(header: PhaseSectionHeaderView(
                        section: section,
                        taskCount: sectionTasks.count,
                        onRename: { onSectionRename(section) },
                        onDelete: { onSectionDelete(section) }
                    )) {
                        ForEach(sectionTasks) { task in
                            PhaseTaskRowView(
                                task: task,
                                groupedSections: groupedSections,
                                onTap: { onTaskTap(task) },
                                onMove: { target in onTaskMove(task, target) }
                            )
                        }
                        .onMove { indices, newOffset in
                            onTaskReorder(section, indices, newOffset)
                        }
                    }
                    .onDrop(of: [UTType.text.identifier], isTargeted: nil) { providers in
                        onDrop(providers, section)
                    }
                }
                
                // Global inline quick-add at bottom
                Section {
                    QuickAddRowView(
                        inlineNewTitle: $inlineNewTitle,
                        onAdd: onQuickAdd
                    )
                }
            }
            .statusBarTapScrollToTop()
        }
    }
}
