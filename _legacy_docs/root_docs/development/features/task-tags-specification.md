# タスクタグ機能 - 設計仕様書

## 📋 概要

Apple純正リマインダーを参考にしたタスクタグ機能の包括的な設計仕様書です。
既存の`ShigodekiTask.tags: [String]`フィールドを活用し、直感的で効率的なタスク分類システムを実現します。

## 🎯 運用設計（Apple純正リマインダー参考）

### タグの基本概念
- **用途**: タスクの横断的な分類・整理（優先度や担当者とは別軸）
- **視覚**: カラフルなタグUIで直感的な識別
- **検索**: タグベースのフィルタリング・検索機能
- **共有**: 家族メンバー間でのタグ共有と統一管理

### 推奨タグ体系
```
🏠 家事
   - 掃除、洗濯、料理、整理整頓関連

💰 支払い  
   - 各種料金、税金、保険料関連

🛒 買い物
   - 日用品、食材、消耗品購入

📋 事務
   - 手続き、書類作成、申請関連

🔧 修理・メンテナンス
   - 家電、設備の点検・修理

📞 連絡・コミュニケーション
   - 電話、メール、訪問対応

🎉 イベント・行事
   - 誕生日、記念日、季節行事準備

📚 学習・自己啓発
   - 勉強、スキルアップ、情報収集

🏥 健康・医療
   - 病院予約、健康管理、薬関連

🌱 趣味・娯楽
   - 個人の趣味、レクリエーション
```

## 🏗 データモデル設計

### 既存モデル拡張
```swift
// 既存: ShigodekiTask.tags: [String] ← 活用
struct ShigodekiTask {
    // ... 既存フィールド
    var tags: [String] // ← 既存フィールドを活用
}
```

### 新規タグマスターモデル
```swift
struct TaskTag: Identifiable, Codable, Hashable {
    var id: String?
    let name: String
    let color: String // Hex color code
    let emoji: String? // Optional emoji prefix
    var familyId: String
    var usageCount: Int // 使用頻度追跡
    var createdAt: Date?
    var lastUsedAt: Date?
    
    // 表示用プロパティ
    var displayName: String {
        if let emoji = emoji {
            return "\(emoji) \(name)"
        }
        return name
    }
}
```

### タグカラーパレット
```swift
enum TagColor: String, CaseIterable, Codable {
    case red = "#FF3B30"
    case orange = "#FF9500"
    case yellow = "#FFCC00"
    case green = "#34C759"
    case mint = "#00C7BE"
    case teal = "#30B0C7"
    case cyan = "#32ADE6"
    case blue = "#007AFF"
    case indigo = "#5856D6"
    case purple = "#AF52DE"
    case pink = "#FF2D92"
    case brown = "#A2845E"
    case gray = "#8E8E93"
    
    var swiftUIColor: Color {
        return Color(hex: self.rawValue)
    }
}
```

## 🎨 UI/UXコンポーネント設計

### 1. TagInputView - タグ入力・選択
**配置**: `CreateTaskView`に統合
**機能**:
- よく使うタグの候補表示（使用頻度順）
- 新規タグの作成機能
- タグの色選択UI
- リアルタイム検索・フィルタリング

