# 📚 シゴデキ プロジェクトドキュメント

シゴデキ（Shigodeki）iOSアプリプロジェクトの包括的ドキュメントライブラリ

---

## 📜 我々の憲法

**[開発方針とプロジェクト原則](./explanation/project-setup/development-principles.md)**

**このドキュメントは、本プロジェクトにおける全ての判断と行動の基盤となる最重要文書です。**

---

## 🎯 クイックアクセス

### 🧪 テスト・品質検証
- **[iOS Testing新手法](development/testing/newtips.md)** - Context7調査ベースの最新検証手法 ⭐️
- **[手動テストチェックリスト](development/testing/manual-checklist.md)** - 体系的検証手順
- **[クイック検証スクリプト](development/testing/quick_validation.sh)** - 5分で基本検証

### 🏗️ 開発・アーキテクチャ  
- **[パフォーマンス分析](development/performance/)** - Phase1〜現在の最適化履歴
- **[アーキテクチャ設計](development/architecture/)** - システム設計・UI/UX改善記録
- **[トラブルシューティング](development/troubleshooting/)** - ビルドエラー・クラッシュ修正履歴

### 🚀 デプロイメント・配布
- **[App Store申請](deployment/appstore/)** - メタデータ・審査チェックリスト
- **[TestFlight配布](deployment/testflight/)** - ベータテスト・デバイステスト
- **[Firebase設定](deployment/firebase/)** - バックエンド設定・セキュリティルール

### 📋 プロジェクト管理
- **[完了レポート](project-management/completion-reports/)** - フェーズ別実装完了記録
- **[セッション記録](project-management/session-prompts/)** - 開発セッション履歴・プロンプト

### 📱 iOS固有ドキュメント
- **[セットアップガイド](../iOS/docs/setup/)** - プロジェクト初期設定・環境構築
- **[テスト設定](../iOS/docs/testing/)** - XCTest・UI Testing設定

## 📂 ディレクトリ構造

```
docs/
├── development/           # 開発関連
│   ├── testing/          # テスト・検証手法
│   ├── performance/      # パフォーマンス最適化  
│   ├── architecture/     # システム設計・UI/UX
│   └── troubleshooting/  # 問題解決記録
├── phases/               # 開発フェーズ別
│   └── phase5/          # Phase 5: Firebase設計
├── deployment/           # デプロイ・配布
│   ├── appstore/        # App Store申請
│   ├── testflight/      # TestFlight配布
│   └── firebase/        # Firebase設定
└── project-management/   # プロジェクト管理
    ├── completion-reports/  # 完了レポート
    └── session-prompts/     # セッション記録
```

## 🎯 目的別ナビゲーション

### 🆕 新規開発者向け
1. [プロジェクトセットアップ](../iOS/docs/setup/SETUP.md)
2. [開発環境構築](../iOS/docs/setup/SETUP_COMPLETE.md)
3. [テスト環境準備](development/testing/manual-checklist.md)

### 🔍 品質検証担当者向け
1. [iOS Testing新手法](development/testing/newtips.md) ⭐️
2. [クイック検証実行](development/testing/quick_validation.sh)
3. [パフォーマンステスト](development/performance/)

### 📱 App Store申請担当者向け
1. [申請メタデータ](deployment/appstore/)
2. [審査チェックリスト](deployment/appstore/)
3. [TestFlight設定](deployment/testflight/)

### 🔧 技術負債・問題解決
1. [トラブルシューティング履歴](development/troubleshooting/)
2. [パフォーマンス問題解決](development/performance/)
3. [アーキテクチャ改善記録](development/architecture/)

## 📊 プロジェクト状況

- **開発フェーズ**: Phase 6 完了 → Phase 7 品質検証中
- **主要機能**: プロジェクト管理、タスク管理、家族共有、AI統合
- **技術スタック**: SwiftUI, Firebase, iOS 17+
- **品質状況**: ビルドエラー修正完了、検証手法確立

## 🔄 ドキュメント更新履歴

- **2025-08-29**: iOS Testing新手法確立・ドキュメント構造整理
- **Phase 6**: App Store申請準備完了
- **Phase 5**: Firebase設計・セキュリティルール策定
- **Phase 1-4**: 基本機能実装・パフォーマンス最適化

---

**最終更新**: 2025-08-29  
**プロジェクト**: シゴデキ（Shigodeki）iOS App  
**技術責任者**: AI Assistant + Human Developer