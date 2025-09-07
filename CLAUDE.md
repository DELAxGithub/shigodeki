# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

シゴデキ (Shigodeki) is an iOS application project using Firebase as the backend. This is currently in the initial setup phase with architecture planning completed but implementation not yet started.

## Project Architecture

### Environment Strategy
- **Dual Environment Setup**: The project uses separate Firebase projects for development and production
  - Development: `shigodeki-dev` 
  - Production: `shigodeki-prod`
- **Bundle ID Separation**: 
  - Production: `com.company.shigodeki`
  - Development: `com.company.shigodeki.dev`

### Firebase Configuration
- **Authentication Methods**: Sign in with Apple (mandatory), with optional Email/Password and Google authentication
- **Database**: Firestore with family-shared data model
- **Data Structure**:
  ```
  families/{familyId}/
  ├── taskLists/{listId}/
  │   └── tasks/{taskId}
  └── users/{userId}
  ```

### Security Model
- Users can only access their own user data
- Family data is restricted to family members only
- Firestore security rules enforce these access patterns

### iOS Project Structure
- Configuration files stored in `Firebase/Config/`:
  - `GoogleService-Info-Dev.plist` (development)
  - `GoogleService-Info-Prod.plist` (production)
- Build script automatically copies appropriate config file based on build configuration
- Debug builds connect to development Firebase project
- Release builds connect to production Firebase project

## Development Workflow

### Initial Setup Commands
```bash
# Install Firebase CLI
npm install -g firebase-tools
firebase login

# Create Firebase projects
firebase projects:create shigodeki-dev --display-name "シゴデキ (Dev)"
firebase projects:create shigodeki-prod --display-name "シゴデキ (Prod)"

# Register iOS apps (run interactively for each environment)
firebase apps:create
```

### Build Configuration
- The project uses Xcode build phases with run scripts to handle environment-specific configuration
- No manual file switching required - build configuration automatically selects appropriate Firebase config

## Key Implementation Notes

- Start development with user registration/login functionality
- Verify Firestore connectivity by testing data writes to the `users` collection
- Firebase SDK includes: `FirebaseAuth`, `FirebaseFirestore`, `FirebaseFirestoreSwift`
- Initialization code: `FirebaseApp.configure()` in AppDelegate or main App file

## Code Organization Principles

### Single Responsibility Principle
- **1ファイル1責任**: Each file should have one clear responsibility
- **File Size Limit**: Keep files under 300 lines when possible
- **Component Separation**: Separate views, view models, and utility functions into different files
- **Shared Components**: Extract reusable components into separate files

### File Structure Guidelines
- **Views**: Each SwiftUI View should be in its own file
- **Row Components**: Extract row views (e.g., `TaskRowView`, `ProjectRowView`) into separate files
- **Shared Components**: Create a `Components/` folder for reusable UI elements
- **Extensions**: Put extensions in separate files grouped by type

### Naming Conventions
- Views: `[Feature][Purpose]View.swift` (e.g., `ProjectDetailView.swift`)
- Components: `[Entity]RowView.swift` (e.g., `ProjectRowView.swift`)
- Managers: `[Entity]Manager.swift` (e.g., `ProjectManager.swift`)

### Refactoring Guidelines
When a file becomes too large (>300 lines):
1. Extract row components into separate files
2. Extract utility functions into extensions
3. Break complex views into smaller sub-views
4. Move shared components to a common location

## 不具合修正の鉄則 (Bug Fixing Protocol)

場当たり的な修正は、さらなる不具合を生む最悪の行為である。すべての不具合修正は、以下の厳格なプロトコルに従うこと。

1.  **再現手順の確立 (Reproduce)**: Issueを元に、不具合を100%再現させる手順を特定する。手動での確認だけでなく、可能であればUIテストで再現コードを記述する。

2.  **失敗するテストの作成 (Write a Failing Test)**: 修正対象のロジックに対し、**まず**その不具合によって失敗するユニットテストを作成する。このテストが、修正が完了したことの「証明」となる。テストのない修正は認めない。

