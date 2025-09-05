# タスクリスト作成ワークフロー仕様

プロジェクト-フェーズ-タスクリスト階層における新アーキテクチャ統合仕様です。

## 🔗 関連情報

- 🏗️ [エクスポート機能](./export-functionality.md) - データ階層構造
- 📊 [UI/UX改善レポート](../../explanation/design-analysis/ui-ux-improvements.md) - ユーザビリティ向上
- 📋 [タグ機能仕様](./task-tags-specification.md) - タスク管理機能

---

# Issue #15: タスクリスト作成機能実装

## 現状分析

### 実装済みコンポーネント
- ✅ `CreateTaskListView` - 基本UI構造存在
- ✅ `TaskListManager` - バックエンド統合準備完了
- ❌ **欠落**: UIと新アーキテクチャ間の統合
- ❌ **欠落**: Phase-TaskList関係管理

### 現在のアーキテクチャギャップ

```yaml
# 新階層構造
Project → Phase → TaskList
                ↑
        統合ポイント欠落
```

**問題**: Phase context なしでTaskListが作成される状況

## システムアーキテクチャ設計

### コンポーネントフロー

```mermaid
graph LR
    A[PhaseListView] → B[CreateTaskListView]
    B → C[TaskListManager]
    C → D[Firestore]
    
    B → E[PhaseManager]
    E → F[SharedManagerStore]
    
    F -.-> B
```

### データフロー仕様

```yaml
workflow_steps:
  1_context: "Project + Phase選択済み"
  2_input: "TaskList名、説明、色"
  3_validation: "名前必須、Phase内ユニーク"
  4_creation: "TaskList + Phase関係作成"
  5_update: "PhaseのTaskListカウント更新"
  6_navigation: "新リスト付きPhase画面に戻る"
```

## 詳細コンポーネント設計

### 1. CreateTaskListView強化版

**現在の問題**: Phase contextと統合の欠落  
**解決策**: Phase認識型作成ワークフロー追加

```swift
struct CreateTaskListView: View {
    // MARK: - Properties
    let phase: Phase
    let project: Project
    
    @StateObject private var taskListManager: TaskListManager
    @StateObject private var phaseManager: PhaseManager
    
    @State private var taskListName = ""
    @State private var taskListDescription = ""
    @State private var selectedColor: TaskListColor = .blue
    @State private var isCreating = false
    @State private var creationError: String?
    
    @Environment(\\.dismiss) private var dismiss
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                contextSection
                taskListDetailsSection
                colorSelectionSection
                previewSection
            }
            .navigationTitle("新しいタスクリスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    createButton
                }
            }
            .alert("作成エラー", isPresented: .constant(creationError != nil)) {
                Button("再試行") { 
                    Task { await createTaskList() }
                }
                Button("OK") { creationError = nil }
            } message: {
                Text(creationError ?? "")
            }
        }
    }
    
    private var contextSection: some View {
        Section("作成先") {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text(project.name)
                        .fontWeight(.medium)
                    Text("フェーズ: \\(phase.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var taskListDetailsSection: some View {
        Section("タスクリスト詳細") {
            TextField("名前", text: $taskListName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("説明（オプション）", text: $taskListDescription)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !isFormValid && !taskListName.isEmpty {
                Text("名前は必須です（100文字以内）")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
    
    private var colorSelectionSection: some View {
        Section("カラー") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
                ForEach(TaskListColor.allCases, id: \\.self) { color in
                    Button(action: { selectedColor = color }) {
                        Circle()
                            .fill(color.displayColor)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                            )
                    }
                }
            }
        }
    }
    
    private var previewSection: some View {
        Section("プレビュー") {
            TaskListPreviewRow(
                name: taskListName.isEmpty ? "タスクリスト名" : taskListName,
                color: selectedColor,
                taskCount: 0
            )
        }
    }
    
    private var createButton: some View {
        Button(isCreating ? "作成中..." : "作成") {
            Task { await createTaskList() }
        }
        .disabled(!isFormValid || isCreating)
    }
    
    // MARK: - Validation
    private var isFormValid: Bool {
        let trimmedName = taskListName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && trimmedName.count <= 100
    }
    
    // MARK: - Creation Logic
    private func createTaskList() async {
        guard !isCreating else { return }
        
        isCreating = true
        creationError = nil
        
        do {
            // 1. TaskListをPhase関係と共に作成
            let taskList = createTaskListModel()
            
            // 2. Firestoreに保存
            try await taskListManager.createTaskList(taskList)
            
            // 3. PhaseのTaskListカウント更新
            await phaseManager.incrementTaskListCount(for: phase.id)
            
            // 4. 成功時のナビゲーション
            await MainActor.run {
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                creationError = "タスクリストの作成に失敗しました: \\(error.localizedDescription)"
            }
        }
        
        isCreating = false
    }
    
    private func createTaskListModel() -> TaskList {
        TaskList(
            id: UUID().uuidString,
            name: taskListName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: taskListDescription.isEmpty ? nil : taskListDescription,
            color: selectedColor,
            phaseId: phase.id,
            projectId: project.id,
            familyId: project.familyId,
            order: 0, // Managerで設定
            isArchived: false,
            taskCount: 0,
            completedTaskCount: 0,
            createdAt: Date(),
            createdBy: getCurrentUserId()
        )
    }
}
```

