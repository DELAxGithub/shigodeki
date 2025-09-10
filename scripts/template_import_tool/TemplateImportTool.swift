#!/usr/bin/env swift
import Foundation

// MARK: - Models (subset matching app)

enum TemplateCategory: String, Codable, CaseIterable { case softwareDevelopment, business, event, lifestyle, education, other }
enum TemplateDifficulty: String, Codable, CaseIterable { case beginner, intermediate, advanced, expert }
enum TaskPriority: String, Codable, CaseIterable { case low, medium, high }
enum TaskListColor: String, Codable, CaseIterable { case blue, green, orange, purple, red, yellow }

struct ProjectTemplate: Codable {
    let name: String
    let description: String?
    let goal: String?
    let category: TemplateCategory
    let version: String
    let phases: [PhaseTemplate]
    let metadata: TemplateMetadata
}
struct PhaseTemplate: Codable {
    let title: String
    let description: String?
    let order: Int
    let prerequisites: [String]?
    let templateReference: String?
    let estimatedDuration: String?
    let taskLists: [TaskListTemplate]
}
struct TaskListTemplate: Codable {
    let name: String
    let description: String?
    let color: TaskListColor?
    let order: Int
    let tasks: [TaskTemplate]
}
struct TaskTemplate: Codable {
    let title: String
    let description: String?
    let priority: TaskPriority
    let estimatedDuration: String?
    let deadline: String?
    let tags: [String]?
    let templateLinks: [String]?
    let isOptional: Bool?
    let estimatedHours: Double?
    let dependsOn: [String]?
    let subtasks: [String]?
}
struct TemplateMetadata: Codable {
    let author: String?
    let createdAt: String?
    let estimatedDuration: String?
    let difficulty: TemplateDifficulty
    let tags: [String]?
    let targetAudience: String?
}

// Legacy format (steps)
struct LegacyJSONTemplate: Codable {
    let name: String
    let description: String?
    let goal: String?
    let category: String?
    let version: String?
    let steps: [LegacyStep]
    let metadata: LegacyMetadata?
    struct LegacyStep: Codable {
        let title: String
        let description: String?
        let order: Int
        let prerequisites: [String]?
        let templateReference: String?
        let estimatedDuration: String?
        let tasks: [LegacyTask]
    }
    struct LegacyTask: Codable {
        let title: String
        let description: String?
        let priority: String?
        let estimatedDuration: String?
        let deadline: String?
        let tags: [String]?
        let templateLinks: [String]?
        let isOptional: Bool?
    }
    struct LegacyMetadata: Codable {
        let author: String?
        let createdAt: String?
        let estimatedDuration: String?
        let difficulty: String?
        let tags: [String]?
    }
}

// MARK: - IO Helpers

let encoder: JSONEncoder = {
    let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e
}()
let decoder: JSONDecoder = { JSONDecoder() }()

func readFile(_ path: String?) throws -> String {
    if let p = path { return try String(contentsOfFile: p, encoding: .utf8) }
    let data = FileHandle.standardInput.readDataToEndOfFile(); return String(data: data, encoding: .utf8) ?? ""
}

func writeFile(_ path: String?, data: Data) throws {
    if let p = path { try data.write(to: URL(fileURLWithPath: p)) } else { FileHandle.standardOutput.write(data) }
}

// MARK: - Prompt

