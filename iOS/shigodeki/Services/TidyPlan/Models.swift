import Foundation

// MARK: - Core Models (embedded from TidyPlanKit)

struct UserLocale: Codable {
    let country: String
    let city: String
}

enum ExitTag: String, CaseIterable, Codable {
    case sell = "SELL"
    case give = "GIVE"
    case recycle = "RECYCLE"
    case trash = "TRASH"
    case keep = "KEEP"
    
    var displayName: String {
        switch self {
        case .sell: return "Sell"
        case .give: return "Give"
        case .recycle: return "Recycle"
        case .trash: return "Trash"
        case .keep: return "Keep"
        }
    }
    
    var systemImage: String {
        switch self {
        case .sell: return "dollarsign.circle"
        case .give: return "heart.circle"
        case .recycle: return "arrow.3.trianglepath"
        case .trash: return "trash.circle"
        case .keep: return "archivebox.circle"
        }
    }
}

struct TidyTask: Codable, Identifiable {
    let id: String
    let title: String
    let area: String?
    let exit_tag: ExitTag?
    let priority: Int?
    let effort_min: Int?
    let labels: [String]?
    let checklist: [String]?
    let links: [String]?
    let url: String?
    let due_at: String?
    
    var exitTag: ExitTag { exit_tag ?? .keep }
    var effortMinutes: Int { effort_min ?? 15 }
    var taskPriority: Int { priority ?? 3 }
    var isHighPriority: Bool { taskPriority >= 4 }
    var dueDate: Date? {
        guard let due_at = due_at else { return nil }
        if let parsed = ISO8601DateFormatter().date(from: due_at) {
            return parsed
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: due_at)
    }
}

struct Plan: Codable {
    let project: String
    let locale: UserLocale
    let tasks: [TidyTask]
}

// MARK: - Validation Extensions

extension TidyTask {
    var isValid: Bool { !id.isEmpty && !title.isEmpty }
    static func validate(_ tasks: [TidyTask]) -> [TidyTask] { tasks.filter { $0.isValid } }
}

extension Plan {
    func validated() -> Plan {
        Plan(project: project, locale: locale, tasks: TidyTask.validate(tasks))
    }
}
