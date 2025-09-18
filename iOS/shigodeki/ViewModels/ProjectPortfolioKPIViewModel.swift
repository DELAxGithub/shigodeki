//
//  ProjectPortfolioKPIViewModel.swift
//  shigodeki
//
//  Phase 4: Drives portfolio-level KPI header on ProjectListView.
//

import Foundation

@MainActor
final class ProjectPortfolioKPIViewModel: ObservableObject {
    @Published private(set) var state: KPIState = .hidden

    private let dataSource = KPIDataSource.shared
    private let store = KPIStore.shared
    private let scheduler = KPIRefreshScheduler.shared

    private let cacheTTL: TimeInterval = 5 * 60
    private let staleThreshold: TimeInterval = 2 * 60

    private var projectIds: [String] = []
    private var cacheKey: String?
    private var refreshTask: Task<Void, Never>?
    private var schedulerRegistered = false

    deinit {
        refreshTask?.cancel()
    }

    func updateProjects(_ projects: [Project]) {
        guard FeatureFlags.kpiDashboardsEnabled else {
            reset()
            return
        }

        let ids = projects.compactMap { $0.id }
        guard !ids.isEmpty else {
            reset()
            return
        }

        let sortedKey = ids.sorted().joined(separator: ",")
        projectIds = ids
        cacheKey = "portfolio:" + sortedKey

        if schedulerRegistered == false {
            scheduler.register { [weak self] in
                guard let self else { return }
                Task { await self.refresh(force: false) }
            }
            schedulerRegistered = true
        }

        loadFromCacheOrFetch()
    }

    func refresh(force: Bool) async {
        guard FeatureFlags.kpiDashboardsEnabled else { return }
        guard !projectIds.isEmpty else { return }

        if !force, case .loading = state {
            return
        }

        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.fetchAndStore()
        }
        await refreshTask?.value
    }

    func manualRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.fetchAndStore()
        }
    }

    private func reset() {
        refreshTask?.cancel()
        projectIds = []
        cacheKey = nil
        state = .hidden
    }

    private func loadFromCacheOrFetch() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.loadFromCacheOrFetchAsync()
        }
    }

    private func loadFromCacheOrFetchAsync() async {
        guard !projectIds.isEmpty else {
            state = .hidden
            return
        }

        if let key = cacheKey,
           let (portfolio, _) = await store.cachedMetrics(for: key, maxAge: cacheTTL) {
            let isStale = Date().timeIntervalSince(portfolio.updatedAt) > staleThreshold
            state = .ready(kpis: portfolio, isStale: isStale)
        } else {
            await fetchAndStore()
        }
    }

    private func fetchAndStore() async {
        guard !projectIds.isEmpty else {
            state = .hidden
            return
        }

        state = .loading
        do {
            let tasks = try await dataSource.fetchTasks(projectIds: projectIds)
            let now = Date()
            let portfolio = PortfolioKPIEngine.computePortfolioKPIs(tasks: tasks, now: now)

            var phaseMetrics: [String: [ProjectPhaseKPIs]] = [:]
            for projectId in projectIds {
                let metrics = PortfolioKPIEngine.computeProjectPhaseKPIs(tasks: tasks, projectId: projectId)
                phaseMetrics[projectId] = metrics
                await store.storePhaseMetrics(metrics, for: projectId)
            }

            if let key = cacheKey {
                await store.storeMetrics(portfolio, phase: phaseMetrics, for: key)
            }

            let isStale = Date().timeIntervalSince(portfolio.updatedAt) > staleThreshold
            state = .ready(kpis: portfolio, isStale: isStale)
        } catch {
            if case .failed = state {
                return
            }
            state = .failed
        }
    }
}

