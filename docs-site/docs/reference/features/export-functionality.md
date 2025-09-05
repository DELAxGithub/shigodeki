# エクスポート機能アーキテクチャ仕様

プロジェクトの完全なエクスポート機能の技術仕様とアーキテクチャ設計です。

## 🔗 関連情報

- 🏗️ [JSONテンプレートシステム](../architecture/json-template-system.md) - テンプレート化機能
- 📋 [タスクリストワークフロー](./tasklist-workflows.md) - データ階層構造
- 📊 [UI/UX改善レポート](../../explanation/design-analysis/ui-ux-improvements.md) - ユーザビリティ向上

---

# Issue #13: プロジェクトエクスポート機能完全実装

## 現状分析

### 実装済み機能
- ✅ プロジェクトエクスポート基本構造
- ✅ PhaseとTaskList読み込み実装済み
- ❌ **重要な問題**: タスク読み込み未実装（line 571）
- ❌ **欠落**: データ整合性検証
- ❌ **欠落**: 複数エクスポート形式対応

### 現在のアーキテクチャ問題

**ProjectManager.swift:571**:
```swift
let listTasks: [ShigodekiTask] = [] // TODO: Implement proper task loading for export
```

この未実装により完全なデータエクスポートができない状態。

## エクスポートシステムアーキテクチャ

### コンポーネント階層構造

```yaml
ProjectExportManager: "メイン制御"
├── DataCollectionEngine: "階層データ読み込み"
├── DataIntegrityVerifier: "検証・整合性チェック"
├── ExportFormatters: "JSON, CSV, PDF等"
├── ProgressTracker: "ユーザーフィードバック"
└── ExportResultHandler: "ファイル管理"
```

### データフロー設計

```mermaid
graph LR
    A[Project Selection] → B[Data Collection]
    B → C[Integrity Check]
    C → D[Format Selection]
    D → E[Export Generation]
    E → F[File Sharing]
    
    B -.-> G[Progress Updates]
    C -.-> H[Validation Results]
    D -.-> I[User Feedback]
```

## コンポーネント詳細設計

### 1. ProjectExportManager

**目的**: エクスポートワークフロー全体のオーケストレーション  
**ファイル**: `iOS/shigodeki/ProjectExportManager.swift`（新規）

```swift
@MainActor
final class ProjectExportManager: ObservableObject {
    // MARK: - Published Properties
    @Published var exportState: ExportState = .idle
    @Published var exportProgress: Double = 0.0
    @Published var exportError: ExportError?
    @Published var exportResult: ExportResult?
    
    // MARK: - Dependencies
    private let projectManager: ProjectManager
    private let taskManager: TaskManager
    private let taskListManager: TaskListManager
    private let subtaskManager: SubtaskManager
    
    // MARK: - Export Workflow
    func exportProject(_ project: Project, format: ExportFormat) async throws -> ExportResult {
        exportState = .collecting
        exportProgress = 0.0
        
        do {
            // Phase 1: 階層データ収集 (0-60%)
            let projectData = try await collectCompleteProjectData(project)
            exportProgress = 0.6
            
            // Phase 2: データ整合性検証 (60-80%)
            let verificationResult = try await verifyDataIntegrity(projectData)
            exportProgress = 0.8
            
            // Phase 3: エクスポート生成 (80-100%)
            let exportResult = try await generateExport(
                projectData, 
                format: format, 
                verification: verificationResult
            )
            exportProgress = 1.0
            
            exportState = .completed
            self.exportResult = exportResult
            return exportResult
            
        } catch {
            exportState = .failed
            exportError = ExportError.from(error)
            throw error
        }
    }
}
```

#### 状態管理

```swift
enum ExportState {
    case idle           // 待機中
    case collecting     // データ収集中
    case verifying      // 検証中
    case formatting     // フォーマット処理中
    case completed      // 完了
    case failed         // 失敗
    
    var displayMessage: String {
        switch self {
        case .idle: return "エクスポート準備完了"
        case .collecting: return "プロジェクトデータを収集中..."
        case .verifying: return "データ整合性を検証中..."
        case .formatting: return "エクスポートファイルを生成中..."
        case .completed: return "エクスポート完了"
        case .failed: return "エクスポートに失敗しました"
        }
    }
}

enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"
    case pdf = "PDF"
    case excel = "Excel"
    
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .pdf: return "pdf"
        case .excel: return "xlsx"
        }
    }
}
```

