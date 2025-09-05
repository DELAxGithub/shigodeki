# 📊 ドキュメント移行進捗管理

**現状認識**: 技術基盤完了、コンテンツ移行は序盤 (9/75ファイル完了 = 12%)

## 🎯 移行完了済み (9ファイル)

| 元ファイル | 新しい場所 | Sprint | 状況 |
|------------|------------|---------|------|
| `CLAUDE.md` | `docs/explanation/project-setup/development-principles.md` | S1 | ✅ 完了 |
| `BUILD_FIX_REPORT.md` | `docs/guides/troubleshooting/build-errors.md` | S1 | ✅ 完了 |
| `CRASH_FIX_REPORT.md` | `docs/guides/troubleshooting/crash-analysis.md` | S1 | ✅ 完了 |
| `task-tags-specification.md` | `docs/reference/features/task-tags-specification.md` | S2 | ✅ 完了 |
| `Security-Audit-Report.md` | `docs/reference/security/audit-report.md` | S2 | ✅ 完了 |
| `phase5-migration-overview.md` | `docs/reference/firebase/phase5-migration-overview.md` | S2 | ✅ 完了 |
| `Phase6-Final-Completion-Report.md` | `docs/explanation/project-history/phase6-completion.md` | S3 | ✅ 完了 |
| `CTO_FINAL_REPORT.md` | `docs/explanation/design-analysis/tag-functionality-crisis.md` | S3 | ✅ 完了 |
| `invitation-systems-analysis-report.md` | `docs/explanation/design-analysis/invitation-systems.md` | S3 | ✅ 完了 |

## ⚠️ 重複ファイル問題 (要解決)

| 古いファイル | 新しいファイル | 優先度 | 対応 |
|------------|-------------|---------|------|
| `docs/development/testing/newtips.md` | `docs-site/docs/guides/testing-methodologies.md` | 高 | 🔄 古い方を移行通知に変更 |

## 📋 未移行ファイル (優先度順)

### 🔥 超高優先度 (セットアップ・環境構築)

| ファイル | Diátaxis分類 | 移行先候補 | 語数 | 担当 | 状況 |
|----------|-------------|------------|------|------|------|
| `iOS/docs/setup/SETUP.md` | 📖 Tutorial | `tutorials/getting-started/environment-setup.md` | 1000 | - | ⏳ 未着手 |
| `iOS/docs/setup/SETUP_COMPLETE.md` | 📖 Tutorial | `tutorials/getting-started/project-configuration.md` | 500 | - | ⏳ 未着手 |
| `iOS/docs/setup/XCTest-Setup-Instructions.md` | 📖 Tutorial | `tutorials/getting-started/testing-setup.md` | 1000 | - | ⏳ 未着手 |

### 🚨 高優先度 (主要機能・アーキテクチャ)

| ファイル | Diátaxis分類 | 移行先候補 | 語数 | 担当 | 状況 |
|----------|-------------|------------|------|------|------|
| `iOS/docs/design/export-functionality-architecture.md` | 📚 Reference | `reference/features/export-functionality.md` | 1558 | - | ⏳ 未着手 |
| `iOS/docs/design/tasklist-creation-workflow.md` | 📚 Reference | `reference/features/tasklist-workflows.md` | 1227 | - | ⏳ 未着手 |
| `docs/development/architecture/UI-UX-Improvements-Report.md` | 💡 Explanation | `explanation/design-analysis/ui-ux-improvements.md` | 917 | - | ⏳ 未着手 |
| `docs/development/architecture/JSON_TEMPLATE_SYSTEM_COMPLETE.md` | 📚 Reference | `reference/architecture/json-template-system.md` | 800 | - | ⏳ 未着手 |

### 📊 Firebase Phase5 関連 (12ファイル)

