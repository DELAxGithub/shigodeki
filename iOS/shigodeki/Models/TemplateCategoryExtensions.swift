//
//  TemplateCategoryExtensions.swift
//  shigodeki
//
//  Extracted from ProjectTemplate.swift for CLAUDE.md compliance
//  Template category and difficulty enums with UI extensions
//

import Foundation
import SwiftUI

enum TemplateCategory: String, CaseIterable, Codable, Hashable {
    case softwareDevelopment = "software_development"
    case projectManagement = "project_management"
    case eventPlanning = "event_planning"
    case lifeEvents = "life_events"
    case business = "business"
    case education = "education"
    case creative = "creative"
    case personal = "personal"
    case health = "health"
    case travel = "travel"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .softwareDevelopment: return "ソフトウェア開発"
        case .projectManagement: return "プロジェクト管理"
        case .eventPlanning: return "イベント企画"
        case .lifeEvents: return "ライフイベント"
        case .business: return "ビジネス"
        case .education: return "教育・学習"
        case .creative: return "クリエイティブ"
        case .personal: return "個人"
        case .health: return "健康・フィットネス"
        case .travel: return "旅行"
        case .other: return "その他"
        }
    }
    
    var icon: String {
        switch self {
        case .softwareDevelopment: return "laptopcomputer"
        case .projectManagement: return "chart.bar.xaxis"
        case .eventPlanning: return "calendar.badge.plus"
        case .lifeEvents: return "house"
        case .business: return "briefcase"
        case .education: return "book"
        case .creative: return "paintbrush"
        case .personal: return "person"
        case .health: return "heart"
        case .travel: return "airplane"
        case .other: return "folder"
        }
    }
    
    var color: Color {
        switch self {
        case .softwareDevelopment: return .blue
        case .projectManagement: return .orange
        case .eventPlanning: return .green
        case .lifeEvents: return .purple
        case .business: return .red
        case .education: return .yellow
        case .creative: return .pink
        case .personal: return .gray
        case .health: return .mint
        case .travel: return .cyan
        case .other: return .secondary
        }
    }
}

enum TemplateDifficulty: String, CaseIterable, Codable, Hashable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .beginner: return "初級"
        case .intermediate: return "中級"
        case .advanced: return "上級"
        case .expert: return "エキスパート"
        }
    }
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .expert: return .red
        }
    }
    
    var stars: Int {
        switch self {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        case .expert: return 4
        }
    }
}