### 2. DataCollectionEngine（修正版）

**目的**: 完全な階層データ読み込み（タスク読み込み問題の修正）

```swift
struct DataCollectionEngine {
    private let projectManager: ProjectManager
    private let taskManager: TaskManager
    private let taskListManager: TaskListManager
    private let subtaskManager: SubtaskManager
    
    func collectCompleteProjectData(_ project: Project) async throws -> CompleteProjectData {
        var phases: [String: Phase] = [:]
        var taskLists: [String: [TaskList]] = [:]
        var tasks: [String: [ShigodekiTask]] = [:]
        var subtasks: [String: [Subtask]] = [:]
        
        // 1. 全フェーズ読み込み
        let projectPhases = try await projectManager.getPhases(projectId: project.id)
        for phase in projectPhases {
            phases[phase.id] = phase
            
            // 2. 各フェーズのタスクリスト読み込み
            let phaseLists = try await taskListManager.getTaskLists(
                phaseId: phase.id, 
                projectId: project.id
            )
            taskLists[phase.id] = phaseLists
            
            // 3. 各タスクリストのタスク読み込み（🔧 修正実装）
            for taskList in phaseLists {
                guard let taskListId = taskList.id else { continue }
                
                // 🔧 修正: 適切なタスク読み込み実装
                let listTasks = try await taskManager.getTasks(
                    taskListId: taskListId,
                    phaseId: phase.id,
                    projectId: project.id
                )
                tasks[taskListId] = listTasks
                
                // 4. 各タスクのサブタスク読み込み
                for task in listTasks {
                    guard let taskId = task.id else { continue }
                    let taskSubtasks = try await subtaskManager.getSubtasks(
                        taskId: taskId,
                        listId: taskListId,
                        phaseId: phase.id,
                        projectId: project.id
                    )
                    subtasks[taskId] = taskSubtasks
                }
            }
        }
        
        return CompleteProjectData(
            project: project,
            phases: phases,
            taskLists: taskLists,
            tasks: tasks,
            subtasks: subtasks,
            metadata: ExportMetadata(
                exportedAt: Date(),
                exportedBy: getCurrentUserId(),
                version: "1.0",
                totalPhases: phases.count,
                totalTaskLists: taskLists.values.flatMap { $0 }.count,
                totalTasks: tasks.values.flatMap { $0 }.count,
                totalSubtasks: subtasks.values.flatMap { $0 }.count
            )
        )
    }
}
```

### 3. エクスポートデータモデル

```swift
struct CompleteProjectData {
    let project: Project
    let phases: [String: Phase]                    // フェーズID → フェーズ
    let taskLists: [String: [TaskList]]            // フェーズID → タスクリスト配列
    let tasks: [String: [ShigodekiTask]]           // タスクリストID → タスク配列
    let subtasks: [String: [Subtask]]              // タスクID → サブタスク配列
    let metadata: ExportMetadata
}

struct ExportMetadata: Codable {
    let exportedAt: Date
    let exportedBy: String
    let version: String
    let totalPhases: Int
    let totalTaskLists: Int
    let totalTasks: Int
    let totalSubtasks: Int
    
    // データ整合性チェックサム
    let dataChecksum: String
    let hierarchyValid: Bool
    
    init(exportedAt: Date, exportedBy: String, version: String, 
         totalPhases: Int, totalTaskLists: Int, totalTasks: Int, totalSubtasks: Int) {
        self.exportedAt = exportedAt
        self.exportedBy = exportedBy
        self.version = version
        self.totalPhases = totalPhases
        self.totalTaskLists = totalTaskLists
        self.totalTasks = totalTasks
        self.totalSubtasks = totalSubtasks
        
        // チェックサム生成
        self.dataChecksum = generateChecksum(
            phases: totalPhases, lists: totalTaskLists, 
            tasks: totalTasks, subtasks: totalSubtasks
        )
        self.hierarchyValid = true // 検証後に設定
    }
}

struct ExportResult {
    let fileURL: URL
    let format: ExportFormat
    let fileSize: Int64
    let itemCount: ExportItemCount
    let verificationResult: DataIntegrityResult
    let exportDuration: TimeInterval
}

struct ExportItemCount {
    let phases: Int
    let taskLists: Int
    let tasks: Int
    let subtasks: Int
    
    var total: Int {
        phases + taskLists + tasks + subtasks
    }
    
    var summary: String {
        "フェーズ: \\(phases)、リスト: \\(taskLists)、タスク: \\(tasks)、サブタスク: \\(subtasks)"
    }
}
```