```swift
struct TagInputView: View {
    @Binding var selectedTags: [String]
    let availableTags: [TaskTag]
    let onTagCreated: (TaskTag) -> Void
    
    @State private var searchText = ""
    @State private var showingCreateTag = false
    
    var filteredTags: [TaskTag] {
        let filtered = availableTags.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return filtered.isEmpty && !searchText.isEmpty 
            ? [] 
            : filtered.sorted { $0.usageCount > $1.usageCount }
    }
    
    var canCreateTag: Bool {
        !searchText.isEmpty && !availableTags.contains { $0.name.lowercased() == searchText.lowercased() }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search
            TextField("タグを検索または新規作成...", text: $searchText)
                .textFieldStyle(.roundedBorder)
            
            // Selected Tags
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedTags, id: \.self) { tagName in
                            // 仮のマスター情報を渡すか、別途取得ロジックが必要
                            // ここでは簡略化のため、色を固定で表示
                            TagChip(tagName: tagName, isSelected: true) {
                                selectedTags.removeAll { $0 == tagName }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Available Tags & Create Option
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    // 新規作成ボタンを候補の先頭に表示
                    if canCreateTag {
                        Button(action: {
                            showingCreateTag = true
                        }) {
                            Text("＋ \"\(searchText)\" を作成")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    ForEach(filteredTags) { tag in
                        TagChip(
                            tag: tag, 
                            isSelected: selectedTags.contains(tag.name)
                        ) {
                            toggleTag(tag.name)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateTag) {
            CreateTagView(
                initialName: searchText,
                onTagCreated: { newTag in
                    onTagCreated(newTag)
                    // 作成後、選択状態にし、検索テキストをクリア
                    if !selectedTags.contains(newTag.name) {
                        selectedTags.append(newTag.name)
                    }
                    searchText = ""
                }
            )
        }
    }
    
    private func toggleTag(_ tagName: String) {
        if let index = selectedTags.firstIndex(of: tagName) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tagName)
        }
    }
}
```

### 2. TagDisplayView - タスクでのタグ表示
**配置**: `TaskRowView`にタグチップ追加
**機能**:
- コンパクトなバッジ表示
- タップでタグフィルタリング
- 最大表示数制限（3個 + "他X個"）

```swift
struct TagDisplayView: View {
    let tags: [String]
    let tagMasters: [TaskTag]
    let maxDisplayCount = 3
    let onTagTapped: (String) -> Void
    
    var displayTags: [TaskTag] {
        let foundTags = tags.compactMap { tagName in
            tagMasters.first { $0.name == tagName }
        }
        return Array(foundTags.prefix(maxDisplayCount))
    }
    
    var remainingCount: Int {
        max(0, tags.count - maxDisplayCount)
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(displayTags) { tag in
                TagChip(tag: tag, size: .small) {
                    onTagTapped(tag.name)
                }
            }
            
            if remainingCount > 0 {
                Text("+\(remainingCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
    }
}
```

### 3. TagManagementView - タグマスター管理
**配置**: 設定画面からアクセス
**機能**:
- 家族共有のタグ一覧
- タグの作成・編集・削除（**安全な削除フロー**）
- 使用頻度に基づく整理
- 未使用タグの整理

```swift
struct TagManagementView: View {
    @StateObject private var tagManager = TagManager()
    @State private var showingCreateTag = false
    @State private var editingTag: TaskTag?
    @State private var tagToDelete: TaskTag?
    
    var sortedTags: [TaskTag] {
        tagManager.tags.sorted { $0.usageCount > $1.usageCount }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sortedTags) { tag in
                    TagManagementRow(
                        tag: tag,
                        onEdit: { editingTag = tag },
                        onDelete: {
                            // 使用状況に応じて削除フローを変更
                            if tag.usageCount > 0 {
                                tagToDelete = tag
                            } else {
                                tagManager.deleteTag(tag) // 未使用なら即削除
                            }
                        }
                    )
                }
            }
            .navigationTitle("タグ管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        showingCreateTag = true
                    }
                }
            }
            .alert(item: $tagToDelete) { tag in
                Alert(
                    title: Text("タグ「\(tag.name)」を削除しますか？"),
                    message: Text("このタグは\(tag.usageCount)個のタスクで使用されています。削除すると、これらのタスクからタグが解除されます。"),
                    primaryButton: .destructive(Text("削除")) {
                        tagManager.deleteTag(tag)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .sheet(isPresented: $showingCreateTag) {
            CreateTagView { newTag in
                tagManager.createTag(newTag)
            }
        }
        .sheet(item: $editingTag) { tag in
            EditTagView(tag: tag) { updatedTag in
                tagManager.updateTag(updatedTag)
            }
        }
    }
}
```