| ファイル | Diátaxis分類 | 移行先候補 | 語数 | 担当 | 状況 |
|----------|-------------|------------|------|------|------|
| `docs/phases/phase5/phase5-security-rules.md` | 📚 Reference | `reference/firebase/security-rules.md` | 1507 | - | ⏳ 未着手 |
| `docs/phases/phase5/phase5-data-model-design.md` | 📚 Reference | `reference/firebase/data-model.md` | 1297 | - | ⏳ 未着手 |
| `docs/phases/phase5/phase5-index-strategy.md` | 📚 Reference | `reference/firebase/index-strategy.md` | 1260 | - | ⏳ 未着手 |
| `docs/phases/phase5/phase5-firestore-collection-structure.md` | 📚 Reference | `reference/firebase/collection-structure.md` | 1180 | - | ⏳ 未着手 |
| `docs/phases/phase5/phase5-migration-timeline.md` | 📚 Reference | `reference/firebase/migration/timeline.md` | 1114 | - | ⏳ 未着手 |
| `docs/phases/phase5/phase5-migration-technical-plan.md` | 📚 Reference | `reference/firebase/migration/technical-plan.md` | 1064 | - | ⏳ 未着手 |
| `docs/phases/phase5/phase5-data-integrity-verification.md` | 📚 Reference | `reference/firebase/validation.md` | 1060 | - | ⏳ 未着手 |
| `docs/phases/phase5/phase5-migration-cloud-functions.md` | 📚 Reference | `reference/firebase/migration/cloud-functions.md` | 1016 | - | ⏳ 未着手 |
| `docs/phases/phase5/phase5-migration-client-compatibility.md` | 📚 Reference | `reference/firebase/migration/compatibility.md` | 949 | - | ⏳ 未着手 |
| `docs/phases/phase5/phase5-migration-rollback-procedures.md` | 🛠️ Guides | `reference/firebase/migration/rollback.md` | 800 | - | ⏳ 未着手 |

### 🛠️ 開発・テスト・配布ガイド

| ファイル | Diátaxis分類 | 移行先候補 | 語数 | 担当 | 状況 |
|----------|-------------|------------|------|------|------|
| `docs/development/testing/manual-checklist.md` | 🛠️ Guides | `guides/testing/manual-checklist.md` | 800 | - | ⏳ 未着手 |
| `docs/deployment/testflight/TestFlight-Setup.md` | 🛠️ Guides | `guides/deployment/testflight.md` | 700 | - | ⏳ 未着手 |
| `docs/deployment/appstore/AppStore-Review-Checklist.md` | 🛠️ Guides | `guides/deployment/app-store.md` | 650 | - | ⏳ 未着手 |

### 📅 履歴・完了報告 (統合・整理対象)

| ファイル | Diátaxis分類 | 移行先候補 | 語数 | 担当 | 状況 |
|----------|-------------|------------|------|------|------|
| `docs/project-management/completion-reports/Phase4-Completion-Report.md` | 💡 Explanation | `explanation/project-history/phase4-completion.md` | 999 | - | ⏳ 未着手 |
| `docs/project-management/completion-reports/PHASE2_IMPLEMENTATION_REPORT.md` | 💡 Explanation | `explanation/project-history/phase2-completion.md` | 800 | - | ⏳ 未着手 |
| `docs/project-management/completion-reports/PHASE3_IMPLEMENTATION_REPORT.md` | 💡 Explanation | `explanation/project-history/phase3-completion.md` | 700 | - | ⏳ 未着手 |

## 🗑️ 削除・統合候補

| ファイル | 理由 | 対応 |
|----------|------|------|
| `docs/PROJECT_CLEANUP_LOG.md` | 一時的な作業記録 | 削除 or Archive |
| `docs/development/testing/quick_validation.sh` | スクリプトファイル | 別途管理 |
| 各種`README.md` | 個別案内 | 統合 or リダイレクト |

## 📈 進捗サマリー

- **完了**: 9/75ファイル (12%)
- **高優先度未着手**: 15ファイル
- **Firebase関連**: 12ファイル (大型プロジェクト)
- **重複要解決**: 2-3ファイル

## 🚀 次期Sprint計画

### Sprint 4: オンボーディング完全対応
- 環境構築系チュートリアル (3ファイル)
- 効果: 新規開発者の即座対応可能

### Sprint 5: 主要機能仕様統合
- エクスポート・タスクリスト機能仕様 (3ファイル)
- 効果: 開発チーム技術参照完全対応

### Sprint 6: Firebase完全統合
- Phase5関連12ファイルの体系的統合
- 効果: バックエンド技術基盤完全ドキュメント化

---

**更新日**: 2025-09-05  
**次回レビュー**: Sprint 4開始前  
**管理**: ドキュメント移行チーム