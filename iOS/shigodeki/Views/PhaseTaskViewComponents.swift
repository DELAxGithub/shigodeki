//
//  PhaseTaskViewComponents.swift
//  shigodeki
//
//  Extracted from PhaseTaskView.swift for CLAUDE.md compliance
//  Phase task view UI components and sheets
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Task Creation Sheet

struct TaskCreationSheet: View {
    @Binding var isPresented: Bool
    @Binding var newTaskTitle: String
    @Binding var newTaskSectionId: String?
    let groupedSections: [PhaseSection]
    let onCreate: (String, PhaseSection?) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("タイトル") {
                    TextField("新しいタスク", text: $newTaskTitle)
                        .submitLabel(.done)
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