### 2. TaskListデータモデル強化

**現在のモデル**: 基本TaskList構造  
**強化**: Phase統合と順序管理

```swift
struct TaskList: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String?
    let color: TaskListColor
    
    // ✨ 新機能: Phase統合
    let phaseId: String
    let projectId: String
    let familyId: String
    
    // ✨ 新機能: 順序と管理
    let order: Int
    let isArchived: Bool
    
    // ✨ 新機能: パフォーマンス向けキャッシュ
    let taskCount: Int
    let completedTaskCount: Int
    
    // メタデータ
    let createdAt: Date
    let createdBy: String
    let updatedAt: Date?
    let updatedBy: String?
    
    // MARK: - Computed Properties
    var completionPercentage: Double {
        guard taskCount > 0 else { return 0.0 }
        return Double(completedTaskCount) / Double(taskCount)
    }
    
    var isCompleted: Bool {
        taskCount > 0 && completedTaskCount == taskCount
    }
    
    var displayTitle: String {
        "\\(name) (\\(completedTaskCount)/\\(taskCount))"
    }
}

enum TaskListColor: String, CaseIterable, Codable {
    case blue, green, orange, red, purple, yellow, gray, pink, indigo, teal
    
    var displayColor: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .purple: return .purple
        case .yellow: return .yellow
        case .gray: return .gray
        case .pink: return .pink
        case .indigo: return .indigo
        case .teal: return .teal
        }
    }
    
    var displayName: String {
        switch self {
        case .blue: return "ブルー"
        case .green: return "グリーン"
        case .orange: return "オレンジ"
        case .red: return "レッド"
        case .purple: return "パープル"
        case .yellow: return "イエロー"
        case .gray: return "グレー"
        case .pink: return "ピンク"
        case .indigo: return "インディゴ"
        case .teal: return "ティール"
        }
    }
    
    var systemImageName: String {
        "circle.fill"
    }
}
```

### 3. TaskListManager強化版

**現在の機能**: 基本CRUD操作  
**強化**: Phase認識型操作