### 4. TagFilterView - フィルタリング機能
**配置**: `TaskDetailView`でタグベースフィルター
**機能**:
- 複数タグでのAND/OR検索（**UIでの明示が必要**）
- クイックフィルターボタン
- フィルター状態の視覚的表示

### 5. TagChip - 共通コンポーネント
```swift
struct TagChip: View {
    // 内部で使うプロパティ
    private let displayName: String
    private let backgroundColor: Color
    private let foregroundColor: Color
    private let size: TagSize
    private let action: () -> Void
    
    enum TagSize {
        case small, medium
        
        var font: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
            case .medium: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            }
        }
    }
    
    // イニシャライザを統一し、可読性を向上
    init(
        tag: TaskTag,
        size: TagSize = .medium,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.displayName = tag.displayName
        self.size = size
        self.action = action
        
        if isSelected {
            self.backgroundColor = Color(hex: tag.color)
            self.foregroundColor = .white
        } else {
            // 未選択時は背景を薄くし、文字色を保つことで可読性を確保
            self.backgroundColor = Color(hex: tag.color).opacity(0.2)
            self.foregroundColor = .primary
        }
    }
    
    // タグマスターがまだない場合（選択済みチップなど）
    init(
        tagName: String,
        size: TagSize = .medium,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.displayName = tagName
        self.size = size
        self.action = action
        
        if isSelected {
            self.backgroundColor = .accentColor
            self.foregroundColor = .white
        } else {
            self.backgroundColor = .gray.opacity(0.2)
            self.foregroundColor = .primary
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(displayName)
                .font(size.font)
                .foregroundColor(foregroundColor)
                .padding(size.padding)
                .background(backgroundColor)
                .cornerRadius(size.cornerRadius)
        }
        .buttonStyle(.plain)
    }
}
```

## 📊 データベース設計

### Firestore構造
```
families/{familyId}/
├── tasks/{taskId}
│   ├── title: String
│   ├── description: String
│   ├── tags: [String] (既存フィールド)
│   └── ... (他の既存フィールド)
│
└── tagMasters/{tagId}
    ├── name: String
    ├── color: String (Hex code)
    ├── emoji: String?
    ├── familyId: String
    ├── usageCount: Number
    ├── createdAt: Timestamp
    └── lastUsedAt: Timestamp
```

### インデックス戦略
```javascript
// 必要な複合インデックス
db.collection("families/{familyId}/tagMasters")
  .createIndex({
    familyId: 1,
    usageCount: -1
  });

db.collection("families/{familyId}/tagMasters")
  .createIndex({
    familyId: 1,
    name: 1
  });
```

## 🔧 実装フェーズ計画

### Phase 1: 基本機能（1週間）
**目標**: タグの基本的な作成・表示機能
1. `TaskTag`モデル作成・Firestore統合
2. `TagChip`共通コンポーネント実装
3. `CreateTaskView`に`TagInputView`統合
4. `TaskRowView`に`TagDisplayView`統合
5. 基本的なCRUD操作

**成果物**:
- タグ作成・選択機能
- タスクでのタグ表示
- データベース基盤構築

### Phase 2: 管理機能（1週間）
**目標**: タグマスター管理と使用状況追跡
1. `TagManagementView`実装
2. タグ使用履歴追跡システム
3. 未使用タグの整理機能
4. タグ編集・削除機能（**安全な削除フロー含む**）
5. バルク操作機能

**成果物**:
- タグ管理画面
- 使用頻度ベース整理
- 家族共有タグシステム

### Phase 3: 高度機能（1週間）
**目標**: フィルタリングと検索機能
1. `TagFilterView`実装
2. タグベースタスクフィルタリング
3. 複数タグでのAND/OR検索
4. クイックフィルターボタン
5. タグ推奨システム（AI連携）

**成果物**:
- 高度なフィルタリング機能
- タグベース検索
- AI推奨タグ機能

