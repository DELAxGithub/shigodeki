//
//  TemplateImportConversion.swift
//  shigodeki
//
//  Extracted from TemplateImporter.swift for CLAUDE.md compliance
//  Legacy template format conversion and parsing utilities
//

import Foundation

@MainActor
class TemplateImportConversion: ObservableObject {
    
    // MARK: - Legacy Format Conversion
    
    func convertFromLegacyFormat(_ legacy: LegacyJSONTemplate) throws -> ProjectTemplate {
        // カテゴリ変換
        let category = parseCategory(from: legacy.category)
        
        // フェーズ変換
        let phases = try legacy.steps.map { step in
            try convertLegacyPhase(step)
        }
        
        // メタデータ変換
        let metadata = TemplateMetadata(
            author: legacy.metadata?.author ?? "Unknown",
            createdAt: legacy.metadata?.createdAt ?? ISO8601DateFormatter().string(from: Date()),
            estimatedDuration: legacy.metadata?.estimatedDuration,
            difficulty: parseDifficulty(from: legacy.metadata?.difficulty),
            tags: legacy.metadata?.tags ?? [],
            language: "ja"
        )
        
        return ProjectTemplate(
            name: legacy.name,
            description: legacy.description,
            goal: legacy.goal,
            category: category,
            version: legacy.version ?? "1.0",
            phases: phases,
            metadata: metadata
        )
    }
    
    private func convertLegacyPhase(_ step: LegacyJSONTemplate.LegacyStep) throws -> PhaseTemplate {
        let tasks = step.tasks.map { convertLegacyTask($0) }
        
        let defaultTaskList = TaskListTemplate(
            name: "メインタスク",
            description: step.description,
            color: .blue,
            order: 0,
            tasks: tasks
        )
        
        return PhaseTemplate(
            title: step.title,
            description: step.description,
            order: step.order,
            prerequisites: step.prerequisites ?? [],
            templateReference: step.templateReference,
            estimatedDuration: step.estimatedDuration,
            taskLists: [defaultTaskList]
        )
    }
    
    private func convertLegacyTask(_ task: LegacyJSONTemplate.LegacyTask) -> TaskTemplate {
        let priority = parsePriority(from: task.priority)
        
        return TaskTemplate(
            title: task.title,
            description: task.description,
            priority: priority,
            estimatedDuration: task.estimatedDuration,
            deadline: task.deadline,
            tags: task.tags ?? [],
            templateLinks: task.templateLinks,
            isOptional: task.isOptional ?? false,
            estimatedHours: parseEstimatedHours(from: task.estimatedDuration),
            dependsOn: [],
            subtasks: []
        )
    }
    
    // MARK: - Parsing Utilities
    
    func parseCategory(from categoryString: String?) -> TemplateCategory {
        guard let categoryString = categoryString else { return .other }
        
        // 日本語カテゴリマッピング
        let mapping: [String: TemplateCategory] = [
            "ソフトウェア開発": .softwareDevelopment,
            "プロジェクト管理": .projectManagement,
            "イベント企画": .eventPlanning,
            "ライフイベント": .lifeEvents,
            "ビジネス": .business,
            "教育": .education,
            "クリエイティブ": .creative,
            "個人": .personal,
            "健康": .health,
            "旅行": .travel
        ]
        
        return mapping[categoryString] ?? TemplateCategory(rawValue: categoryString.lowercased().replacingOccurrences(of: " ", with: "_")) ?? .other
    }
    
    func parseDifficulty(from difficultyString: String?) -> TemplateDifficulty {
        guard let difficultyString = difficultyString else { return .intermediate }
        
        let mapping: [String: TemplateDifficulty] = [
            "low": .beginner,
            "medium": .intermediate,
            "high": .advanced,
            "expert": .expert,
            "初級": .beginner,
            "中級": .intermediate,
            "上級": .advanced,
            "エキスパート": .expert
        ]
        
        return mapping[difficultyString] ?? .intermediate
    }
    