```swift
extension TaskListManager {
    // MARK: - Phase認識型作成
    func createTaskList(_ taskList: TaskList) async throws {
        // 1. Phase存在検証
        guard await validatePhaseExists(taskList.phaseId) else {
            throw TaskListError.phaseNotFound
        }
        
        // 2. Phase内での順序決定
        let order = await getNextOrderInPhase(taskList.phaseId)
        var taskListWithOrder = taskList
        taskListWithOrder.order = order
        
        // 3. 名前の重複チェック
        guard await isNameUniqueInPhase(taskList.name, phaseId: taskList.phaseId) else {
            throw TaskListError.nameAlreadyExists
        }
        
        // 4. Firestoreへの作成
        let document = db.collection("families")
            .document(taskList.familyId)
            .collection("projects")
            .document(taskList.projectId)
            .collection("phases")
            .document(taskList.phaseId)
            .collection("taskLists")
            .document(taskList.id)
        
        try await document.setData(from: taskListWithOrder)
        
        // 5. ローカルキャッシュ更新
        await MainActor.run {
            self.taskLists.append(taskListWithOrder)
            self.taskLists.sort { $0.order < $1.order }
        }
        
        // 6. 統計更新
        await updatePhaseStatistics(phaseId: taskList.phaseId)
    }
    
    // MARK: - Phase統合機能
    private func validatePhaseExists(_ phaseId: String) async -> Bool {
        do {
            let document = db.collection("phases").document(phaseId)
            let snapshot = try await document.getDocument()
            return snapshot.exists
        } catch {
            return false
        }
    }
    
    private func isNameUniqueInPhase(_ name: String, phaseId: String) async -> Bool {
        let existingLists = taskLists.filter { 
            $0.phaseId == phaseId && $0.name.lowercased() == name.lowercased() 
        }
        return existingLists.isEmpty
    }
    
    private func getNextOrderInPhase(_ phaseId: String) async -> Int {
        let existingLists = taskLists.filter { $0.phaseId == phaseId }
        return (existingLists.map { $0.order }.max() ?? -1) + 1
    }
    
    private func updatePhaseStatistics(phaseId: String) async {
        // Phase統計の更新（TaskList数、完了率など）
        let phaseLists = taskLists.filter { $0.phaseId == phaseId }
        let totalTasks = phaseLists.reduce(0) { $0 + $1.taskCount }
        let completedTasks = phaseLists.reduce(0) { $0 + $1.completedTaskCount }
        
        // PhaseManagerを通じてPhase統計を更新
        NotificationCenter.default.post(
            name: .phaseStatisticsUpdated,
            object: PhaseStatistics(
                phaseId: phaseId,
                taskListCount: phaseLists.count,
                totalTasks: totalTasks,
                completedTasks: completedTasks
            )
        )
    }
    
    // MARK: - エラー型定義
    enum TaskListError: LocalizedError {
        case phaseNotFound
        case nameAlreadyExists
        case invalidData
        case networkError
        
        var errorDescription: String? {
            switch self {
            case .phaseNotFound:
                return "指定されたフェーズが見つかりません"
            case .nameAlreadyExists:
                return "同じ名前のタスクリストが既に存在します"
            case .invalidData:
                return "無効なデータが入力されました"
            case .networkError:
                return "ネットワークエラーが発生しました"
            }
        }
    }
}

// MARK: - 通知とデータ構造
extension Notification.Name {
    static let phaseStatisticsUpdated = Notification.Name("phaseStatisticsUpdated")
}

struct PhaseStatistics {
    let phaseId: String
    let taskListCount: Int
    let totalTasks: Int
    let completedTasks: Int
    
    var completionPercentage: Double {
        guard totalTasks > 0 else { return 0.0 }
        return Double(completedTasks) / Double(totalTasks)
    }
}
```

### 4. PhaseManager統合

**目的**: Phase-TaskList関係整合性の維持

```swift
extension PhaseManager {
    // MARK: - TaskList統計管理
    func incrementTaskListCount(for phaseId: String) async {
        guard let phaseIndex = phases.firstIndex(where: { $0.id == phaseId }) else {
            print("⚠️ Phase not found: \\(phaseId)")
            return
        }
        
        // ローカル更新
        await MainActor.run {
            phases[phaseIndex].taskListCount += 1
            phases[phaseIndex].updatedAt = Date()
        }
        
        // Firestore更新
        await updatePhaseTaskListCount(phaseId: phaseId, increment: 1)
    }
    
    func decrementTaskListCount(for phaseId: String) async {
        guard let phaseIndex = phases.firstIndex(where: { $0.id == phaseId }) else {
            return
        }
        
        await MainActor.run {
            phases[phaseIndex].taskListCount = max(0, phases[phaseIndex].taskListCount - 1)
            phases[phaseIndex].updatedAt = Date()
        }
        
        await updatePhaseTaskListCount(phaseId: phaseId, increment: -1)
    }
    
    // MARK: - Firestore統合
    private func updatePhaseTaskListCount(phaseId: String, increment: Int) async {
        do {
            let phaseRef = db.collection("phases").document(phaseId)
            try await phaseRef.updateData([
                "taskListCount": FieldValue.increment(Int64(increment)),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            print("❌ Failed to update phase task list count: \\(error)")
        }
    }
    
    // MARK: - 統計同期
    func syncPhaseStatistics() async {
        // 全PhaseのTaskList統計を再計算
        for phaseIndex in phases.indices {
            let phaseId = phases[phaseIndex].id
            let actualCount = await getActualTaskListCount(phaseId: phaseId)
            
            await MainActor.run {
                phases[phaseIndex].taskListCount = actualCount
            }
        }
    }
    
    private func getActualTaskListCount(phaseId: String) async -> Int {
        do {
            let query = db.collection("taskLists").whereField("phaseId", isEqualTo: phaseId)
            let snapshot = try await query.getDocuments()
            return snapshot.documents.count
        } catch {
            print("❌ Failed to get actual task list count: \\(error)")
            return 0
        }
    }
}
```