### 4. DataIntegrityVerifier

**目的**: データ整合性・完全性の保証

```swift
struct DataIntegrityVerifier {
    func verifyDataIntegrity(_ data: CompleteProjectData) async throws -> DataIntegrityResult {
        var issues: [IntegrityIssue] = []
        
        // 1. 階層関係の検証
        issues.append(contentsOf: verifyHierarchyIntegrity(data))
        
        // 2. データ完全性の検証
        issues.append(contentsOf: verifyDataCompleteness(data))
        
        // 3. 参照整合性の検証
        issues.append(contentsOf: verifyReferentialIntegrity(data))
        
        // 4. ビジネスルールの検証
        issues.append(contentsOf: verifyBusinessRules(data))
        
        let severity = determineSeverity(issues)
        
        return DataIntegrityResult(
            isValid: severity != .critical,
            issues: issues,
            severity: severity,
            verifiedAt: Date(),
            checksum: generateDataChecksum(data)
        )
    }
    
    private func verifyHierarchyIntegrity(_ data: CompleteProjectData) -> [IntegrityIssue] {
        var issues: [IntegrityIssue] = []
        
        // プロジェクト → フェーズ関係チェック
        for (phaseId, phase) in data.phases {
            if phase.projectId != data.project.id {
                issues.append(.hierarchyMismatch(
                    "フェーズ '\\(phase.name)' が異なるプロジェクトに属しています"
                ))
            }
        }
        
        // フェーズ → タスクリスト関係チェック
        for (phaseId, taskLists) in data.taskLists {
            for taskList in taskLists {
                if taskList.phaseId != phaseId {
                    issues.append(.hierarchyMismatch(
                        "タスクリスト '\\(taskList.name)' が異なるフェーズに属しています"
                    ))
                }
            }
        }
        
        // タスクリスト → タスク関係チェック
        for (taskListId, tasks) in data.tasks {
            for task in tasks {
                if task.listId != taskListId {
                    issues.append(.hierarchyMismatch(
                        "タスク '\\(task.title)' が異なるタスクリストに属しています"
                    ))
                }
            }
        }
        
        return issues
    }
    
    private func verifyDataCompleteness(_ data: CompleteProjectData) -> [IntegrityIssue] {
        var issues: [IntegrityIssue] = []
        
        // 必須フィールドの存在チェック
        if data.project.name.isEmpty {
            issues.append(.missingData("プロジェクト名が空です"))
        }
        
        // 各フェーズの完全性チェック
        for phase in data.phases.values {
            if phase.name.isEmpty {
                issues.append(.missingData("フェーズ名が空です: ID \\(phase.id)"))
            }
        }
        
        return issues
    }
}

struct DataIntegrityResult {
    let isValid: Bool
    let issues: [IntegrityIssue]
    let severity: IntegritySeverity
    let verifiedAt: Date
    let checksum: String
}

enum IntegrityIssue {
    case hierarchyMismatch(String)
    case missingData(String)
    case invalidReference(String)
    case businessRuleViolation(String)
    
    var description: String {
        switch self {
        case .hierarchyMismatch(let msg): return "階層不整合: \\(msg)"
        case .missingData(let msg): return "データ不足: \\(msg)"
        case .invalidReference(let msg): return "無効参照: \\(msg)"
        case .businessRuleViolation(let msg): return "ルール違反: \\(msg)"
        }
    }
}

enum IntegritySeverity: String {
    case none = "問題なし"
    case warning = "警告"
    case error = "エラー"
    case critical = "重大"
}
```

### 5. エクスポートフォーマッター

