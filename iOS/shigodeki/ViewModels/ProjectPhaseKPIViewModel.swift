//
//  ProjectPhaseKPIViewModel.swift
//  shigodeki
//
//  Phase 4: Supplies per-phase KPI metrics for ProjectDetailView.
//

import Foundation

@MainActor
final class ProjectPhaseKPIViewModel: ObservableObject {
    @Published private(set) var metrics: [ProjectPhaseKPIs] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?

    private var projectId: String
    private let dataSource = KPIDataSource.shared
    private let store = KPIStore.shared

    private let cacheTTL: TimeInterval = 5 * 60
    private var loadTask: Task<Void, Never>?

    init(projectId: String) {
        self.projectId = projectId
    }

    deinit {
        loadTask?.cancel()
    }

    func start() {
        guard !projectId.isEmpty else { return }

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.loadFromCacheOrFetch()
        }
    }

    func manualRefresh() {
        guard !projectId.isEmpty else { return }

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.fetchAndStore()
        }
    }

    func updateProjectId(_ newValue: String) {
        guard projectId != newValue else { return }
        projectId = newValue
        start()
    }

    private func loadFromCacheOrFetch() async {
        if let cached = await store.cachedPhaseMetrics(for: projectId, maxAge: cacheTTL) {
            metrics = cached
            isLoading = false
            error = nil
            return
        }

        await fetchAndStore()
    }

    private func fetchAndStore() async {
        isLoading = true
        error = nil

        do {
            let tasks = try await dataSource.fetchTasks(projectIds: [projectId])
            let metrics = PortfolioKPIEngine.computeProjectPhaseKPIs(tasks: tasks, projectId: projectId)
            await store.storePhaseMetrics(metrics, for: projectId)
            self.metrics = metrics
            self.isLoading = false
        } catch {
            self.isLoading = false
            self.error = error
        }
    }
}