3.  **コードの修正 (Fix the Code)**: 作成したテストが成功するように、コードを修正する。修正は、影響範囲を最小限に留めること。

4.  **リグレッションテストの実行 (Run Regression Tests)**: 修正によって他の機能が破壊されていないことを確認するため、関連するすべてのテスト（ユニットテスト、UIテスト）を実行し、すべてパスすることを確認する。

5.  **プルリクエスト/コミット (Submit)**: コミットメッセージには、修正内容、原因、そして対応するテストケースについて明確に記述する。

## テスト駆動開発 (Test-Driven Development - TDD)

- **No Test, No Merge**: テストコードのない機能追加・不具合修正は、理由の如何を問わずマージを許可しない。これは絶対のルールである。
- **テストファースト**: 新機能実装やリファクタリングの際は、まずテストを書き、そのテストをパスするコードを実装するアプローチを原則とする。
- **カバレッジは指標であって目的ではない**: テストカバレッジは品質の一つの指標だが、数字だけを追い求めるな。重要なロジック、複雑な条件分岐、境界値などを重点的にテストすること。
- **テストの独立性**: 各テストは他のテストに依存せず、独立して実行可能でなければならない。

## CTOからの最終通告

これらの原則は、単なるガイドラインではない。**プロジェクトの生命線を守るための絶対的な規律**である。
この規律に違反する「独自ムーブ」は、プロジェクト全体を危険に晒す行為とみなし、一切許容しない。
コードを書く前に、必ずこの`CLAUDE.md`を読み込み、原則を遵守せよ。

---

## 運用ガードレール v2025.01（300行/分割リファクタ）

CLAUDE_VERSION: v2025.01

本章は「1ファイル1責任」「300行ルール」を確実に守るための運用規約です。作業前に読み返し、PRで既読と遵守を宣言してください。

### サイズ規約
- ファイル: 目安 250 行 / 上限 300 行
- 型（class/struct/enum/protocol）: 目安 200 行
- 関数: 目安 50 行

上限超過は原則不可。例外を出す場合は「例外運用」に従い、返済計画を PR に記載すること。

### 必読タイミング（チェック欄は PR テンプレで宣言）
- 作業開始前
- 設計変更前（公開 API の追加/変更時）
- PR 作成前（CLAUDE_VERSION を明記）

### PR 運用ルール
- 1PR = 1責務の削減（1つの概念の抽出/分離に集中）
- 差分規模の上限: 最大 1,000 行、最大 10 ファイル
- rename/move とロジック変更を混在させない（レビュー容易化）
- PR テンプレの必須項目を全て埋める（既読チェック/分割計画/ファイル行数表/例外記録）

### スコープ固定（Scope Lock）
- PR 作成時に「対象責務」「含める変更」「含めない変更」を明記し、実装中にスコープを増やさない
- スコープ変更が不可避な場合は、PR本文の「変更概要/分割計画/次の分割候補」を更新し、理由を1行で追記
- コミット分解を厳守（①追加/移動のみ ②呼び出し差し替え ③不要コード削除）。いずれも振る舞い不変の範囲に留める

### レポート整合性（Report Consistency）
- メトリクスは PR ブランチの HEAD で測定（`wc -l`）。他資料の過去数値と矛盾する場合は「測定時点差/先行PRの影響」など簡潔に補足
- PR 本文の「次のアクション」や「残タスク」は、実際の作業結果に合わせて更新。未実施の作業を“済”として記載しない
- 用語の統一（例）
  - Parser = `AITaskSuggestionParser`（現状維持）
  - 変換 = `AITaskConverter`
  - ルーティング = `AIClientRouter`

### 例外運用（JIT 例外）
- 300行超を一時的に許可する場合、PR で以下を明記:
  - 例外の理由（安全上・段階分割上の必要性）
  - 返済期限（原則 1 スプリント以内）
  - 返済タスク（Issue #91 等へのチェックリスト項目追加）