    func parsePriority(from priorityString: String?) -> TaskPriority {
        guard let priorityString = priorityString else { return .medium }
        
        switch priorityString.lowercased() {
        case "low", "低":
            return .low
        case "high", "高":
            return .high
        default:
            return .medium
        }
    }
    
    func parseEstimatedHours(from durationString: String?) -> Double? {
        guard let durationString = durationString else { return nil }
        
        // 簡単な時間パース（例: "2時間", "1週間", "3日"）
        if durationString.contains("時間") {
            let numberString = durationString.replacingOccurrences(of: "時間", with: "").trimmingCharacters(in: .whitespaces)
            return Double(numberString)
        } else if durationString.contains("日") {
            let numberString = durationString.replacingOccurrences(of: "日", with: "").trimmingCharacters(in: .whitespaces)
            if let days = Double(numberString) {
                return days * 8 // 1日8時間想定
            }
        } else if durationString.contains("週間") {
            let numberString = durationString.replacingOccurrences(of: "週間", with: "").trimmingCharacters(in: .whitespaces)
            if let weeks = Double(numberString) {
                return weeks * 40 // 1週間40時間想定
            }
        } else if durationString.contains("ヶ月") {
            let numberString = durationString.replacingOccurrences(of: "ヶ月", with: "").trimmingCharacters(in: .whitespaces)
            if let months = Double(numberString) {
                return months * 160 // 1ヶ月160時間想定
            }
        }
        
        return nil
    }
}

// MARK: - Advanced Parsing

extension TemplateImportConversion {
    
    func parseComplexDuration(from durationString: String) -> (hours: Double, confidence: Double)? {
        let cleanString = durationString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // より複雑なパターンマッチング
        let patterns: [(regex: NSRegularExpression, multiplier: Double)] = [
            (try! NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*時間?"#), 1.0),
            (try! NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*日"#), 8.0),
            (try! NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*週間?"#), 40.0),
            (try! NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*ヶ?月"#), 160.0),
            (try! NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*年"#), 1920.0)
        ]
        
        for (regex, multiplier) in patterns {
            let matches = regex.matches(in: cleanString, range: NSRange(cleanString.startIndex..., in: cleanString))
            if let match = matches.first {
                if let range = Range(match.range(at: 1), in: cleanString) {
                    let numberString = String(cleanString[range])
                    if let number = Double(numberString) {
                        let hours = number * multiplier
                        let confidence = 1.0 // 完全マッチ
                        return (hours: hours, confidence: confidence)
                    }
                }
            }
        }
        
        return nil
    }
    
    func inferCategoryFromContent(template: ProjectTemplate) -> TemplateCategory {
        let allText = ([template.name] + 
                      [template.description].compactMap { $0 } + 
                      template.phases.flatMap { phase in 
                          [phase.title] + [phase.description].compactMap { $0 }
                      }).joined(separator: " ").lowercased()
        
        let categoryKeywords: [TemplateCategory: [String]] = [
            .softwareDevelopment: ["アプリ", "開発", "プログラム", "コード", "システム", "api", "データベース"],
            .business: ["事業", "ビジネス", "営業", "売上", "顧客", "マーケティング"],
            .eventPlanning: ["イベント", "企画", "準備", "会場", "参加者"],
            .education: ["学習", "教育", "研修", "スキル", "知識"],
            .health: ["健康", "運動", "ダイエット", "フィットネス", "医療"],
            .travel: ["旅行", "観光", "宿泊", "交通", "予約"]
        ]
        
        var scores: [TemplateCategory: Int] = [:]
        
        for (category, keywords) in categoryKeywords {
            let score = keywords.reduce(0) { sum, keyword in
                sum + (allText.contains(keyword) ? 1 : 0)
            }
            scores[category] = score
        }
        
        return scores.max { $0.value < $1.value }?.key ?? .other
    }
}