//
//  PortfolioKPIEngine.swift
//  shigodeki
//
//  Pure functions to compute portfolio and project phase KPI metrics.
//

import Foundation

enum PortfolioKPIEngine {
    static func computePortfolioKPIs(tasks: [TaskLite], now: Date = Date()) -> PortfolioKPIs {
        guard !tasks.isEmpty else {
            return PortfolioKPIs(
                overdue: 0,
                completionTrend: [],
                deadlineHeatmap: [],
                updatedAt: now
            )
        }

        let total = tasks.count
        let completed = tasks.filter { $0.isCompleted }.count

        let overdue = tasks.filter { !$0.isCompleted && ($0.dueDate ?? now) < now }.count

        let trend = generateCompletionTrend(tasks: tasks, total: total, now: now)
        let heatmap = generateHeatmap(tasks: tasks, now: now)

        let updatedAt = tasks.compactMap { $0.updatedAt ?? $0.completedAt ?? $0.createdAt }.max() ?? now

        return PortfolioKPIs(
            overdue: overdue,
            completionTrend: trend,
            deadlineHeatmap: heatmap,
            updatedAt: updatedAt
        )
    }

    static func computeProjectPhaseKPIs(tasks: [TaskLite], projectId: String) -> [ProjectPhaseKPIs] {
        let projectTasks = tasks.filter { $0.projectId == projectId }
        guard !projectTasks.isEmpty else { return [] }

        let grouped = Dictionary(grouping: projectTasks) { $0.phaseId ?? "unknown" }
        let now = Date()

        return grouped.map { phaseId, tasks in
            let total = tasks.count
            let completed = tasks.filter { $0.isCompleted }.count
            let completion = total > 0 ? Double(completed) / Double(total) : 0

            let blockers = tasks
                .filter { !$0.isCompleted && (($0.dueDate ?? now) < now || !$0.dependsOn.isEmpty) }
                .sorted { ($0.dueDate ?? now) < ($1.dueDate ?? now) }
                .prefix(3)
                .map { ProjectPhaseKPIs.TaskRef(id: $0.id, title: $0.title) }

            var dependencyCounts: [String: Int] = [:]
            for task in tasks {
                for dep in task.dependsOn {
                    dependencyCounts[dep, default: 0] += 1
                }
            }
            let dependencies = dependencyCounts
                .map { ProjectPhaseKPIs.DepEdge(phaseId: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count }
                .prefix(3)
                .map { $0 }

            return ProjectPhaseKPIs(
                phaseId: phaseId,
                completion: completion,
                blockers: Array(blockers),
                deps: Array(dependencies)
            )
        }
    }

    private static func generateCompletionTrend(tasks: [TaskLite], total: Int, now: Date) -> [PortfolioKPIs.CompletionSample] {
        let calendar = Calendar.current
        var points: [PortfolioKPIs.CompletionSample] = []
        for dayOffset in stride(from: 6, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: day) ?? day
            let completed = tasks.filter { $0.completedAt ?? Date.distantPast <= dayEnd && $0.isCompleted }.count
            let completion = total > 0 ? Double(completed) / Double(total) : 0
            points.append(PortfolioKPIs.CompletionSample(date: day, completion: completion))
        }
        return points
    }

    private static func generateHeatmap(tasks: [TaskLite], now: Date) -> [PortfolioKPIs.HeatmapBin] {
        var bins: [PortfolioKPIs.HeatmapBin] = []
        var counts: [String: Int] = [:]
        let calendar = Calendar.current

        for task in tasks {
            guard let due = task.dueDate else { continue }
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: due)
            let year = components.yearForWeekOfYear ?? calendar.component(.year, from: due)
            let week = components.weekOfYear ?? calendar.component(.weekOfYear, from: due)
            let urgency = urgencyBucket(for: task, now: now)
            let key = "\(year)-\(week)-\(urgency)"
            counts[key, default: 0] += 1
        }

        for (key, count) in counts {
            let parts = key.split(separator: "-")
            guard parts.count == 3,
                  let year = Int(parts[0]),
                  let week = Int(parts[1]),
                  let urgency = Int(parts[2]) else { continue }
            bins.append(PortfolioKPIs.HeatmapBin(weekOfYear: week, year: year, urgency: urgency, count: count))
        }
        return bins.sorted { lhs, rhs in
            if lhs.year == rhs.year {
                if lhs.weekOfYear == rhs.weekOfYear { return lhs.urgency < rhs.urgency }
                return lhs.weekOfYear < rhs.weekOfYear
            }
            return lhs.year < rhs.year
        }
    }

    private static func urgencyBucket(for task: TaskLite, now: Date) -> Int {
        if let raw = task.priorityRaw, let priority = TaskPriority(rawValue: raw) {
            switch priority {
            case .low: return 0
            case .medium: return 1
            case .high: return 2
            }
        }
        guard let due = task.dueDate else { return 0 }
        let interval = due.timeIntervalSince(now)
        if interval < 0 { return 2 }
        if interval <= 48 * 3600 { return 2 }
        if interval <= 7 * 24 * 3600 { return 1 }
        return 0
    }
}
