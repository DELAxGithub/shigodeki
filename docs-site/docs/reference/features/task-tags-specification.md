# タスクタグ機能仕様

シゴデキアプリのタスクタグ機能に関する技術仕様書です。

## 🔗 関連情報

- 📱 [Apple純正リマインダー](https://support.apple.com/ja-jp/guide/reminders/welcome/mac) - UI/UX参考元
- 🛠️ [開発ガイド](../../guides/development/feature-implementation.md) - 実装手法
- 📖 [環境構築](../../tutorials/getting-started/environment-setup.md) - 初期セットアップ

---

# 📋 概要

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
   - 家電、設備、車両の点検・修理

🚗 外出・送迎
   - 病院、学校、習い事関連

🎯 個人目標
   - 健康、学習、自己啓発関連
```

## 💾 データ構造設計

### 既存フィールド活用
```swift
struct ShigodekiTask {
    // 既存フィールド（変更なし）
    var id: String
    var title: String
    var tags: [String]  // ← この配列を活用
    
    // その他既存フィールド...
}
```

### タグ色定義システム
```swift
struct TaskTag {
    let name: String
    let color: TagColor
    let emoji: String?
    let isBuiltIn: Bool  // プリセット or ユーザー作成
}

enum TagColor: String, CaseIterable {
    case red = "#FF3B30"
    case orange = "#FF9500"
    case yellow = "#FFCC00"
    case green = "#34C759"
    case mint = "#00C7BE"
    case teal = "#30B0C7"
    case cyan = "#32D2FF"
    case blue = "#007AFF"
    case indigo = "#5856D6"
    case purple = "#AF52DE"
    case pink = "#FF2D92"
    case brown = "#A2845E"
}
```

## 🖥️ UI/UX仕様

### タグ表示
- **チップ型UI**: 角丸長方形、カラー背景、白文字
- **絵文字サポート**: 視認性向上のための絵文字表示
- **サイズ**: 標準14pt、コンパクト12pt

### タグ選択インターフェース
- **多段階選択**: 複数タグの同時適用対応
- **予測入力**: タイピング時のタグ候補表示
- **色分けプレビュー**: 選択前の色確認機能

### フィルタリング機能
- **AND/OR条件**: 複数タグの論理結合選択
- **クイックフィルタ**: よく使うタグの1タップ適用
- **保存済み検索**: 条件組み合わせのプリセット機能

## 🏗️ アーキテクチャ設計

### タグ管理クラス
```swift
class TagManager: ObservableObject {
    @Published var availableTags: [TaskTag] = []
    @Published var builtInTags: [TaskTag] = []
    @Published var customTags: [TaskTag] = []
    
    // CRUD操作
    func createTag(name: String, color: TagColor) -> TaskTag
    func updateTag(_ tag: TaskTag, name: String?, color: TagColor?)
    func deleteTag(_ tag: TaskTag) -> Bool
    
    // 検索・フィルタ
    func filterTasks(by tags: [String], condition: FilterCondition) -> [ShigodekiTask]
    func suggestTags(for input: String) -> [TaskTag]
}

enum FilterCondition {
    case any  // OR条件: いずれかのタグを持つ
    case all  // AND条件: すべてのタグを持つ
}
```

### データ永続化
```swift
// Firestore構造
families/{familyId}/tagPresets/{tagId} {
    name: "家事",
    color: "#34C759",
    emoji: "🏠",
    isBuiltIn: true,
    createdBy: "user_id",
    createdAt: Timestamp,
    usageCount: 42  // 使用頻度追跡
}
```

## 📱 実装フェーズ

### Phase 1: 基盤実装 (Week 1-2)
- [ ] `TaskTag`モデル定義
- [ ] `TagManager`クラス作成
- [ ] プリセットタグ初期データ
- [ ] 基本CRUD操作

### Phase 2: UI実装 (Week 3-4)
- [ ] タグ表示コンポーネント
- [ ] タグ選択画面
- [ ] カラーピッカー統合
- [ ] 予測入力機能

### Phase 3: 検索・フィルタ (Week 5-6)
- [ ] フィルタリングロジック
- [ ] 保存済み検索
- [ ] 高度な検索条件
- [ ] パフォーマンス最適化

### Phase 4: 統計・分析 (Week 7-8)
- [ ] タグ使用頻度分析
- [ ] 生産性レポート
- [ ] タグ利用推奨機能
- [ ] 家族間使用パターン分析

## ⚡ パフォーマンス考慮

### インデックス戦略
```javascript
// Firestore複合インデックス
families/{familyId}/tasks
- tags (array) + isCompleted (boolean)
- tags (array) + dueDate (timestamp)
- tags (array) + priority (string)
```

### キャッシュ戦略
- **フレッシュ度**: 1時間キャッシュ、バックグラウンド更新
- **プリロード**: よく使うタグの事前読み込み
- **オフライン**: 最低限のタグ情報をローカル保存

## 🧪 テスト戦略

### ユニットテスト
- [ ] TagManagerクラス各メソッド
- [ ] フィルタリングロジック
- [ ] データ変換処理

### UIテスト
- [ ] タグ選択フロー
- [ ] マルチタグフィルタリング
- [ ] カスタムタグ作成

### パフォーマンステスト
- [ ] 大量タグ（100+）でのフィルタ性能
- [ ] 複雑な検索条件でのレスポンス時間
- [ ] メモリ使用量監視

## 🔐 セキュリティ考慮

### データバリデーション
```swift
struct TagValidator {
    static let maxNameLength = 20
    static let maxTagsPerTask = 10
    static let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces)
    
    static func validate(_ tagName: String) -> ValidationResult {
        guard !tagName.isEmpty else { return .empty }
        guard tagName.count <= maxNameLength else { return .tooLong }
        guard tagName.rangeOfCharacter(from: allowedCharacters.inverted) == nil 
        else { return .invalidCharacters }
        return .valid
    }
}
```

### 権限管理
- **家族メンバー**: 既存タグ使用、新規タグ提案
- **管理者**: 全タグ管理、家族共通タグ設定
- **読み取り専用**: タグでの検索・フィルタのみ

## 📊 成功指標

### 利用率KPI
- タグ付きタスク割合: 目標70%以上
- 1ユーザー当たり平均アクティブタグ数: 5-8個
- カスタムタグ作成率: 月1個以上/ユーザー

### 検索効率KPI  
- タグ検索使用率: 全検索の50%以上
- 検索結果への満足度: 4.0以上/5.0
- フィルタ適用後のタスク実行率: 80%以上

---

*最終更新: 2025-09-04*  
*関連Issue: [タスクタグ機能実装 #42](https://github.com/company/shigodeki/issues/42)*