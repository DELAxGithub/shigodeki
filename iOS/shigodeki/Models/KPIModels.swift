//
//  KPIModels.swift
//  shigodeki
//
//  Shared data structures for KPI dashboards.
//

import Foundation

struct PortfolioKPIs: Equatable {
    struct CompletionSample: Equatable, Identifiable {
        let date: Date
        let completion: Double

        var id: Date { date }
    }

    struct HeatmapBin: Equatable, Identifiable {
        let weekOfYear: Int
        let year: Int
        let urgency: Int
        let count: Int

        var id: String { "\(year)-\(weekOfYear)-\(urgency)" }
    }

    let overdue: Int
    let completionTrend: [CompletionSample]
    let deadlineHeatmap: [HeatmapBin]
    let updatedAt: Date
}

struct ProjectPhaseKPIs: Equatable, Identifiable {
    struct TaskRef: Equatable, Identifiable {
        let id: String
        let title: String
    }

    struct DepEdge: Equatable, Identifiable {
        let phaseId: String
        let count: Int

        var id: String { phaseId }
    }

    let phaseId: String
    let completion: Double
    let blockers: [TaskRef]
    let deps: [DepEdge]

    var id: String { phaseId }
}

struct TaskLite: Equatable {
    let id: String
    let title: String
    let projectId: String
    let phaseId: String?
    let dueDate: Date?
    let createdAt: Date?
    let updatedAt: Date?
    let completedAt: Date?
    let priorityRaw: String?
    let isCompleted: Bool
    let dependsOn: [String]
}
