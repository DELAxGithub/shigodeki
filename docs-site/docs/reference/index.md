# 📚 Technical Reference - 技術仕様

シゴデキプロジェクトの技術的詳細と仕様書集です。

## 🏗️ Architecture - システム設計

システム全体のアーキテクチャと設計判断

- [システム概要](./architecture/overview.md) - 全体アーキテクチャ
- [セキュリティ監査](./architecture/security-audit.md) - セキュリティ仕様
- [UI/UX改善](./architecture/ui-ux-improvements.md) - ユーザビリティ設計
- [JSONテンプレートシステム](./architecture/json-template-system.md) - データ構造設計

## ✨ Features - 機能仕様

個別機能の詳細仕様

- [タスクタグ機能](./features/task-tags.md) - タグシステム仕様 ⭐️
- [エクスポート機能](./features/export-functionality.md) - データ出力機能
- [タスクリストワークフロー](./features/tasklist-workflows.md) - リスト管理フロー

## 🔥 Firebase - バックエンド設計

Firebaseを使用したバックエンドシステムの包括的設計書

### Core Design
- [概要](./firebase/overview.md) - Firebase設計全体像
- [データモデル](./firebase/data-model.md) - Firestoreスキーマ設計
- [セキュリティルール](./firebase/security-rules.md) - アクセス制御
- [コレクション構造](./firebase/collection-structure.md) - データベース構造
- [インデックス戦略](./firebase/index-strategy.md) - クエリ最適化
- [データ検証](./firebase/validation.md) - 整合性保証

### Migration
- [移行概要](./firebase/migration/overview.md) - Phase5移行計画
- [技術計画](./firebase/migration/technical-plan.md) - 実装詳細
- [スケジュール](./firebase/migration/timeline.md) - 移行タイムライン
- [Cloud Functions](./firebase/migration/cloud-functions.md) - サーバーレス関数
- [互換性](./firebase/migration/compatibility.md) - クライアント対応
- [ロールバック](./firebase/migration/rollback.md) - 緊急時対応

## 🔌 API - インターフェース仕様

将来のAPI設計（予定）

- [API概要](./api/index.md) - RESTful API設計計画

## 🔗 関連情報

- 📖 [チュートリアル](../tutorials/index.md) - 実装方法を学ぶ
- 🛠️ [実践ガイド](../guides/index.md) - 具体的な実装手順
- 💡 [背景情報](../explanation/index.md) - 設計判断の理由

---

**使い方**: 実装時の詳細仕様確認、システム理解の深化に活用してください。