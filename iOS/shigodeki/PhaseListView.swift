//
//  PhaseListView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct PhaseListView: View {
    let project: Project
    @ObservedObject var phaseManager: PhaseManager
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @StateObject private var authManager = AuthenticationManager()
    @State private var showingCreatePhase = false
    @State private var selectedPhase: Phase?
    @State private var selectedPhaseId: String? = nil
    @Environment(\.dismiss) private var dismiss
    var onSelectPhase: ((Phase) -> Void)? = nil
    @State private var listCounts: [String: Int] = [:] // now represents section counts
    var onSelectTaskList: ((TaskList, Phase) -> Void)? = nil
    
    var body: some View {
        VStack {
            BreadcrumbBar(items: [project.name, "フェーズ"]) { idx in
                print("UI: Breadcrumb tapped idx=\(idx) at PhaseListView")
                if idx == 0 { dismiss() }
            }
                .padding(.horizontal)
            if phaseManager.phases.isEmpty && !phaseManager.isLoading {
                // Empty phases state
                VStack(spacing: 24) {
                    Image(systemName: "list.number")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 8) {
                        Text("フェーズがありません")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("プロジェクトを段階的に進めるため\nフェーズを作成しましょう")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        showingCreatePhase = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("フェーズを作成")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
                .padding()
                
            } else {
                // Hidden navigator driven by selectedPhaseId for robust push
                NavigationLink(
                    isActive: Binding(
                        get: { selectedPhaseId != nil },
                        set: { if !$0 { selectedPhaseId = nil } }
                    )
                ) {
                    if let pid = selectedPhaseId, let p = phaseManager.phases.first(where: { $0.id == pid }) {
                        PhaseTaskView(phase: p, project: project)
                    } else {
                        EmptyView()
                    }
                } label: { EmptyView() }
                .hidden()
                List {
                    ForEach(phaseManager.phases) { phase in
                        if let onSelectPhase {
                            Button { onSelectPhase(phase) } label: {
                                PhaseRowView(phase: phase, phaseManager: phaseManager, taskListCount: listCounts[phase.id ?? ""])
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                HapticFeedbackManager.shared.light()
                                if let pid = phase.id { selectedPhaseId = pid }
                                print("UI: Phase tapped -> \(phase.name) [id=\(phase.id ?? "")] ")
                            } label: {
                                PhaseRowView(phase: phase, phaseManager: phaseManager, taskListCount: listCounts[phase.id ?? ""])
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onMove(perform: movePhases)
                    .onDelete(perform: deletePhases)
                }
                .refreshable {
                    await loadPhases()
                }
            }
        }
        .loadingOverlay(phaseManager.isLoading, message: "フェーズを更新中...")
        .navigationTitle("フェーズ")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    showingCreatePhase = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            loadPhases()
            startListeningToPhases()
            Task { await loadListCounts() }
        }
        .onChange(of: phaseManager.phases.count) { _, _ in
            Task { await loadListCounts() }
        }
        .sheet(isPresented: $showingCreatePhase) {
            CreatePhaseView(project: project, phaseManager: phaseManager)
        }
        .alert("エラー", isPresented: .constant(phaseManager.error != nil)) {
            Button("OK") {
                phaseManager.error = nil
            }
        } message: {
            Text(phaseManager.error?.localizedDescription ?? "")
        }
    }
    
    private func loadPhases() {
        guard let projectId = project.id else { return }
        
        Task {
            do {
                let phases = try await phaseManager.getPhases(projectId: projectId)
                await MainActor.run {
                    phaseManager.phases = phases
                }
                print("📥 PhaseListView: Loaded \(phases.count) phases for project \(projectId)")
            } catch {
                print("Error loading phases: \(error)")
            }
        }
    }
    
    private func loadListCounts() async {
        guard let projectId = project.id else { return }
        var result: [String: Int] = [:]
        let sectionManager = PhaseSectionManager()
        for ph in phaseManager.phases {
            guard let pid = ph.id else { continue }
            do {
                let sections = try await sectionManager.getSections(phaseId: pid, projectId: projectId)
                result[pid] = sections.count
            } catch { }
        }
        await MainActor.run { self.listCounts = result }
    }
    
    private func startListeningToPhases() {
        guard let projectId = project.id else { return }
        phaseManager.startListeningForPhases(projectId: projectId)
    }
    
    private func movePhases(from source: IndexSet, to destination: Int) {
        var reorderedPhases = phaseManager.phases
        reorderedPhases.move(fromOffsets: source, toOffset: destination)
        // Optimistic local update to reflect immediately
        phaseManager.phases = reorderedPhases
        print("UI: Phase reorder gesture from=\(Array(source)) to=\(destination); newOrder=\(reorderedPhases.map{ $0.name })")
        
        guard let projectId = project.id else { return }
        
        Task {
            do {
                try await phaseManager.reorderPhases(reorderedPhases, projectId: projectId)
            } catch {
                print("Error reordering phases: \(error)")
            }
        }
    }
    
    private func deletePhases(at offsets: IndexSet) {
        guard let projectId = project.id else { return }
        
        for index in offsets {
            let phase = phaseManager.phases[index]
            guard let phaseId = phase.id else { continue }
            
            Task {
                do {
                    try await phaseManager.deletePhase(id: phaseId, projectId: projectId)
                } catch {
                    print("Error deleting phase: \(error)")
                }
            }
        }
    }
}

// MARK: - Phase Task List View

struct PhaseTaskListView: View {
    let phase: Phase
    let project: Project
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @StateObject private var viewModelHolder = _VMHolder()
    @StateObject private var authManager = AuthenticationManager()
    @State private var showingCreateTaskList = false
    // Feature toggle: whether to skip list layer automatically
    private let skipListLayer: Bool = false
    @State private var autoNavigate = false
    @State private var didAutoNavigate = false
    @State private var autoList: TaskList? = nil
    @Environment(\.dismiss) private var dismiss
    var onSelectTaskList: ((TaskList, Phase) -> Void)? = nil
    var onTapProject: (() -> Void)? = nil
    
    var body: some View {
        VStack {
            // Hidden link for auto-navigation when feature enabled
            if skipListLayer {
                NavigationLink(isActive: $autoNavigate) {
                    if let l = autoList {
                        TaskListDetailView(taskList: l, phase: phase, project: project)
                    } else {
                        EmptyView()
                    }
                } label: { EmptyView() }
                .hidden()
            }
            BreadcrumbBar(items: [project.name, phase.name]) { idx in
                print("UI: Breadcrumb tapped idx=\(idx) at PhaseTaskListView")
                if idx == 0 {
                    if let onTapProject { onTapProject() } else { dismiss() }
                }
            }
                .padding(.horizontal)
            let isLoading = viewModelHolder.vm?.isLoading ?? false
            let lists = viewModelHolder.vm?.lists ?? []
            if lists.isEmpty && !isLoading {
                // Empty task lists state
                VStack(spacing: 24) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 8) {
                        Text("タスクリストがありません")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("このフェーズのタスクを管理するため\nタスクリストを作成しましょう")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        showingCreateTaskList = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("タスクリストを作成")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
                .padding()
                
            } else {
                List {
                    ForEach(lists) { taskList in
                        if let onSelectTaskList {
                            Button { onSelectTaskList(taskList, phase) } label: {
                                PhaseTaskListRowView(taskList: taskList)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(destination: TaskListDetailView(taskList: taskList, phase: phase, project: project)) {
                                PhaseTaskListRowView(taskList: taskList)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                print("UI: TaskList tapped -> \(taskList.name) [id=\(taskList.id ?? "")] in phase \(phase.name)")
                            })
                        }
                    }
                }
                .refreshable {
                    await viewModelHolder.vm?.reload()
                }
            }
        }
        .loadingOverlay(viewModelHolder.vm?.isLoading ?? false, message: "タスクリストを更新中...")
        .navigationTitle(phase.name)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    showingCreateTaskList = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            if viewModelHolder.vm == nil, let phaseId = phase.id, let projectId = project.id {
                let vm = PhaseTaskListViewModel(phaseId: phaseId, projectId: projectId)
                viewModelHolder.vm = vm
                await vm.bootstrap(store: sharedManagers)
                // Auto-route when exactly one list exists
                if skipListLayer {
                    let currentLists = vm.lists
                    if currentLists.count == 1 && !didAutoNavigate {
                        autoList = currentLists.first
                        didAutoNavigate = true
                        DispatchQueue.main.async {
                            self.autoNavigate = true
                        }
                    } else if currentLists.isEmpty && !didAutoNavigate {
                        await createDefaultListAndNavigate()
                    }
                }
            }
        }
        .onChange(of: viewModelHolder.vm?.lists.count ?? 0) { _, newCount in
            if skipListLayer {
                if newCount == 1 && !didAutoNavigate {
                    let currentLists = viewModelHolder.vm?.lists ?? []
                    autoList = currentLists.first
                    didAutoNavigate = true
                    DispatchQueue.main.async {
                        self.autoNavigate = true
                    }
                } else if newCount == 0 && !didAutoNavigate {
                    Task { await createDefaultListAndNavigate() }
                }
            }
        }
        .sheet(isPresented: $showingCreateTaskList) {
            CreatePhaseTaskListSheet(phase: phase, project: project)
                .environmentObject(sharedManagers)
        }
    }

    // Create a default task list when none exists, then navigate
    private func createDefaultListAndNavigate() async {
        guard let phaseId = phase.id, let projectId = project.id else { return }
        do {
            let taskListManager = await sharedManagers.getTaskListManager()
            let auth = await sharedManagers.getAuthManager()
            let uid = auth.currentUserId ?? ""
            let created = try await taskListManager.createTaskList(
                name: "ToDo",
                phaseId: phaseId,
                projectId: projectId,
                createdBy: uid,
                color: .blue,
                order: nil
            )
            await MainActor.run {
                autoList = created
                didAutoNavigate = true
                autoNavigate = true
            }
        } catch {
            print("Auto-create default list failed: \(error)")
        }
    }
}

// Wrapper to bridge VM and keep access to underlying manager for sheet
private final class _VMHolder: ObservableObject {
    @Published var vm: PhaseTaskListViewModel?
}

private struct CreatePhaseTaskListSheet: View {
    let phase: Phase
    let project: Project
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @State private var manager: TaskListManager? = nil
    
    var body: some View {
        Group {
            if let m = manager {
                CreatePhaseTaskListView(phase: phase, project: project, taskListManager: m)
            } else {
                LoadingStateView(message: "タスクリスト準備中...")
                    .padding()
            }
        }
        .task {
            if manager == nil { manager = await sharedManagers.getTaskListManager() }
        }
    }
}

// MARK: - Supporting Views

struct PhaseTaskListRowView: View {
    let taskList: TaskList
    @State private var taskCount: Int? = nil
    
    var body: some View {
        HStack {
            Circle()
                .fill(taskList.color.swiftUIColor)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(taskList.name)
                    .font(.headline)
                
                Text("\(taskCount ?? 0)個のタスク")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .task(id: taskList.id) {
            await loadTaskCount()
        }
    }
    
    private func loadTaskCount() async {
        guard let listId = taskList.id else { return }
        let manager = EnhancedTaskManager()
        do {
            let tasks = try await manager.getTasks(listId: listId, phaseId: taskList.phaseId, projectId: taskList.projectId)
            await MainActor.run { taskCount = tasks.count }
        } catch {
            // keep nil
        }
    }
}

// MARK: - Breadcrumb Bar
struct BreadcrumbBar: View {
    let items: [String]
    var onTap: ((Int) -> Void)? = nil
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, label in
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.caption)
                            .foregroundColor(idx == items.count - 1 ? .primary : .secondary)
                        if idx < items.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?(idx) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Task Editor
struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var task: ShigodekiTask
    let listId: String
    let phaseId: String
    let projectId: String
    @ObservedObject var enhancedTaskManager: EnhancedTaskManager
    @StateObject private var subtaskManager = SubtaskManager()
    @StateObject private var projectManager = ProjectManager()
    @StateObject private var authManager = AuthenticationManager()
    @State private var subtasks: [Subtask] = []
    @State private var isSaving = false
    @State private var newSubtaskTitle: String = ""
    @State private var projectMembers: [ProjectMember] = []
    @State private var selectedAssignee: String? = nil
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
                            Text("あなた（\(authManager.currentUser?.name ?? myId)）").tag(Optional(myId))
                        }
                        ForEach(projectMembers, id: \.userId) { member in
                            if member.userId != authManager.currentUserId {
                                Text(member.displayName ?? short(member.userId)).tag(Optional(member.userId))
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
        Task { do { let members = try await projectManager.getProjectMembers(projectId: projectId); await MainActor.run { self.projectMembers = members } } catch { print(error) } }
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
                desc += "\n\nAI提案:\n" + (first.description ?? "")
                task.description = desc
            }
        }
    }
}

