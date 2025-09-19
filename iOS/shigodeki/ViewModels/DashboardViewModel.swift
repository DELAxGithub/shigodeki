//
//  DashboardViewModel.swift
//  shigodeki
//
//  Aggregates data for the DashboardView without adding extra Firestore listeners.
//

import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var myTasks: [DashboardTaskSummary] = []
    @Published private(set) var aiDrafts: [TaskDraft] = []
    @Published var isLoadingAssignments = false
    @Published var errorMessage: String?

    private let sharedStore: SharedManagerStore
    private var aiGeneratorCancellable: AnyCancellable?
    private var refreshTask: Task<Void, Never>?
    private var lastRefreshTriggerAt: Date?

    private var projectNameCache: [String: String] = [:]
    private var phaseNameCache: [String: String] = [:]
    private var listNameCache: [String: String] = [:]

    private let debounceInterval: TimeInterval = 0.35

    init(sharedStore: SharedManagerStore = .shared) {
        self.sharedStore = sharedStore
        observeGenerator()
    }

    func triggerRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }

            if let last = self.lastRefreshTriggerAt {
                let elapsed = Date().timeIntervalSince(last)
                if elapsed < self.debounceInterval {
                    let delay = UInt64((self.debounceInterval - elapsed) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delay)
                }
            }

            self.lastRefreshTriggerAt = Date()
            await self.loadAssignments()
            await self.syncGeneratorState()
            await MainActor.run { self.refreshTask = nil }
        }
    }

    func markAIDraftsConsumed() {
        aiDrafts = []
    }

    // MARK: - Private

    private func observeGenerator() {
        Task { [weak self] in
            guard let self else { return }
            let generator = await self.sharedStore.getAiGenerator()
            await MainActor.run {
                self.bindGenerator(generator)
            }
        }
    }

    private func bindGenerator(_ generator: AITaskGenerator) {
        aiGeneratorCancellable = generator.$generatedSuggestions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] suggestion in
                guard let self else { return }
                guard FeatureFlags.previewAIEnabled else {
                    self.aiDrafts = []
                    return
                }
                if let suggestion {
                    self.aiDrafts = AIDraftMapper.map(from: suggestion)
                } else {
                    self.aiDrafts = []
                }
            }
    }

    private func syncGeneratorState() async {
        // Ensure current generator snapshot is reflected when the view appears before
        // Combine delivers a new value (e.g., after cold start).
        if aiDrafts.isEmpty {
            let generator = await sharedStore.getAiGenerator()
            if let suggestion = generator.generatedSuggestions, FeatureFlags.previewAIEnabled {
                aiDrafts = AIDraftMapper.map(from: suggestion)
            }
        }
    }

    private func loadAssignments() async {
        guard refreshTask?.isCancelled == false else { return }

        isLoadingAssignments = true
        errorMessage = nil

        do {
            async let authManager = sharedStore.getAuthManager()
            async let service = sharedStore.getDashboardService()
            async let projectManager = sharedStore.getProjectManager()
            async let phaseManager = sharedStore.getPhaseManager()
            async let taskListManager = sharedStore.getTaskListManager()

            let (auth, dashboardService, pm, phm, tlm) = await (authManager, service, projectManager, phaseManager, taskListManager)
            guard let userId = auth.currentUser?.id else {
                myTasks = []
                isLoadingAssignments = false
                return
            }

            let records = try await dashboardService.fetchAssignedTasks(for: userId, limit: 20)
            let summaries = await mapRecords(records, projectManager: pm, phaseManager: phm, taskListManager: tlm)

            myTasks = summaries
            isLoadingAssignments = false
        } catch {
            #if DEBUG
            print("❌ DashboardViewModel.loadAssignments error: \(error)")
            #endif
            myTasks = []
            isLoadingAssignments = false
            errorMessage = error.localizedDescription
        }
    }

    private func mapRecords(
        _ records: [DashboardTaskRecord],
        projectManager: ProjectManager,
        phaseManager: PhaseManager,
        taskListManager: TaskListManager
    ) async -> [DashboardTaskSummary] {
        var results: [DashboardTaskSummary] = []
        results.reserveCapacity(records.count)

        for record in records {
            let task = record.task
            let projectName = await resolveProjectName(task.projectId, projectManager: projectManager)
            let phaseName = await resolvePhaseName(phaseId: task.phaseId, projectId: task.projectId, phaseManager: phaseManager)
            let listName = await resolveListName(task.listId, phaseId: task.phaseId, projectId: task.projectId, taskListManager: taskListManager)

            results.append(
                DashboardTaskSummary(
                    task: task,
                    projectName: projectName,
                    phaseName: phaseName,
                    listName: listName
                )
            )
        }

        return results
    }

    private func resolveProjectName(_ projectId: String, projectManager: ProjectManager) async -> String {
        if let cached = projectNameCache[projectId] { return cached }
        if let existing = projectManager.projects.first(where: { $0.id == projectId }) {
            projectNameCache[projectId] = existing.name
            return existing.name
        }
        if let project = try? await projectManager.getProject(id: projectId) {
            projectNameCache[projectId] = project.name
            return project.name
        }
        return "プロジェクト"
    }

    private func resolvePhaseName(phaseId: String, projectId: String, phaseManager: PhaseManager) async -> String? {
        guard !phaseId.isEmpty else { return nil }
        if let cached = phaseNameCache[phaseId] { return cached }
        if let phase = phaseManager.phases.first(where: { $0.id == phaseId }) {
            phaseNameCache[phaseId] = phase.name
            return phase.name
        }
        if let phase = try? await phaseManager.getPhase(id: phaseId, projectId: projectId) {
            phaseNameCache[phaseId] = phase.name
            return phase.name
        }
        return nil
    }

    private func resolveListName(_ listId: String, phaseId: String, projectId: String, taskListManager: TaskListManager) async -> String? {
        guard listId.isEmpty == false else { return nil }
        if let cached = listNameCache[listId] { return cached }
        if let list = taskListManager.taskLists.first(where: { $0.id == listId }) {
            listNameCache[listId] = list.name
            return list.name
        }
        if let list = try? await taskListManager.getTaskList(id: listId, phaseId: phaseId, projectId: projectId) {
            listNameCache[listId] = list.name
            return list.name
        }
        return nil
    }
}

struct DashboardTaskSummary: Identifiable, Equatable, Hashable {
    let task: ShigodekiTask
    let projectName: String
    let phaseName: String?
    let listName: String?

    var id: String { task.id ?? UUID().uuidString }

    var subtitle: String {
        if let listName, !listName.isEmpty {
            return "\(projectName) › \(listName)"
        }
        if let phaseName, !phaseName.isEmpty {
            return "\(projectName) › \(phaseName)"
        }
        return projectName
    }
}