```swift
protocol ExportFormatter {
    func format(_ data: CompleteProjectData) async throws -> Data
    var fileExtension: String { get }
    var mimeType: String { get }
}

// JSON フォーマッター（メイン）
struct JSONExportFormatter: ExportFormatter {
    let fileExtension = "json"
    let mimeType = "application/json"
    
    func format(_ data: CompleteProjectData) async throws -> Data {
        let exportDocument = JSONExportDocument(
            project: data.project,
            phases: Array(data.phases.values).sorted { $0.order < $1.order },
            structure: buildHierarchicalStructure(data),
            metadata: data.metadata
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        return try encoder.encode(exportDocument)
    }
    
    private func buildHierarchicalStructure(_ data: CompleteProjectData) -> [PhaseStructure] {
        return data.phases.values.sorted { $0.order < $1.order }.map { phase in
            let taskLists = data.taskLists[phase.id] ?? []
            
            let taskListStructures = taskLists.sorted { $0.order < $1.order }.map { taskList in
                let tasks = data.tasks[taskList.id ?? ""] ?? []
                
                let taskStructures = tasks.sorted { $0.order < $1.order }.map { task in
                    let subtasks = data.subtasks[task.id ?? ""] ?? []
                    return TaskStructure(
                        task: task,
                        subtasks: subtasks.sorted { $0.order < $1.order }
                    )
                }
                
                return TaskListStructure(
                    taskList: taskList,
                    tasks: taskStructures
                )
            }
            
            return PhaseStructure(
                phase: phase,
                taskLists: taskListStructures
            )
        }
    }
}

// CSV フォーマッター（フラット構造）
struct CSVExportFormatter: ExportFormatter {
    let fileExtension = "csv"
    let mimeType = "text/csv"
    
    func format(_ data: CompleteProjectData) async throws -> Data {
        var csvContent = "フェーズ,タスクリスト,タスク,サブタスク,状態,優先度,期限,担当者\\n"
        
        for phase in data.phases.values.sorted(by: { $0.order < $1.order }) {
            let taskLists = data.taskLists[phase.id] ?? []
            
            for taskList in taskLists.sorted(by: { $0.order < $1.order }) {
                let tasks = data.tasks[taskList.id ?? ""] ?? []
                
                for task in tasks.sorted(by: { $0.order < $1.order }) {
                    let subtasks = data.subtasks[task.id ?? ""] ?? []
                    
                    if subtasks.isEmpty {
                        csvContent += formatCSVRow(
                            phase: phase.name,
                            taskList: taskList.name,
                            task: task.title,
                            subtask: "",
                            task: task
                        )
                    } else {
                        for subtask in subtasks {
                            csvContent += formatCSVRow(
                                phase: phase.name,
                                taskList: taskList.name,
                                task: task.title,
                                subtask: subtask.title,
                                task: task
                            )
                        }
                    }
                }
            }
        }
        
        return csvContent.data(using: .utf8) ?? Data()
    }
    
    private func formatCSVRow(phase: String, taskList: String, task: String, 
                             subtask: String, task: ShigodekiTask) -> String {
        let status = task.isCompleted ? "完了" : "未完了"
        let priority = "通常" // タスク優先度フィールドがあれば使用
        let dueDate = "" // 期限フィールドがあれば使用
        let assignee = "" // 担当者フィールドがあれば使用
        
        return "\\"\\(phase)\\",\\"\\(taskList)\\",\\"\\(task)\\",\\"\\(subtask)\\",\\"\\(status)\\",\\"\\(priority)\\",\\"\\(dueDate)\\",\\"\\(assignee)\\"\\n"
    }
}
```

## UI/UX設計

### エクスポートオプション画面

```swift
struct ProjectExportView: View {
    let project: Project
    @StateObject private var exportManager = ProjectExportManager()
    @State private var selectedFormat: ExportFormat = .json
    @State private var includeMetadata = true
    @State private var validateIntegrity = true
    @State private var showingExportResult = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                projectSummarySection
                formatSelectionSection
                exportOptionsSection
                
                Spacer()
                
                if exportManager.exportState == .idle {
                    exportButton
                } else {
                    exportProgressSection
                }
            }
            .padding()
            .navigationTitle("プロジェクトをエクスポート")
            .sheet(isPresented: $showingExportResult) {
                if let result = exportManager.exportResult {
                    ExportResultView(result: result)
                }
            }
        }
    }
    
    private var projectSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("エクスポート対象")
                .font(.headline)
            
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(project.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("作成日: \\(project.createdAt, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("エクスポート形式")
                .font(.headline)
            
            Picker("エクスポート形式", selection: $selectedFormat) {
                ForEach(ExportFormat.allCases, id: \\.self) { format in
                    Label(format.rawValue, systemImage: format.systemImage)
                        .tag(format)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private var exportOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("オプション")
                .font(.headline)
            
            Toggle("メタデータを含める", isOn: $includeMetadata)
            Toggle("データ整合性チェックを実行", isOn: $validateIntegrity)
        }
    }
    
    private var exportButton: some View {
        Button(action: startExport) {
            Label("エクスポート開始", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }
    
    private var exportProgressSection: some View {
        VStack(spacing: 16) {
            ProgressView(value: exportManager.exportProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            Text(exportManager.exportState.displayMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if exportManager.exportProgress > 0 {
                Text("\\(Int(exportManager.exportProgress * 100))% 完了")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func startExport() {
        Task {
            do {
                let result = try await exportManager.exportProject(project, format: selectedFormat)
                showingExportResult = true
            } catch {
                // エラーハンドリング
                print("エクスポートエラー: \\(error)")
            }
        }
    }
}
```