struct TaskListDetailView: View {
    let taskList: TaskList
    let phase: Phase
    let project: Project
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @StateObject private var viewModelHolder = _TaskListVMHolder()
    @StateObject private var authManager = AuthenticationManager()
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
        
        return try snapshot.documents.compactMap { document in
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

struct CreatePhaseTaskListView: View {
    let phase: Phase
    let project: Project
    @ObservedObject var taskListManager: TaskListManager
    @Environment(\.presentationMode) var presentationMode
    @State private var taskListName = ""
    @State private var selectedColor: TaskListColor = .blue
    
    var body: some View {
        NavigationView {
            Form {
                TextField("タスクリスト名", text: $taskListName)
                
                Section("色") {
                    ColorSelectionGrid(selectedColor: $selectedColor)
                }
            }
            .navigationTitle("新しいタスクリスト")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        createTaskList()
                    }
                    .disabled(taskListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func createTaskList() {
        guard let phaseId = phase.id, let projectId = project.id else { return }
        let name = taskListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        if let userId = AuthenticationManager().currentUserId {
            Task {
                do {
                    _ = try await taskListManager.createTaskList(
                        name: name,
                        phaseId: phaseId,
                        projectId: projectId,
                        createdBy: userId,
                        color: selectedColor,
                        order: nil
                    )
                    await MainActor.run {
                        presentationMode.wrappedValue.dismiss()
                    }
                } catch {
                    print("Error creating task list: \(error)")
                }
            }
        }
    }
}

struct ColorSelectionGrid: View {
    @Binding var selectedColor: TaskListColor
    
    var body: some View {
        let columns = Array(repeating: GridItem(.flexible()), count: 4)
        LazyVGrid(columns: columns) {
            ForEach(TaskListColor.allCases, id: \.self) { color in
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                    )
                    .onTapGesture {
                        selectedColor = color
                    }
            }
        }
    }
}

struct CreatePhaseTaskView: View {
    let taskList: TaskList
    let phase: Phase
    let project: Project
    @ObservedObject var taskManager: TaskManager
    @StateObject private var authManager = AuthenticationManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var taskTitle: String = ""
    @State private var taskDescription: String = ""
    @State private var selectedPriority: TaskPriority = .medium
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("タスク詳細")) {
                    TextField("タスクタイトル", text: $taskTitle)
                    TextField("説明（オプション）", text: $taskDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("優先度")) {
                    Picker("優先度", selection: $selectedPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(priority.swiftUIColor)
                                    .frame(width: 12, height: 12)
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            .navigationTitle("新しいタスク")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        createTask()
                    }
                    .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createTask() {
        guard let userId = authManager.currentUser?.id,
              let taskListId = taskList.id,
              let phaseId = phase.id,
              let projectId = project.id else { return }
        
        isCreating = true
        
        Task {
            do {
                _ = try await taskManager.createPhaseTask(
                    title: taskTitle,
                    description: taskDescription.isEmpty ? nil : taskDescription,
                    taskListId: taskListId,
                    projectId: projectId,
                    phaseId: phaseId,
                    creatorUserId: userId,
                    priority: selectedPriority
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error creating task: \(error)")
                isCreating = false
            }
        }
    }
}

#Preview {
    let sampleProject = Project(name: "Sample Project", description: "A sample project for preview", ownerId: "user1")
    PhaseListView(project: sampleProject, phaseManager: PhaseManager())
}