## 🧪 テスト計画

### 単体テスト
```swift
// TagManagerTests.swift
class TagManagerTests: XCTestCase {
    func testCreateTag() {
        // タグ作成テスト
    }
    
    func testUpdateUsageCount() {
        // 使用回数更新テスト
    }
    
    func testDeleteUnusedTags() {
        // 未使用タグ削除テスト
    }
    
    func testDeleteUsedTagWithConfirmation() {
        // 使用中タグの削除確認フローテスト
    }
}

// TagFilterTests.swift  
class TagFilterTests: XCTestCase {
    func testANDFiltering() {
        // AND検索テスト
    }
    
    func testORFiltering() {
        // OR検索テスト
    }
}
```

### 統合テスト
- タグ付きタスクの作成・更新・削除
- 家族メンバー間でのタグ共有
- リアルタイム更新の整合性

### UIテスト  
- タグ選択UI操作
- フィルタリング機能
- タグ管理画面操作

## 🎨 UX考慮事項

### 直感性
- Apple純正リマインダーとのUIパターン統一
- 色分けとエモジによる視覚的分かりやすさ
- 一貫したインタラクションデザイン
- **検索から作成までのシームレスなフロー**

### 効率性
- よく使うタグの上位表示
- クイック選択機能
- キーボードショートカット対応

### 家族共有
- 統一されたタグ体系
- 利用状況の可視化
- 重複タグの防止機能
- **意図しないデータ破壊を防ぐ安全な削除フロー**

### パフォーマンス
- タグ数が多い場合の仮想化表示
- 遅延読み込み対応
- キャッシュ機能活用

### アクセシビリティ
- **十分なカラーコントラストの確保**
- VoiceOver対応

## 🔒 セキュリティ・プライバシー

### データ保護
- 家族スコープでのタグ隔離
- 適切なFirestoreセキュリティルール
- PII（個人識別情報）の除外

### アクセス制御
```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 家族メンバーは自分の家族のタグを読み書きできる
    // request.auth.token.familyId で家族IDを検証することを推奨
    match /families/{familyId}/tagMasters/{tagId} {
      allow read, write: if request.auth != null && get(/databases/$(database)/documents/families/$(familyId)).data.members[request.auth.uid] != null;
    }
  }
}
```

## 📈 拡張可能性

### 将来的な機能拡張
- タグベースの統計・分析機能
- 自動タグ提案（ML活用）
- タグテンプレート機能
- 他アプリとのタグ同期

---

## 📝 更新履歴
- 2025-01-XX: 初版作成
- Phase完了時に適宜更新予定

---

