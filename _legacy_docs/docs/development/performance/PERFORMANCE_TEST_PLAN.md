# パフォーマンステストプラン - Phase 1

## 📊 測定対象とベンチマーク目標

### 1. アプリ起動時間
- **目標**: 冷間起動 < 3秒、温間起動 < 1秒
- **測定方法**: Xcode Instruments Time Profiler
- **測定ポイント**: 
  - アプリ起動開始 → MainTabView表示完了
  - Firebase初期化時間
  - 認証確認時間

### 2. メモリ使用量
- **目標**: 通常使用時 < 150MB、最大 < 250MB
- **測定方法**: Xcode Instruments Allocations
- **測定ポイント**:
  - アプリ起動時のベースライン
  - プロジェクト一覧表示時
  - 複数画面遷移後のピーク

### 3. Firebase操作レスポンス時間
- **目標**: 読み込み < 2秒、書き込み < 3秒
- **測定方法**: OSLog + Signposts
- **測定対象**:
  - プロジェクト一覧読み込み
  - タスク作成・更新
  - リアルタイムリスナー接続時間

### 4. UI応答性
- **目標**: 画面遷移 < 0.5秒、タップ応答 < 0.1秒
- **測定方法**: Xcode Instruments Core Animation
- **測定対象**:
  - タブ切り替え時間
  - プロジェクト詳細画面への遷移
  - リスト系画面のスクロール性能

## 🔧 Instruments設定手順

### 1. プロファイリング設定
```bash
# Release構成でビルド（パフォーマンス最適化有効）
xcodebuild -scheme shigodeki -configuration Release -destination 'platform=iOS Simulator,name=iPhone 15 Pro' clean build

# または実機での測定（推奨）
xcodebuild -scheme shigodeki -configuration Release -destination 'platform=iOS,id=YOUR_DEVICE_ID' clean build
```

### 2. Instruments起動
- Xcode → Product → Profile
- 測定対象のInstruments選択:
  - **Time Profiler**: CPU使用率、関数呼び出し時間
  - **Allocations**: メモリ使用量、リーク検出
  - **Leaks**: メモリリーク専用
  - **Core Animation**: FPS、描画性能

### 3. カスタムSignposts確認
- 統合したOSLogカテゴリー:
  - `com.company.shigodeki.Memory`
  - `com.company.shigodeki.Firebase`
  - `com.company.shigodeki.UI`
  - `com.company.shigodeki.Launch`
  - `com.company.shigodeki.Network`

## 📱 測定シナリオ

### シナリオ1: アプリ起動テスト
```
1. アプリを完全に終了
2. 冷間起動（初回起動）
3. Firebase認証確認
4. メイン画面表示完了まで測定
```

### シナリオ2: プロジェクト操作テスト
```
1. プロジェクト一覧表示
2. プロジェクト作成（新規）
3. プロジェクト詳細画面表示
4. フェーズ・タスク作成
5. リアルタイム同期確認
```

### シナリオ3: メモリストレステスト
```
1. ベースライン測定
2. 複数プロジェクト間の切り替え
3. 大量タスクリスト表示
4. 画面遷移を10回繰り返し
5. メモリリーク検出
```

### シナリオ4: Firebase接続テスト
```
1. ネットワーク切断状態で起動
2. オフライン操作（作成・更新）
3. ネットワーク復旧
4. 同期時間とデータ整合性確認
```

## 📈 測定結果の記録方法

### 1. Instrumentsでの測定
- `.trace`ファイルの保存
- スクリーンショット記録
- パフォーマンスグラフの出力

### 2. 自動ログ記録
```swift
// アプリ起動時
InstrumentsSetup.shared.startAppLaunchMeasurement()

// 各操作でメモリ使用量記録
InstrumentsSetup.shared.logMemoryUsage(context: "ProjectList")

// Firebase操作の測定
await PerformanceTestHelper.measureFirebaseOperation(operation: "LoadProjects") {
    return try await projectManager.getUserProjects(userId: userId)
}
```

### 3. 結果の分析基準
- **良好**: 目標値の80%以下
- **許容**: 目標値の100%以下
- **要改善**: 目標値の120%以上
- **緊急**: 目標値の150%以上

## 🎯 特定する問題の優先度

### 優先度1: 致命的問題
- アプリクラッシュ
- 応答停止（5秒以上）
- メモリリーク

### 優先度2: 深刻な問題
- 起動時間 > 5秒
- メモリ使用量 > 300MB
- Firebase操作 > 10秒

### 優先度3: 改善対象
- 目標値の120%を超える項目
- UI応答の遅延
- 不要なリスナー

## 🔄 次のPhaseへの移行基準

### Phase 1完了条件
1. ✅ 全シナリオの測定完了
2. ✅ 問題リストの作成（優先度付き）
3. ✅ ベースライン性能の記録
4. ✅ 改善すべき上位5項目の特定

### Phase 2準備
- 特定された問題の技術的解決策立案
- Firebase接続最適化方針の決定
- @StateObject管理方法の改善案
- 既存PerformanceOptimization.swiftの活用計画

## 📝 測定結果テンプレート

```markdown
# パフォーマンス測定結果 - [日付]

## 測定環境
- デバイス: iPhone 15 Pro Simulator / 実機
- iOS Version: 17.x
- Build Configuration: Release
- 測定時間: [時間]

## 結果サマリー
| 項目 | 目標値 | 実測値 | 判定 |
|------|--------|--------|------|
| 冷間起動 | <3秒 | X.X秒 | 🟢/🟡/🔴 |
| メモリ使用量 | <150MB | XXXMB | 🟢/🟡/🔴 |
| Firebase読み込み | <2秒 | X.X秒 | 🟢/🟡/🔴 |

## 発見された問題
1. [問題1] - 優先度: 高/中/低
2. [問題2] - 優先度: 高/中/低

## Phase 2での改善対象
1. [改善項目1]
2. [改善項目2]
```