### エクスポート結果表示

```swift
struct ExportResultView: View {
    let result: ExportResult
    @Environment(\\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                successHeader
                resultSummary
                integrityReport
                
                Spacer()
                
                shareButton
            }
            .padding()
            .navigationTitle("エクスポート完了")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
    
    private var successHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("エクスポート成功")
                .font(.title2)
                .fontWeight(.semibold)
        }
    }
    
    private var resultSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("エクスポート結果")
                .font(.headline)
            
            InfoRow(label: "ファイル形式", value: result.format.rawValue)
            InfoRow(label: "ファイルサイズ", value: ByteCountFormatter().string(fromByteCount: result.fileSize))
            InfoRow(label: "処理時間", value: String(format: "%.1f秒", result.exportDuration))
            InfoRow(label: "総アイテム数", value: "\\(result.itemCount.total)個")
            InfoRow(label: "内訳", value: result.itemCount.summary)
        }
    }
    
    private var integrityReport: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("データ整合性")
                .font(.headline)
            
            HStack {
                Image(systemName: result.verificationResult.isValid ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(result.verificationResult.isValid ? .green : .orange)
                
                Text(result.verificationResult.isValid ? "整合性チェック: 正常" : "警告あり")
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            if !result.verificationResult.issues.isEmpty {
                DisclosureGroup("詳細を表示") {
                    ForEach(result.verificationResult.issues.indices, id: \\.self) { index in
                        Text(result.verificationResult.issues[index].description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var shareButton: some View {
        ShareLink(item: result.fileURL) {
            Label("ファイルを共有", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }
}
```

## 実装戦略

### Phase 1: コアデータ収集（2日）

**タスク**:
1. `DataCollectionEngine`の完全実装
2. `ProjectManager.swift:571`のTODO修正
3. 包括的エラーハンドリング追加

**成果物**:
- 完全なタスク読み込み機能
- エラー処理とログ記録
- 単体テスト実装

### Phase 2: データ整合性（1日）

**タスク**:
1. `DataIntegrityVerifier`構築
2. 検証ルールとチェック追加
3. 整合性レポート実装

**成果物**:
- データ検証システム
- 詳細な検証レポート
- 整合性テスト

### Phase 3: エクスポート形式（1日）

**タスク**:
1. JSONフォーマッター実装（メイン）
2. CSVフォーマッター追加（フラットエクスポート）
3. エクスポート結果処理

**成果物**:
- 複数形式対応
- 形式固有の最適化
- ファイル生成テスト

### Phase 4: UI統合（1日）

**タスク**:
1. エクスポートオプションUI構築
2. プログレス追跡追加
3. ファイル共有機能実装

**成果物**:
- 完全なUX体験
- リアルタイム進捗表示
- 共有とファイル管理

## 成功指標

### 技術的成功指標

- **エクスポート成功率**: 99%以上
- **データ整合性検証精度**: 95%以上  
- **エクスポート生成時間**: 一般的なプロジェクトで30秒未満

### データ品質指標

- **データ損失**: ゼロ
- **階層関係保持**: 100%
- **参照整合性維持**: 99%以上

## リスク軽減策

### データ整合性リスク

- **対策**: 複数レベルでの包括的検証
- **原子的操作**: データ収集の原子性保証
- **ロールバック機能**: 失敗時のエクスポート取り消し

### パフォーマンスリスク  

- **対策**: ユーザーフィードバック用の進捗追跡
- **バックグラウンド処理**: 大型エクスポートの背景処理
- **メモリ効率**: 効率的なデータ処理

### ユーザーエクスペリエンスリスク

- **対策**: 回復オプション付きの明確なエラーメッセージ
- **プレビュー機能**: 生成前のエクスポートプレビュー
- **複数形式**: 異なる用途向けの複数オプション

---

**更新日**: 2025-09-05  
**関連Issue**: [#13](https://github.com/project/issues/13)  
**実装優先度**: 高