//
//  DashboardTaskDetailView.swift
//  shigodeki
//
//  Lazy loader that resolves project/phase/list context for a dashboard
//  summary and presents the existing task views.
//

import SwiftUI

struct DashboardTaskDetailView: View {
    let summary: DashboardTaskSummary

    @EnvironmentObject private var sharedManagers: SharedManagerStore
    @State private var project: Project?
    @State private var phase: Phase?
    @State private var taskList: TaskList?
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.error)
                    Text(loadError)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .navigationTitle(summary.projectName)
            } else if let project {
                if let list = taskList, let phase {
                    TaskListDetailView(taskList: list, phase: phase, project: project)
                } else if let phase {
                    PhaseTaskView(phase: phase, project: project)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("関連フェーズを読み込めませんでした")
                            .foregroundColor(.secondary)
                        Button("プロジェクトを開く") {
                            NotificationCenter.default.post(name: .projectTabSelected, object: nil)
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            } else {
                ProgressView("読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(summary.projectName)
        .task { await ensureLoaded() }
    }

    // MARK: - Loading

    private func ensureLoaded() async {
        guard project == nil || (summary.task.listId.isEmpty == false && taskList == nil) else { return }
        await loadDetail()
    }

    private func loadDetail() async {
        guard isLoading == false else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let projectManager = sharedManagers.getProjectManager()
            async let phaseManager = sharedManagers.getPhaseManager()
            async let taskListManager = sharedManagers.getTaskListManager()

            let (pm, phm, tlm) = await (projectManager, phaseManager, taskListManager)

            let resolvedProject = try await resolveProject(using: pm)
            let resolvedPhase = try await resolvePhase(using: phm, projectId: resolvedProject?.id ?? summary.task.projectId)
            let resolvedTaskList = try await resolveTaskList(using: tlm, phaseId: resolvedPhase?.id ?? summary.task.phaseId)

            project = resolvedProject
            phase = resolvedPhase
            taskList = resolvedTaskList

            if project == nil {
                loadError = "プロジェクト情報を取得できませんでした"
            }
        } catch {
            #if DEBUG
            print("❌ DashboardTaskDetailView.loadDetail: \(error)")
            #endif
            loadError = error.localizedDescription
        }
    }

    private func resolveProject(using manager: ProjectManager) async throws -> Project? {
        if let cached = manager.projects.first(where: { $0.id == summary.task.projectId }) {
            return cached
        }
        return try await manager.getProject(id: summary.task.projectId)
    }

    private func resolvePhase(using manager: PhaseManager, projectId: String?) async throws -> Phase? {
        guard !summary.task.phaseId.isEmpty else { return nil }
        if let cached = manager.phases.first(where: { $0.id == summary.task.phaseId }) {
            return cached
        }
        guard let projectId else { return try await manager.getPhase(id: summary.task.phaseId, projectId: summary.task.projectId) }
        return try await manager.getPhase(id: summary.task.phaseId, projectId: projectId)
    }

    private func resolveTaskList(using manager: TaskListManager, phaseId: String?) async throws -> TaskList? {
        guard summary.task.listId.isEmpty == false else { return nil }
        if let cached = manager.taskLists.first(where: { $0.id == summary.task.listId }) {
            return cached
        }
        guard let phaseId else { return try await manager.getTaskList(id: summary.task.listId, phaseId: summary.task.phaseId, projectId: summary.task.projectId) }
        return try await manager.getTaskList(id: summary.task.listId, phaseId: phaseId, projectId: summary.task.projectId)
    }
}
