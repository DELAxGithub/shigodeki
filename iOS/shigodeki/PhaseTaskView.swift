//
//  PhaseTaskView.swift
//  shigodeki
//
//  Phase-level task list grouped by sections
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

struct PhaseTaskView: View {
    let phase: Phase
    let project: Project
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @StateObject private var taskVM = _PhaseTaskVM()
    @StateObject private var sectionManager = PhaseSectionManager()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.editMode) private var editMode
    // Section CRUD state
    @State private var showingCreateSection = false
    @State private var newSectionName = ""
    @State private var renamingSection: PhaseSection? = nil
    @State private var renameText: String = ""
    // Task create state
    @State private var showingCreateTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskSectionId: String? = nil
    // Task detail navigation
    @State private var selectedTaskId: String? = nil
    // Inline quick add
    @State private var inlineNewTitle: String = ""
    
    var body: some View {
        VStack {
            BreadcrumbBar(items: [project.name, phase.name, "タスク"]) { idx in
                if idx == 0 { dismiss() } else if idx == 1 { dismiss() }
            }
            .padding(.horizontal)
            
            content
            // Hidden navigator
            NavigationLink(isActive: Binding(get: { selectedTaskId != nil }, set: { if !$0 { selectedTaskId = nil } })) {
                if let tid = selectedTaskId, let t = taskVM.tasks.first(where: { $0.id == tid }) {
                    PhaseTaskDetailView(project: project, phase: phase, task: t)
                } else {
                    EmptyView()
                }
            } label: { EmptyView() }.hidden()
        }
        .navigationTitle(phase.name)
        .navigationBarBackButtonHidden(true)
        .task {
            await taskVM.bootstrap(phaseId: phase.id ?? "", projectId: project.id ?? "", store: sharedManagers)
            sectionManager.startListening(phaseId: phase.id ?? "", projectId: project.id ?? "")
        }
        .refreshable { await taskVM.reload() }
        .loadingOverlay(taskVM.isLoading, message: "タスクを更新中...")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    EditButton()
                    Button { showingCreateTask = true } label: { Image(systemName: "plus.circle") }
                    Button { showingCreateSection = true } label: { Image(systemName: "folder.badge.plus") }
                }
            }
        }
        .sheet(isPresented: $showingCreateTask) {
            NavigationView {
                Form {
                    Section("タイトル") {
                        TextField("新しいタスク", text: $newTaskTitle)
                            .submitLabel(.done)
                    }
                    Section("セクション") {
                        Picker("セクション", selection: Binding(get: { newTaskSectionId ?? "" }, set: { newTaskSectionId = $0.isEmpty ? nil : $0 })) {
                            Text("未分類").tag("")
                            ForEach(groupedSections, id: \.id) { sec in
                                if let sid = sec.id { Text(sec.name).tag(sid) }
                            }
                        }
                    }
                }
                .navigationTitle("タスクを追加")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { showingCreateTask = false; newTaskTitle = "" } }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("追加") {
                            Task { @MainActor in
                                let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !title.isEmpty else { return }
                                let sec = groupedSections.first(where: { $0.id == newTaskSectionId })
                                await taskVM.createTask(title: title, section: sec, project: project, phase: phase)
                                newTaskTitle = ""
                                showingCreateTask = false
                            }
                        }
                        .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateSection) {
            NavigationView {
                Form {
                    Section("セクション名") {
                        TextField("例: 企画", text: $newSectionName)
                    }
                }
                .navigationTitle("セクションを追加")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { showingCreateSection = false; newSectionName = "" } }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("追加") {
                            Task { @MainActor in
                                try? await sectionManager.createSection(name: newSectionName.trimmingCharacters(in: .whitespacesAndNewlines), phaseId: phase.id ?? "", projectId: project.id ?? "")
                                newSectionName = ""
                                showingCreateSection = false
                            }
                        }.disabled(newSectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .sheet(item: $renamingSection) { sec in
            RenameSectionSheet(section: sec, initialName: sec.name) { newName in
                var updated = sec; updated.name = newName
                Task { try? await sectionManager.updateSection(updated, phaseId: phase.id ?? "", projectId: project.id ?? "") }
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        let tasks = taskVM.tasks
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
                    Section(header: sectionHeader(section)) {
                        ForEach(tasksInSection(section.id)) { task in
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
                                if let due = task.dueDateFormatted { Text(due).font(.caption).foregroundColor(.secondary) }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedTaskId = task.id }
                            .onDrag { 
                                // Enable drag both in edit mode and normal mode for cross-section movement
                                NSItemProvider(object: NSString(string: task.id ?? ""))
                            }
                            .contextMenu {
                                Menu("セクションへ移動") {
                                    ForEach(groupedSections, id: \.id) { target in
                                        Button(target.name) {
                                            Task { await taskVM.moveTask(task, to: target, project: project, phase: phase) }
                                        }
                                    }
                                    Button("未分類") {
                                        Task { await taskVM.moveTask(task, to: nil, project: project, phase: phase) }
                                    }
                                }
                            }
                        }
                        .onMove { indices, newOffset in
                            Task { await taskVM.reorderTasks(in: section, moveFrom: indices, to: newOffset) }
                        }
                        // Inline quick-add row at the bottom of each section (optional UX: for now bottom of list has one)
                    }
                    // Drop destination on section header area
                    .onDrop(of: [UTType.text.identifier], isTargeted: nil) { providers in
                        handleDrop(providers: providers, into: section)
                    }
                }
                // Global inline quick-add at bottom (adds to 未分類)
                Section {
                    HStack {
                        Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                        TextField("新規タスク…", text: $inlineNewTitle)
                            .submitLabel(.done)
                            .onSubmit { quickAdd() }
                        Button("追加") { quickAdd() }
                            .disabled(inlineNewTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
    
    private var groupedSections: [PhaseSection] {
        var result = sectionManager.sections
        let knownIds = Set(result.compactMap { $0.id })
        let tasks = taskVM.tasks
        // Add a pseudo section for tasks without section
        if tasks.contains(where: { ($0.sectionId ?? "").isEmpty }) {
            result.insert(PhaseSection(name: "未分類", order: -1), at: 0)
        }
        // Add synthetic sections for orphan sectionIds
        let orphanIds = Set(tasks.compactMap { $0.sectionId }).subtracting(knownIds)
        for oid in orphanIds {
            var name = "その他"
            if let t = tasks.first(where: { $0.sectionId == oid }), let n = t.sectionName, !n.isEmpty { name = n }
            var sec = PhaseSection(name: name, order: 999)
            sec.id = oid
            result.append(sec)
        }
        return result.sorted { $0.order < $1.order }
    }
    
    private func tasksInSection(_ sectionId: String?) -> [ShigodekiTask] {
        if sectionId == nil || sectionId == "" { return taskVM.tasks.filter { ($0.sectionId ?? "").isEmpty } }
        return taskVM.tasks.filter { $0.sectionId == sectionId }
    }
    
    private func sectionHeader(_ section: PhaseSection) -> some View {
        HStack {
            Text(section.name).font(.subheadline).fontWeight(.semibold)
            Spacer()
            Text("\(tasksInSection(section.id).count)件").font(.caption).foregroundColor(.secondary)
            Menu { sectionMenu(section) } label: { Image(systemName: "ellipsis.circle") }
        }
    }

    @ViewBuilder
    private func sectionMenu(_ section: PhaseSection) -> some View {
        Button("名称変更") { renamingSection = section }
        Button("削除", role: .destructive) {
            if let sid = section.id { Task { try? await sectionManager.deleteSection(id: sid, phaseId: phase.id ?? "", projectId: project.id ?? "") } }
        }
    }

    // MARK: - Quick Add (bottom input)
    private func quickAdd() {
        let title = inlineNewTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        Task { @MainActor in
            await taskVM.createTask(title: title, section: nil, project: project, phase: phase)
            inlineNewTitle = ""
        }
    }
}

@MainActor
private final class _PhaseTaskVM: ObservableObject {
    @Published var tasks: [ShigodekiTask] = []
    @Published var isLoading = false
    private var taskManager: EnhancedTaskManager?
    private var phaseId: String = ""
    private var projectId: String = ""
    
    func bootstrap(phaseId: String, projectId: String, store: SharedManagerStore) async {
        self.phaseId = phaseId
        self.projectId = projectId
        let m = await store.getTaskManager()
        self.taskManager = m
        await reload()
        m.startListeningForPhaseTasks(phaseId: phaseId, projectId: projectId)
        m.$tasks.receive(on: RunLoop.main).sink { [weak self] in self?.tasks = $0 }.store(in: &cancellables)
        m.$isLoading.receive(on: RunLoop.main).sink { [weak self] in self?.isLoading = $0 }.store(in: &cancellables)
    }
    
    func reload() async {
        guard let m = taskManager else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let phaseTasks = try await m.getPhaseTasks(phaseId: phaseId, projectId: projectId)
            tasks = phaseTasks
            if tasks.isEmpty {
                // Fallback for legacy data: flatten list-based tasks into sections
                tasks = try await LegacyDataBridge.flattenLegacyTasks(phaseId: phaseId, projectId: projectId)
            }
        } catch {
            // Keep previous tasks on error
        }
    }
    
    func moveTask(_ task: ShigodekiTask, to targetSection: PhaseSection?, project: Project, phase: Phase) async {
        guard let m = taskManager else { return }
        do {
            try await m.updateTaskSection(task, toSectionId: targetSection?.id, toSectionName: targetSection?.name)
            await reload()
        } catch { }
    }
    
    func createTask(title: String, section: PhaseSection?, project: Project, phase: Phase) async {
        guard let m = taskManager else { return }
        let auth = await SharedManagerStore.shared.getAuthManager()
        let uid = auth.currentUserId ?? ""
        do {
            _ = try await m.createPhaseTask(
                title: title,
                description: nil,
                assignedTo: nil,
                createdBy: uid,
                dueDate: nil,
                priority: .medium,
                sectionId: section?.id,
                sectionName: section?.name,
                phaseId: phase.id ?? "",
                projectId: project.id ?? "",
                order: nil
            )
            await reload()
        } catch { }
    }
    
    // Quick add helper is defined in outer view
    
    func reorderTasks(in section: PhaseSection, moveFrom source: IndexSet, to destination: Int) async {
        guard let m = taskManager else { return }
        var items = tasksIn(sectionId: section.id)
        items.move(fromOffsets: source, toOffset: destination)
        do { try await m.reorderTasksInSection(items, phaseId: phaseId, projectId: projectId, sectionId: section.id) } catch { }
        await MainActor.run { self.tasks = mergeReordered(items, for: section.id) }
    }
    
    private func tasksIn(sectionId: String?) -> [ShigodekiTask] {
        if sectionId == nil || sectionId == "" { return tasks.filter { ($0.sectionId ?? "").isEmpty } }
        return tasks.filter { $0.sectionId == sectionId }
    }
    
    private func mergeReordered(_ reordered: [ShigodekiTask], for sectionId: String?) -> [ShigodekiTask] {
        var all = tasks
        let ids = Set(reordered.compactMap { $0.id })
        all.removeAll { ids.contains($0.id ?? "") && (($0.sectionId ?? "") == (sectionId ?? "")) }
        all.append(contentsOf: reordered)
        return all
    }
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Drag & Drop helpers
private extension PhaseTaskView {
    func handleDrop(providers: [NSItemProvider], into section: PhaseSection) -> Bool {
        let typeId = UTType.text.identifier
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(typeId) }) else { return false }
        provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, _ in
            if let data = item as? Data, let id = String(data: data, encoding: .utf8) {
                dropMove(taskId: id, to: section)
            } else if let str = item as? String {
                dropMove(taskId: str, to: section)
            }
        }
        return true
    }
    func dropMove(taskId: String, to section: PhaseSection) {
        guard let task = taskVM.tasks.first(where: { $0.id == taskId }) else { return }
        Task { await taskVM.moveTask(task, to: section, project: project, phase: phase) }
    }
}

// MARK: - Rename Section Sheet
private struct RenameSectionSheet: View {
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
            Form { TextField("セクション名", text: $name) }
                .navigationTitle("名称変更")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { dismiss() } }
                    ToolbarItem(placement: .navigationBarTrailing) { Button("保存") { onSave(name.trimmingCharacters(in: .whitespacesAndNewlines)); dismiss() } }
                }
        }
    }
}