let promptHeader = """
あなたはプロジェクトテンプレート変換器です。与えられた自然言語の要件記述を、指定のJSONスキーマ（ProjectTemplate）に正規化して出力します。出力は有効なJSONのみ、追加テキストなし。

Constraints:
- 出力は1つのJSONオブジェクトのみ。
- スキーマ（キー名・ネスト構造）を厳守:
  - root: name, description?, goal?, category, version, phases[], metadata
  - phases[].title, description?, order, prerequisites[], templateReference?, estimatedDuration?, taskLists[]
  - taskLists[].name, description?, color, order, tasks[]
  - tasks[].title, description?, priority(low|medium|high), estimatedDuration?, deadline?, tags[], templateLinks?, isOptional?, estimatedHours?, dependsOn[], subtasks[]
  - metadata.author?, createdAt(ISO8601)?, estimatedDuration?, difficulty(beginner|intermediate|advanced|expert), tags[], targetAudience?
- 列挙値は指定の候補のみ（category: softwareDevelopment|business|event|lifestyle|education|other / difficulty / priority / color）。
- 空値は出力しない。未指定はキーごと省略可。
- phase.order と taskList.order は0起点の昇順を割り当てる。
- 可能なら taskLists は「基本」1つにまとめる（最小構成）。
- 日本語のタイトル/説明を保持。

Mapping Rules:
- 見出し/章立て → phases[].title／箇条書き→ tasks[].title
- 重要/最優先/緊急 → priority: high、通常 → medium、小タスク → low
- 時間表現（例: 2時間）→ estimatedDuration: "2 hours"
- 日付（締切）→ deadline（可能なら ISO8601）
- カテゴリ不明時 → category: "other"、難易度不明時 → difficulty: "intermediate"

出力フォーマットの雛形は以下を参考:
{
  "name": "...",
  "description": "...",
  "goal": "...",
  "category": "softwareDevelopment|business|event|lifestyle|education|other",
  "version": "1.0",
  "phases": [
    {
      "title": "...",
      "description": "...",
      "order": 0,
      "prerequisites": [],
      "taskLists": [
        {
          "name": "基本",
          "description": "主要タスク",
          "color": "blue",
          "order": 0,
          "tasks": [
            { "title": "...", "description": "...", "priority": "medium", "tags": [] }
          ]
        }
      ]
    }
  ],
  "metadata": {
    "author": "user",
    "difficulty": "intermediate",
    "tags": []
  }
}

ユーザー入力（自然文）:

"""

func makePrompt(naturalText: String) -> String {
    return promptHeader + naturalText + "\n\"\"\"\n"
}

// MARK: - Legacy → Modern conversion

func mapPriority(_ p: String?) -> TaskPriority { switch p?.lowercased() { case "high": return .high; case "low": return .low; default: return .medium } }
func mapCategory(_ s: String?) -> TemplateCategory { TemplateCategory(rawValue: s ?? "") ?? .other }
func mapDifficulty(_ s: String?) -> TemplateDifficulty { TemplateDifficulty(rawValue: s ?? "") ?? .intermediate }

func convertLegacy(_ legacy: LegacyJSONTemplate) -> ProjectTemplate {
    let phases: [PhaseTemplate] = legacy.steps.map { step in
        let tasks: [TaskTemplate] = step.tasks.map { t in
            TaskTemplate(title: t.title,
                         description: t.description,
                         priority: mapPriority(t.priority),
                         estimatedDuration: t.estimatedDuration,
                         deadline: t.deadline,
                         tags: t.tags,
                         templateLinks: t.templateLinks,
                         isOptional: t.isOptional,
                         estimatedHours: nil,
                         dependsOn: nil,
                         subtasks: nil)
        }
        let tl = TaskListTemplate(name: "タスク",
                                   description: step.description,
                                   color: .blue,
                                   order: 0,
                                   tasks: tasks)
        return PhaseTemplate(title: step.title,
                             description: step.description,
                             order: step.order,
                             prerequisites: step.prerequisites ?? [],
                             templateReference: step.templateReference,
                             estimatedDuration: step.estimatedDuration,
                             taskLists: [tl])
    }
    let meta = TemplateMetadata(author: legacy.metadata?.author ?? "Unknown",
                                createdAt: legacy.metadata?.createdAt,
                                estimatedDuration: legacy.metadata?.estimatedDuration,
                                difficulty: mapDifficulty(legacy.metadata?.difficulty),
                                tags: legacy.metadata?.tags,
                                targetAudience: nil)
    return ProjectTemplate(name: legacy.name,
                           description: legacy.description,
                           goal: legacy.goal,
                           category: mapCategory(legacy.category),
                           version: legacy.version ?? "1.0",
                           phases: phases,
                           metadata: meta)
}

// MARK: - Commands

enum Cmd: String { case makePrompt = "make-prompt", validate = "validate", convert = "convert", sample = "sample" }

func fail(_ msg: String) -> Never { fputs("Error: \(msg)\n", stderr); exit(1) }

func parseArg(_ flag: String) -> String? {
    if let i = CommandLine.arguments.firstIndex(of: flag), i+1 < CommandLine.arguments.count {
        return CommandLine.arguments[i+1]
    }
    return nil
}

guard CommandLine.arguments.count >= 2, let cmd = Cmd(rawValue: CommandLine.arguments[1]) else {
    print("Usage: TemplateImportTool.swift <make-prompt|validate|convert|sample> [options]\n\n" +
          "make-prompt --in <textfile>\n" +
          "validate --json <file>\n" +
          "convert --in <file> --out <file>\n" +
          "sample <modern|legacy>")
    exit(0)
}