**このドキュメントは開発チーム全体での仕様共有と、一貫した実装のためのリファレンスとして活用してください。**
                    showingCreateTag = true
                }
                .disabled(searchText.isEmpty)
            }
            
            // Selected Tags
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedTags, id: \.self) { tagName in
                            TagChip(tagName: tagName, isSelected: true) {
                                selectedTags.removeAll { $0 == tagName }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Available Tags
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(filteredTags) { tag in
                    TagChip(
                        tag: tag, 
                        isSelected: selectedTags.contains(tag.name)
                    ) {
                        toggleTag(tag.name)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateTag) {
            CreateTagView(
                initialName: searchText,
                onTagCreated: onTagCreated
            )
        }
    }
}
```

### 2. TagDisplayView - タスクでのタグ表示
**配置**: `TaskRowView`にタグチップ追加
**機能**:
- コンパクトなバッジ表示
- タップでタグフィルタリング
- 最大表示数制限（3個 + "他X個"）

```swift
struct TagDisplayView: View {
    let tags: [String]
    let tagMasters: [TaskTag]
    let maxDisplayCount = 3
    let onTagTapped: (String) -> Void
    
    var displayTags: [TaskTag] {
        let foundTags = tags.compactMap { tagName in
            tagMasters.first { $0.name == tagName }
        }
        return Array(foundTags.prefix(maxDisplayCount))
    }
    
    var remainingCount: Int {
        max(0, tags.count - maxDisplayCount)
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(displayTags) { tag in
                TagChip(tag: tag, size: .small) {
                    onTagTapped(tag.name)
                }
            }
            
            if remainingCount > 0 {
                Text("+\(remainingCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
    }
}
```

### 3. TagManagementView - タグマスター管理
**配置**: 設定画面からアクセス
**機能**:
- 家族共有のタグ一覧
- タグの作成・編集・削除
- 使用頻度に基づく整理
- 未使用タグの整理

```swift
struct TagManagementView: View {
    @StateObject private var tagManager = TagManager()
    @State private var showingCreateTag = false
    @State private var editingTag: TaskTag?
    
    var sortedTags: [TaskTag] {
        tagManager.tags.sorted { $0.usageCount > $1.usageCount }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("よく使うタグ") {
                    ForEach(sortedTags.prefix(10)) { tag in
                        TagManagementRow(
                            tag: tag,
                            onEdit: { editingTag = tag },
                            onDelete: { tagManager.deleteTag(tag) }
                        )
                    }
                }
                
                if sortedTags.count > 10 {
                    Section("その他のタグ") {
                        ForEach(Array(sortedTags.dropFirst(10))) { tag in
                            TagManagementRow(
                                tag: tag,
                                onEdit: { editingTag = tag },
                                onDelete: { tagManager.deleteTag(tag) }
                            )
                        }
                    }
                }
            }
            .navigationTitle("タグ管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        showingCreateTag = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateTag) {
            CreateTagView { newTag in
                tagManager.createTag(newTag)
            }
        }
        .sheet(item: $editingTag) { tag in
            EditTagView(tag: tag) { updatedTag in
                tagManager.updateTag(updatedTag)
            }
        }
    }
}
```

### 4. TagFilterView - フィルタリング機能
**配置**: `TaskDetailView`でタグベースフィルター
**機能**:
- 複数タグでのAND/OR検索
- クイックフィルターボタン
- フィルター状態の視覚的表示

### 5. TagChip - 共通コンポーネント
```swift
struct TagChip: View {
    let tag: TaskTag?
    let tagName: String?
    let isSelected: Bool
    let size: TagSize
    let action: () -> Void
    
    enum TagSize {
        case small, medium, large
        
        var fontSize: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .footnote
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
            case .medium: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .large: return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            }
        }
    }
    
    init(tag: TaskTag, size: TagSize = .medium, isSelected: Bool = false, action: @escaping () -> Void) {
        self.tag = tag
        self.tagName = nil
        self.size = size
        self.isSelected = isSelected
        self.action = action
    }
    
    init(tagName: String, size: TagSize = .medium, isSelected: Bool = false, action: @escaping () -> Void) {
        self.tag = nil
        self.tagName = tagName
        self.size = size
        self.isSelected = isSelected
        self.action = action
    }
    
    var displayName: String {
        tag?.displayName ?? tagName ?? ""
    }
    
    var backgroundColor: Color {
        if let tag = tag {
            return Color(hex: tag.color).opacity(isSelected ? 1.0 : 0.3)
        }
        return isSelected ? .blue : .gray.opacity(0.3)
    }
    
    var body: some View {
        Button(action: action) {
            Text(displayName)
                .font(size.fontSize)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(size.padding)
                .background(backgroundColor)
                .cornerRadius(size == .small ? 6 : 8)
        }
        .buttonStyle(.plain)
    }
}
```

## 📊 データベース設計

### Firestore構造
```
families/{familyId}/
├── tasks/{taskId}
│   ├── title: String
│   ├── description: String
│   ├── tags: [String] (既存フィールド)
│   └── ... (他の既存フィールド)
│
└── tagMasters/{tagId}
    ├── name: String
    ├── color: String (Hex code)
    ├── emoji: String?
    ├── familyId: String
    ├── usageCount: Number
    ├── createdAt: Timestamp
    └── lastUsedAt: Timestamp
