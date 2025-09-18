//
//  ProjectSummaryMetrics.swift
//  shigodeki
//
//  Lightweight container for family project card summaries.
//

import Foundation

struct ProjectSummaryMetrics: Equatable {
    struct UpcomingTask: Equatable, Identifiable {
        let id = UUID()
        let title: String
        let dueDate: Date?
    }

    let completion: Double
    let remainingCount: Int
    let upcomingTasks: [UpcomingTask]
    let lastUpdated: Date?
    let memberInitials: [String]
    let memberCount: Int

    static let empty = ProjectSummaryMetrics(
        completion: 0,
        remainingCount: 0,
        upcomingTasks: [],
        lastUpdated: nil,
        memberInitials: [],
        memberCount: 0
    )
}

