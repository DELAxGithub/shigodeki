# 開発方針とプロジェクト原則

シゴデキプロジェクトの開発における基本方針と原則を説明します。

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