```

### インデックス戦略
```javascript
// 必要な複合インデックス
db.collection("families/{familyId}/tagMasters")
  .createIndex({
    familyId: 1,
    usageCount: -1
  });

db.collection("families/{familyId}/tagMasters")
  .createIndex({
    familyId: 1,
    name: 1
  });
```

## 🔧 実装フェーズ計画

### Phase 1: 基本機能（1週間）
**目標**: タグの基本的な作成・表示機能
1. `TaskTag`モデル作成・Firestore統合
2. `TagChip`共通コンポーネント実装
3. `CreateTaskView`に`TagInputView`統合
4. `TaskRowView`に`TagDisplayView`統合
5. 基本的なCRUD操作

**成果物**:
- タグ作成・選択機能
- タスクでのタグ表示
- データベース基盤構築

### Phase 2: 管理機能（1週間）
**目標**: タグマスター管理と使用状況追跡
1. `TagManagementView`実装
2. タグ使用履歴追跡システム
3. 未使用タグの整理機能
4. タグ編集・削除機能
5. バルク操作機能

**成果物**:
- タグ管理画面
- 使用頻度ベース整理
- 家族共有タグシステム

### Phase 3: 高度機能（1週間）
**目標**: フィルタリングと検索機能
1. `TagFilterView`実装
2. タグベースタスクフィルタリング
3. 複数タグでのAND/OR検索
4. クイックフィルターボタン
5. タグ推奨システム（AI連携）

**成果物**:
- 高度なフィルタリング機能
- タグベース検索
- AI推奨タグ機能

## 🧪 テスト計画

### 単体テスト
```swift
// TagManagerTests.swift
class TagManagerTests: XCTestCase {
    func testCreateTag() {
        // タグ作成テスト
    }
    
    func testUpdateUsageCount() {
        // 使用回数更新テスト
    }
    
    func testDeleteUnusedTags() {
        // 未使用タグ削除テスト
    }
}

// TagFilterTests.swift  
class TagFilterTests: XCTestCase {
    func testANDFiltering() {
        // AND検索テスト
    }
    
    func testORFiltering() {
        // OR検索テスト
    }
}
```

### 統合テスト
- タグ付きタスクの作成・更新・削除
- 家族メンバー間でのタグ共有
- リアルタイム更新の整合性

### UIテスト  
- タグ選択UI操作
- フィルタリング機能
- タグ管理画面操作

## 🎨 UX考慮事項

### 直感性
- Apple純正リマインダーとのUIパターン統一
- 色分けとエモジによる視覚的分かりやすさ
- 一貫したインタラクションデザイン

### 効率性
- よく使うタグの上位表示
- クイック選択機能
- キーボードショートカット対応

### 家族共有
- 統一されたタグ体系
- 利用状況の可視化
- 重複タグの防止機能

### パフォーマンス
- タグ数が多い場合の仮想化表示
- 遅延読み込み対応
- キャッシュ機能活用

## 🔒 セキュリティ・プライバシー

### データ保護
- 家族スコープでのタグ隔離
- 適切なFirestoreセキュリティルール
- PII（個人識別情報）の除外

### アクセス制御
```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /families/{familyId}/tagMasters/{tagId} {
      allow read, write: if request.auth != null 
        && request.auth.uid in resource.data.members;
    }
  }
}
```

## 📈 拡張可能性

### 将来的な機能拡張
- タグベースの統計・分析機能
- 自動タグ提案（ML活用）
- タグテンプレート機能
- 他アプリとのタグ同期

### 技術的拡張性
- GraphQL API対応
- オフライン同期機能
- マルチプラットフォーム対応
- サードパーティ統合

---

## 📝 更新履歴
- 2025-01-XX: 初版作成
- Phase完了時に適宜更新予定

---

**このドキュメントは開発チーム全体での仕様共有と、一貫した実装のためのリファレンスとして活用してください。**