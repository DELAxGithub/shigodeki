import Foundation

enum PlanNormalizationError: Error {
    case invalidJSON
    case missingProject
    case missingTasks
}

struct PlanNormalization {
    static func stripCodeFences(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }
        let pattern = "^```[a-zA-Z0-9_-]*\\n|\\n```$"
        trimmed = trimmed.replacingOccurrences(of: pattern, with: "", options: [.regularExpression])
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizePlan(
        from text: String,
        defaultLocale: UserLocale,
        defaultLang: String = "ja",
        defaultRegion: String = "JP"
    ) throws -> Plan {
        let cleaned = stripCodeFences(text)
        guard let data = cleaned.data(using: .utf8) else { throw PlanNormalizationError.invalidJSON }
        let decoder = JSONDecoder()
        guard var raw = try? decoder.decode(RawPlan.self, from: data) else {
            throw PlanNormalizationError.invalidJSON
        }

        guard let project = raw.project else { throw PlanNormalizationError.missingProject }

        var projectTitle = project.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        if projectTitle?.isEmpty ?? true {
            projectTitle = "Photo Suggestion"
        }

        let trimmedLang = project.locale?.lang?.trimmingCharacters(in: .whitespacesAndNewlines)
        let language = (trimmedLang?.isEmpty == false ? trimmedLang : nil) ?? defaultLang

        var region = project.locale?.region?.trimmingCharacters(in: .whitespacesAndNewlines)
        if region?.isEmpty ?? true { region = defaultRegion }
        region = region?.uppercased()

        guard let rawTasks = raw.tasks else { throw PlanNormalizationError.missingTasks }
        let tasks: [TidyTask] = rawTasks.compactMap { task in
            guard let title = task.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
            let dueAt = normalizeDate(task.due)
            let priority = priorityValue(from: task.priority)
            let rationale = task.rationale?.trimmingCharacters(in: .whitespacesAndNewlines)
            let checklist: [String]? = {
                guard let rationale, !rationale.isEmpty else { return nil }
                let items = rationale
                    .components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                return items.isEmpty ? nil : items
            }()

            return TidyTask(
                id: UUID().uuidString,
                title: title,
                area: nil,
                exit_tag: .keep,
                priority: priority,
                effort_min: nil,
                labels: nil,
                checklist: checklist,
                links: nil,
                url: nil,
                due_at: dueAt
            )
        }

        guard !tasks.isEmpty else { throw PlanNormalizationError.missingTasks }

        let finalCountry = region ?? defaultLocale.country
        let finalCity = defaultCity(for: finalCountry, language: language, fallback: defaultLocale.city)

        return Plan(
            project: projectTitle ?? "Photo Suggestion",
            locale: UserLocale(country: finalCountry, city: finalCity),
            tasks: tasks
        ).validated()
    }

    // MARK: - Helpers

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

    private static func priorityValue(from label: String?) -> Int? {
        guard let label else { return nil }
        switch label.lowercased() {
        case "low": return 2
        case "normal": return 3
        case "high": return 4
        default: return nil
        }
    }

    private static func defaultCity(for region: String, language: String, fallback: String) -> String {
        switch region.uppercased() {
        case "JP":
            return "Tokyo"
        case "CA":
            return "Toronto"
        case "US":
            return language.lowercased().hasPrefix("ja") ? "Los Angeles" : "San Francisco"
        default:
            return fallback
        }
    }

    private struct RawPlan: Decodable {
        struct Project: Decodable {
            struct Locale: Decodable { var lang: String?; var region: String? }
            var title: String?
            var locale: Locale?
        }
        struct Task: Decodable {
            var title: String?
            var rationale: String?
            var priority: String?
            var due: String?

            enum CodingKeys: String, CodingKey {
                case title
                case rationale
                case priority
                case due
                case description
                case details
                case notes
                case dueAt = "due_at"
                case exitTag = "exit_tag"
                case checklist
                case effortMin = "effort_min"
                case effort
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                title = try? container.decode(String.self, forKey: .title)
                rationale = (try? container.decode(String.self, forKey: .rationale))
                    ?? (try? container.decode(String.self, forKey: .description))
                    ?? (try? container.decode(String.self, forKey: .details))
                    ?? (try? container.decode(String.self, forKey: .notes))

                if let rawPriority = try? container.decode(String.self, forKey: .priority) {
                    priority = rawPriority
                } else if let priorityValue = try? container.decode(Int.self, forKey: .priority) {
                    priority = Self.priorityLabel(for: priorityValue)
                }

                due = (try? container.decode(String.self, forKey: .due))
                    ?? (try? container.decode(String.self, forKey: .dueAt))

                if rationale == nil,
                   let checklist = try? container.decode([String].self, forKey: .checklist),
                   checklist.isEmpty == false {
                    rationale = checklist.joined(separator: "\n")
                }
            }

            init(title: String? = nil, rationale: String? = nil, priority: String? = nil, due: String? = nil) {
                self.title = title
                self.rationale = rationale
                self.priority = priority
                self.due = due
            }

            private static func priorityLabel(for value: Int) -> String? {
                switch value {
                case ...1: return "low"
                case 2: return "low"
                case 3: return "normal"
                case 4...: return "high"
                default: return nil
                }
            }
        }
        var project: Project?
        var tasks: [Task]?

        enum CodingKeys: String, CodingKey {
            case project
            case tasks
            case locale // legacy support
        }

        init(project: Project? = nil, tasks: [Task]? = nil) {
            self.project = project
            self.tasks = tasks
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let projectObject = try? container.decode(Project.self, forKey: .project) {
                project = projectObject
            } else if let projectString = try? container.decode(String.self, forKey: .project) {
                project = Project(title: projectString, locale: nil)
            } else {
                project = nil
            }

            tasks = try? container.decode([Task].self, forKey: .tasks)

            if project == nil,
               let legacyLocale = try? container.decode(Project.Locale.self, forKey: .locale) {
                project = Project(title: nil, locale: legacyLocale)
            }
        }
    }
}
