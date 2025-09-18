import Foundation

enum PlanNormalizationError: Error {
    case invalidJSON
    case missingProject
    case missingTasks
}

struct PlanNormalization {
    static func stripCodeFences(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            if let range = trimmed.range(of: "\n") {
                trimmed = String(trimmed[range.upperBound...])
            }
        }
        if trimmed.hasSuffix("```") {
            if let range = trimmed.range(of: "```", options: .backwards) {
                trimmed = String(trimmed[..<range.lowerBound])
            }
        }
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizePlan(from text: String, defaultLocale: UserLocale) throws -> Plan {
        let cleaned = stripCodeFences(text)
        guard let data = cleaned.data(using: .utf8) else { throw PlanNormalizationError.invalidJSON }
        let decoder = JSONDecoder()
        guard var raw = try? decoder.decode(RawPlan.self, from: data) else {
            throw PlanNormalizationError.invalidJSON
        }

        var projectTitle = raw.project?.trimmingCharacters(in: .whitespacesAndNewlines)
        if projectTitle?.isEmpty ?? true {
            projectTitle = "Photo Suggestion"
        }

        var country = raw.locale?.country?.trimmingCharacters(in: .whitespacesAndNewlines)
        var city = raw.locale?.city?.trimmingCharacters(in: .whitespacesAndNewlines)
        if country?.isEmpty ?? true { country = defaultLocale.country }
        if city?.isEmpty ?? true { city = defaultLocale.city }

        guard let rawTasks = raw.tasks else { throw PlanNormalizationError.missingTasks }
        let tasks: [TidyTask] = rawTasks.compactMap { task in
            guard let title = task.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
            let trimmedId = task.id?.trimmingCharacters(in: .whitespacesAndNewlines)
            let id = (trimmedId?.isEmpty ?? true) ? UUID().uuidString : trimmedId!
            let exitTag = ExitTag(rawValue: (task.exitTag ?? "").uppercased()) ?? .keep
            let priority = task.priorityValue
            let effort = task.effortValue
            let checklist = sanitizedList(task.checklist) ?? task.rationale.map { [$0] }
            let links = sanitizedList(task.links)
            let labels = sanitizedList(task.labels)
            let dueAt = normalizeDate(task.dueAt)
            return TidyTask(
                id: id,
                title: title,
                area: task.area,
                exit_tag: exitTag,
                priority: priority,
                effort_min: effort,
                labels: labels,
                checklist: checklist,
                links: links,
                url: task.url,
                due_at: dueAt
            )
        }

        guard !tasks.isEmpty else { throw PlanNormalizationError.missingTasks }
        guard let finalCountry = country, let finalCity = city else { throw PlanNormalizationError.invalidJSON }

        return Plan(project: projectTitle ?? "Photo Suggestion",
                    locale: UserLocale(country: finalCountry, city: finalCity),
                    tasks: tasks).validated()
    }

    private static func sanitizedList(_ items: [String]?) -> [String]? {
        guard let items else { return nil }
        let trimmed = items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let filtered = trimmed.filter { !$0.isEmpty }
        return filtered.isEmpty ? nil : filtered
    }

    private static func normalizeDate(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let formats = ["yyyy-MM-dd", "yyyy/MM/dd", "yyyy.MM.dd", "yyyyMMdd"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                let iso = DateFormatter()
                iso.locale = Locale(identifier: "en_US_POSIX")
                iso.dateFormat = "yyyy-MM-dd"
                return iso.string(from: date)
            }
        }
        return nil
    }

    private struct RawPlan: Codable {
        struct Locale: Codable { var country: String?; var city: String? }
        struct Task: Codable {
            var id: String?
            var title: String?
            var exitTag: String?
            var priority: Int?
            var priorityLabel: String?
            var effort_min: Int?
            var effortLabel: String?
            var checklist: [String]?
            var rationale: String?
            var links: [String]?
            var labels: [String]?
            var dueAt: String?
            var area: String?
            var url: String?

            enum CodingKeys: String, CodingKey {
                case id, title, area, url, labels, links, rationale
                case exitTag = "exit_tag"
                case priority
                case effort_min
                case checklist
                case dueAt = "due_at"
                case due
                case effort
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try? container.decode(String.self, forKey: .id)
                title = try? container.decode(String.self, forKey: .title)
                exitTag = try? container.decode(String.self, forKey: .exitTag)
                area = try? container.decode(String.self, forKey: .area)
                url = try? container.decode(String.self, forKey: .url)
                labels = try? container.decode([String].self, forKey: .labels)
                links = try? container.decode([String].self, forKey: .links)
                rationale = try? container.decode(String.self, forKey: .rationale)
                checklist = try? container.decode([String].self, forKey: .checklist)

                if let priorityValue = try? container.decode(Int.self, forKey: .priority) {
                    priority = priorityValue
                } else if let priorityString = try? container.decode(String.self, forKey: .priority) {
                    priorityLabel = priorityString
                }

                if let effortValue = try? container.decode(Int.self, forKey: .effort_min) {
                    effort_min = effortValue
                } else if let effortString = try? container.decode(String.self, forKey: .effort_min) ?? container.decode(String.self, forKey: .effort) {
                    effortLabel = effortString
                }

                dueAt = (try? container.decode(String.self, forKey: .dueAt))
                    ?? (try? container.decode(String.self, forKey: .due))
            }

            init() {}

            var priorityValue: Int? {
                if let priority { return (1...4).contains(priority) ? priority : nil }
                guard let label = priorityLabel?.lowercased() else { return nil }
                switch label {
                case "urgent", "high": return 4
                case "medium", "normal": return 3
                case "low": return 2
                default: return nil
                }
            }

            var effortValue: Int? {
                if let effort_min { return effort_min }
                guard let label = effortLabel else { return nil }
                return Int(label)
            }
        }

        var project: String?
        var locale: Locale?
        var tasks: [Task]?
    }
}