## UI/UX設計強化

### ナビゲーションフロー

```yaml
PhaseListView:
  - action: "新しいタスクリスト"ボタン
  - trigger: CreateTaskListView(phase: selectedPhase, project: project)
  
CreateTaskListView:
  - form_sections:
    - context: "作成先表示"
    - details: "名前、説明、色"
    - preview: "作成予定の外観"
  - actions:
    - cancel: "PhaseListViewに戻る"
    - create: "作成 → 成功時PhaseListViewに戻る（更新済み）"
```

### フォーム検証UI

```swift
private var validationSection: some View {
    Section {
        if !taskListName.isEmpty {
            if taskListName.count > 100 {
                ValidationMessage("名前は100文字以内で入力してください", type: .error)
            } else if isNameDuplicate {
                ValidationMessage("この名前は既に使用されています", type: .warning)
            } else {
                ValidationMessage("有効な名前です", type: .success)
            }
        }
        
        if !taskListDescription.isEmpty && taskListDescription.count > 500 {
            ValidationMessage("説明は500文字以内で入力してください", type: .error)
        }
    }
}

struct ValidationMessage: View {
    let message: String
    let type: ValidationMessageType
    
    var body: some View {
        HStack {
            Image(systemName: type.iconName)
                .foregroundColor(type.color)
            Text(message)
                .font(.caption)
                .foregroundColor(type.color)
        }
    }
}

enum ValidationMessageType {
    case success, warning, error
    
    var color: Color {
        switch self {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
    
    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
}
```

### ローディング状態UI

```swift
private var loadingStateSection: some View {
    if isCreating {
        Section {
            HStack {
                ProgressView()
                    .scaleEffect(0.9)
                
                VStack(alignment: .leading) {
                    Text("タスクリストを作成中...")
                        .fontWeight(.medium)
                    Text("フェーズとの関連付けを行っています")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
```

### プレビューコンポーネント

```swift
struct TaskListPreviewRow: View {
    let name: String
    let color: TaskListColor
    let taskCount: Int
    
    var body: some View {
        HStack {
            Circle()
                .fill(color.displayColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading) {
                Text(name)
                    .fontWeight(.medium)
                Text("\\(taskCount)個のタスク")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("プレビュー")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .cornerRadius(4)
        }
    }
}
```

## PhaseListViewとの統合

### 更新されたPhaseListView呼び出し

```swift
// PhaseListView内
struct PhaseListView: View {
    @State private var showCreateTaskList = false
    @State private var selectedPhase: Phase?
    
    var body: some View {
        // ... existing content
        
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("新規リスト") {
                    if let phase = getCurrentPhase() {
                        selectedPhase = phase
                        showCreateTaskList = true
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateTaskList) {
            if let phase = selectedPhase {
                CreateTaskListView(
                    phase: phase,
                    project: project
                )
                .environmentObject(sharedManagers.taskListManager)
                .environmentObject(sharedManagers.phaseManager)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .phaseStatisticsUpdated)) { notification in
            if let statistics = notification.object as? PhaseStatistics {
                updatePhaseStatistics(statistics)
            }
        }
    }
    
    private func updatePhaseStatistics(_ statistics: PhaseStatistics) {
        // Phase統計の更新
        Task {
            await phaseManager.syncPhaseStatistics()
        }
    }
}
```

