# 🔗 相互リンク戦略書

**策定日**: 2025-09-04  
**目的**: Diátaxisカテゴリ間の効果的な相互参照システム構築

## 🧭 リンク設計原則

### 1. Context-Aware Linking（文脈に応じたリンク）
各カテゴリから他カテゴリへの自然な参照パターン：

```
📖 Tutorials → 🛠️ Guides: 「学習後の実践」
🛠️ Guides → 📚 Reference: 「詳細仕様の確認」  
📚 Reference → 💡 Explanation: 「設計理由の理解」
💡 Explanation → 📖 Tutorials: 「実装方法の学習」
```

### 2. Progressive Disclosure（段階的詳細化）
情報の深さレベルに応じたリンク構造：

```
概要 → 基本 → 詳細 → 専門知識
  ↓     ↓     ↓       ↓
Intro → Tutorial → Guide → Reference + Explanation
```

## 📋 標準リンクテンプレート

### カテゴリ横断リンクフォーマット

```markdown
## 🔗 関連情報

### 📖 学習リソース
- [基本セットアップ](../tutorials/getting-started/environment-setup.md) - 環境構築方法
- [上級ワークフロー](../tutorials/advanced-workflows/ci-cd-setup.md) - CI/CD導入

### 🛠️ 実践ガイド  
- [具体的な解決手順](../guides/troubleshooting/build-errors.md) - エラー対処法
- [ベストプラクティス](../guides/development/feature-development.md) - 開発手法

### 📚 詳細仕様
- [技術仕様書](../reference/features/task-tags.md) - 機能の詳細
- [アーキテクチャ](../reference/architecture/security-audit.md) - システム設計

### 💡 背景情報
- [設計判断](../explanation/project-setup/development-principles.md) - なぜこの設計か
- [開発履歴](../explanation/project-history/phase6-completion.md) - 経緯と学び
```

## 🎯 カテゴリ別リンク戦略

### 📖 Tutorials からの参照パターン

**学習完了後の次のステップ**:
```markdown
## 🚀 学習完了後の次のステップ

### 実践で遭遇する課題
- 🛠️ [ビルドエラーの解決](../guides/troubleshooting/build-errors.md)
- 🛠️ [テスト手法の活用](../guides/testing/methodologies.md)

### より詳しく知りたい場合
- 📚 [Firebase設計の全体像](../reference/firebase/overview.md)
- 💡 [なぜこのアーキテクチャを選んだか](../explanation/project-setup/architecture-decisions.md)
```

### 🛠️ Guides からの参照パターン

**問題解決の前提知識と詳細情報**:
```markdown
## 📋 前提条件
- 📖 [環境構築](../tutorials/getting-started/environment-setup.md)が完了していること

## 🔍 詳細情報
- 📚 [詳細仕様](../reference/features/task-tags.md) - 機能の技術的詳細
- 💡 [設計背景](../explanation/design-analysis/tag-save-flow.md) - なぜこの実装方法か

## 🆘 さらに困ったら
- 🛠️ [よくある問題](../guides/troubleshooting/common-issues.md)
```

### 📚 Reference からの参照パターン

**仕様理解の補完情報**:
```markdown
## 📖 実装方法
- [基本的な実装手順](../tutorials/getting-started/testing-setup.md)

## 🛠️ 実践での活用
- [実際のトラブルシューティング](../guides/troubleshooting/build-errors.md)

## 💡 設計の背景
- [なぜこの仕様にしたか](../explanation/design-analysis/invitation-systems.md)
```

### 💡 Explanation からの参照パターン

**理解から実践への橋渡し**:
```markdown
## 📖 実装してみる
- [実際に環境構築する](../tutorials/getting-started/environment-setup.md)

## 🛠️ 実際の活用例
- [この設計を活かしたガイド](../guides/deployment/testflight.md)

## 📚 技術的詳細
- [具体的な仕様](../reference/features/export-functionality.md)
```

## 🔄 双方向リンク戦略

### Hub & Spoke モデル
各カテゴリのindex.mdをハブとして活用：

```
        📖 Tutorials
            ↑↓
📚 Reference ←→ 🛠️ Guides  
            ↑↓
        💡 Explanation
```

### Contextual Linking（文脈リンク）
ページ内の自然な文脈でリンク挿入：

```markdown
# ビルドエラーの解決

Firebase設定でよくあるエラーです。[Firebase設計の概要](../reference/firebase/overview.md)を確認し、[セキュリティルール](../reference/firebase/security-rules.md)が正しく設定されているか確認してください。

設定方法がわからない場合は、[環境構築ガイド](../tutorials/getting-started/environment-setup.md)から始めることをおすすめします。

この問題の設計的背景については、[Phase5完了レポート](../explanation/project-history/phase6-completion.md)で詳しく解説されています。
```

## 📊 リンク効果測定

### 成功指標
1. **ページ間遷移率**: 20%以上のクロスカテゴリ遷移
2. **滞在時間**: 平均3分以上の深い読み込み
3. **学習完了率**: チュートリアル→ガイド遷移80%以上
4. **問題解決率**: ガイド→リファレンス参照での解決90%以上

### A/Bテスト対象
- リンクテキストの表現（「詳細は～」vs「～を確認」）
- リンク配置（文中 vs 末尾 vs サイドバー）
- 視覚的強調（絵文字 vs アイコン vs 色）

## 🛠️ 実装方針

### Phase別実装
1. **Phase 3**: 基本的なクロスリンクを全index.mdに追加
2. **Phase 4-1**: コンテンツ移行時に文脈リンクを挿入
3. **Phase 4-2**: 双方向リンクの完全性チェック
4. **Phase 5**: 効果測定とリンク最適化

### 自動化戦略
- **リンクチェック**: GitHub Actions でリンク切れ検出
- **リンク提案**: 新規ページ作成時に関連リンク候補自動生成
- **効果測定**: Google Analytics でページ間遷移追跡

---

**期待効果**: ユーザーの情報発見効率50%向上、深い理解促進、自律的な問題解決能力向上