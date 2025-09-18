//
//  KPIStore.swift
//  shigodeki
//
//  Lightweight in-memory cache used by KPI dashboards.
//

import Foundation

actor KPIStore {
    static let shared = KPIStore()

    private var portfolioCache: [String: (portfolio: PortfolioKPIs, storedAt: Date)] = [:]
    private var phaseCache: [String: (metrics: [ProjectPhaseKPIs], storedAt: Date)] = [:]

    func cachedMetrics(for key: String, maxAge: TimeInterval) async -> (PortfolioKPIs, Date)? {
        guard let cached = portfolioCache[key] else { return nil }
        guard Date().timeIntervalSince(cached.storedAt) <= maxAge else { return nil }
        return (cached.portfolio, cached.storedAt)
    }

    func storeMetrics(_ portfolio: PortfolioKPIs, phase: [String: [ProjectPhaseKPIs]], for key: String) async {
        portfolioCache[key] = (portfolio, Date())
        for (projectId, metrics) in phase {
            phaseCache[projectId] = (metrics, Date())
        }
    }

    func cachedPhaseMetrics(for projectId: String, maxAge: TimeInterval) async -> [ProjectPhaseKPIs]? {
        guard let cached = phaseCache[projectId] else { return nil }
        guard Date().timeIntervalSince(cached.storedAt) <= maxAge else { return nil }
        return cached.metrics
    }

    func storePhaseMetrics(_ metrics: [ProjectPhaseKPIs], for projectId: String) async {
        phaseCache[projectId] = (metrics, Date())
    }
}