switch cmd {
case .makePrompt:
    let inPath = parseArg("--in")
    let text = try readFile(inPath)
    print(makePrompt(naturalText: text.trimmingCharacters(in: .whitespacesAndNewlines)))

case .validate:
    guard let jsonPath = parseArg("--json") else { fail("--json <file> is required") }
    let json = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
    if let modern = try? decoder.decode(ProjectTemplate.self, from: json) {
        let phaseCount = modern.phases.count
        let taskCount = modern.phases.flatMap { $0.taskLists }.flatMap { $0.tasks }.count
        print("VALID: modern ProjectTemplate (phases=\(phaseCount), tasks=\(taskCount))")
        exit(0)
    }
    if let legacy = try? decoder.decode(LegacyJSONTemplate.self, from: json) {
        let stepCount = legacy.steps.count
        let taskCount = legacy.steps.flatMap { $0.tasks }.count
        print("VALID: legacy steps template (steps=\(stepCount), tasks=\(taskCount))")
        exit(0)
    }
    fail("Unsupported or invalid JSON (neither modern nor legacy)")

case .convert:
    guard let inPath = parseArg("--in") else { fail("--in <file> is required") }
    let outPath = parseArg("--out")
    let data = try Data(contentsOf: URL(fileURLWithPath: inPath))
    if let modern = try? decoder.decode(ProjectTemplate.self, from: data) {
        let out = try encoder.encode(modern); try writeFile(outPath, data: out)
        print("Wrote modern JSON (passthrough) -> \(outPath ?? "stdout")")
        exit(0)
    }
    if let legacy = try? decoder.decode(LegacyJSONTemplate.self, from: data) {
        let converted = convertLegacy(legacy)
        let out = try encoder.encode(converted); try writeFile(outPath, data: out)
        print("Converted legacy -> modern -> \(outPath ?? "stdout")")
        exit(0)
    }
    fail("Unsupported or invalid JSON (cannot convert)")

case .sample:
    guard CommandLine.arguments.count >= 3 else { fail("sample <modern|legacy>") }
    let kind = CommandLine.arguments[2]
    if kind == "modern" {
        let sample = ProjectTemplate(
            name: "つるつテンプレート",
            description: "サンプル",
            goal: "基本フロー",
            category: .business,
            version: "1.0",
            phases: [
                PhaseTemplate(title: "企画", description: "計画を立てる", order: 0, prerequisites: [], templateReference: nil, estimatedDuration: nil, taskLists: [
                    TaskListTemplate(name: "基本", description: "主要タスク", color: .blue, order: 0, tasks: [
                        TaskTemplate(title: "要件定義", description: "目的を明確化", priority: .high, estimatedDuration: nil, deadline: nil, tags: [], templateLinks: nil, isOptional: nil, estimatedHours: nil, dependsOn: nil, subtasks: nil),
                        TaskTemplate(title: "スケジュール策定", description: nil, priority: .medium, estimatedDuration: nil, deadline: nil, tags: nil, templateLinks: nil, isOptional: nil, estimatedHours: nil, dependsOn: nil, subtasks: nil)
                    ])
                ])
            ],
            metadata: TemplateMetadata(author: "Me", createdAt: nil, estimatedDuration: "1 hour", difficulty: .beginner, tags: ["sample"], targetAudience: "individual")
        )
        let out = try encoder.encode(sample); FileHandle.standardOutput.write(out)
    } else if kind == "legacy" {
        let legacy = LegacyJSONTemplate(name: "つるつテンプレート", description: "サンプル", goal: nil, category: "business", version: "1.0", steps: [
            .init(title: "企画", description: "計画を立てる", order: 0, prerequisites: nil, templateReference: nil, estimatedDuration: nil, tasks: [
                .init(title: "要件定義", description: "目的を明確化", priority: "high", estimatedDuration: nil, deadline: nil, tags: ["core"], templateLinks: nil, isOptional: nil),
                .init(title: "スケジュール策定", description: nil, priority: "medium", estimatedDuration: nil, deadline: nil, tags: nil, templateLinks: nil, isOptional: nil)
            ])
        ], metadata: .init(author: "Me", createdAt: nil, estimatedDuration: "1 hour", difficulty: "intermediate", tags: ["sample"]))
        let out = try encoder.encode(legacy); FileHandle.standardOutput.write(out)
    } else {
        fail("unknown sample kind: \(kind)")
    }
}