### 成功フィードバック

```swift
// 作成成功時のフィードバック
private func showSuccessFeedback() {
    let feedback = UINotificationFeedbackGenerator()
    feedback.notificationOccurred(.success)
    
    // ハプティックフィードバックと組み合わせ
    withAnimation(.easeInOut) {
        // 成功状態のUI更新
    }
}
```

## Firestoreスキーマ統合

### コレクション構造

```yaml
families/{familyId}/
├── projects/{projectId}/
    ├── phases/{phaseId}/
        ├── taskLists/{taskListId}
        ├── statistics/
            └── summary: "集約統計"
```

### ドキュメント構造

```json
{
  "id": "tasklist-uuid-xxxx",
  "name": "UIコンポーネント実装",
  "description": "SwiftUIビューとコンポーネントの実装",
  "color": "blue",
  "phaseId": "phase-uuid-xxxx",
  "projectId": "project-uuid-xxxx", 
  "familyId": "family-uuid-xxxx",
  "order": 0,
  "isArchived": false,
  "taskCount": 0,
  "completedTaskCount": 0,
  "createdAt": "2025-09-05T10:30:00Z",
  "createdBy": "user-uuid-xxxx",
  "updatedAt": null,
  "updatedBy": null
}
```

### セキュリティルール

```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // TaskList access rules
    match /families/{familyId}/projects/{projectId}/phases/{phaseId}/taskLists/{taskListId} {
      allow read, write: if request.auth != null 
        && request.auth.uid in resource.data.memberIds
        && request.auth.uid in get(/databases/$(database)/documents/families/$(familyId)).data.memberIds;
      
      allow create: if request.auth != null
        && request.auth.uid in get(/databases/$(database)/documents/families/$(familyId)).data.memberIds
        && resource.data.phaseId == phaseId
        && resource.data.projectId == projectId
        && resource.data.familyId == familyId;
    }
  }
}
```

## 実装タイムライン

### Phase 1: コア統合（1日）

**タスク**:
1. CreateTaskListViewのPhase context更新
2. TaskListManager作成ロジック強化
3. PhaseManager統合追加

**成果物**:
- Phase認識型TaskList作成機能
- データ整合性保証
- 基本エラーハンドリング

### Phase 2: UI強化（1日）

**タスク**:
1. フォーム検証とエラーハンドリング改善
2. ローディング状態と成功フィードバック追加
3. ナビゲーション統合実装

**成果物**:
- 直感的なユーザーインターフェース
- 詳細な状態フィードバック
- シームレスなナビゲーション体験

### Phase 3: テスト＆磨き上げ（1日）

**タスク**:
1. 作成ワークフローのエンドツーエンドテスト
2. エッジケースとエラーシナリオ処理
3. アニメーションとトランジション追加

**成果物**:
- 包括的テストカバレッジ
- エラー回復機能
- 磨き上げられたUX

## 成功指標

### 技術的成功指標

- **TaskList作成成功率**: 95%以上
- **平均作成時間**: 3秒未満
- **データ整合性問題**: ゼロ
- **パフォーマンス**: UI反応60fps維持

### ユーザーエクスペリエンス指標

- **フォーム完了率**: 90%以上
- **ユーザー満足度評価**: 4.0/5.0以上
- **エラー回復成功率**: 80%以上
- **再利用率**: 創造されたTaskListの85%が実際に使用

## リスク軽減策

### データ整合性リスク

**対策**:
- ロールバック機能付き原子的操作
- 複数レベルでの検証
- 一貫した状態管理
- リアルタイム同期

### ユーザーエクスペリエンスリスク

**対策**:
- 回復オプション付き明確なエラーメッセージ
- ローディング状態でユーザー混乱防止
- 検証フィードバックでエラー予防
- オフライン対応とデータ同期

### パフォーマンスリスク

**対策**:
- オプティミスティックUI更新
- バックグラウンドFirestore操作
- 効率的なデータキャッシュ
- 段階的ローディング

---

**更新日**: 2025-09-05  
**関連Issue**: [#15](https://github.com/project/issues/15)  
**実装優先度**: 高