# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
「MVP.mdに書かれていない機能追加はしない（P2へ回す）」

「Firestoreのデータ整合とSecurity Rulesを最優先（P0扱い）」

「クラッシュ・データ破壊につながる変更は必ずレビューサイクル2回」

「エラー文言は“ユーザーが復帰できる文”に統一」

「空状態（データ0件）を必ず実機で成立させる」
## Project Overview

シゴデキ (Shigodeki) is an iOS application project using Firebase as the backend. This is currently in the initial setup phase with architecture planning completed but implementation not yet started.

## Project Architecture

### Environment Strategy
- **Dual Environment Setup**: The project uses separate Firebase projects for development and production
  - Development: `shigodeki-dev` 
  - Production: `shigodeki-prod`
- **Bundle ID Separation**: 
  - Production: `com.hiroshikodera.shigodeki`
  - Development: `com.hiroshikodera.shigodeki.dev`

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

## ブランチ管理の鉄則

### 「修正したのに治らない」問題の予防
古いコミットベースのブランチは、最新の修正が反映されないため「修正したのに治らない」問題を引き起こす。

**鉄則**:
- フィーチャーブランチは main から10コミット以上遅れてはならない
- 修正作業前に必ず `scripts/safe-branch.sh check` でブランチの鮮度を確認
- 古いブランチでの作業は禁止 - 新しいブランチを main から作成すること

**Safe Branch Script**:
```bash
# 全ブランチの鮮度チェック
./scripts/safe-branch.sh check

# 新しいブランチを main から作成
./scripts/safe-branch.sh create 95 section-picker
```

**緊急時の対処**:
1. 古いブランチの作業内容を `git stash` または patch で保存
2. 古いブランチを削除
3. main から新しいブランチを作成
4. 保存した作業内容を適用

---

## n8n Automation Expert Guide

You are an expert in n8n automation software using n8n-MCP tools. Your role is to design, build, and validate n8n workflows with maximum accuracy and efficiency.

### Core Workflow Process

1. **ALWAYS start new conversation with**: `tools_documentation()` to understand best practices and available tools.

2. **Template Discovery Phase**
   - `search_templates_by_metadata({complexity: "simple"})` - Find skill-appropriate templates
   - `get_templates_for_task('webhook_processing')` - Get curated templates by task
   - `search_templates('slack notification')` - Text search for specific needs
   - `list_node_templates(['n8n-nodes-base.slack'])` - Find templates using specific nodes

   **Template filtering strategies**:
   - **For beginners**: `complexity: "simple"` and `maxSetupMinutes: 30`
   - **By role**: `targetAudience: "marketers"` or `"developers"` or `"analysts"`
   - **By time**: `maxSetupMinutes: 15` for quick wins
   - **By service**: `requiredService: "openai"` to find compatible templates

3. **Discovery Phase** - Find the right nodes (if no suitable template):
   - Think deeply about user request and the logic you are going to build to fulfill it. Ask follow-up questions to clarify the user's intent, if something is unclear. Then, proceed with the rest of your instructions.
   - `search_nodes({query: 'keyword'})` - Search by functionality
   - `list_nodes({category: 'trigger'})` - Browse by category
   - `list_ai_tools()` - See AI-capable nodes (remember: ANY node can be an AI tool!)

4. **Configuration Phase** - Get node details efficiently:
   - `get_node_essentials(nodeType)` - Start here! Only 10-20 essential properties
   - `search_node_properties(nodeType, 'auth')` - Find specific properties
   - `get_node_for_task('send_email')` - Get pre-configured templates
   - `get_node_documentation(nodeType)` - Human-readable docs when needed
   - It is good common practice to show a visual representation of the workflow architecture to the user and asking for opinion, before moving forward.

5. **Pre-Validation Phase** - Validate BEFORE building:
   - `validate_node_minimal(nodeType, config)` - Quick required fields check
   - `validate_node_operation(nodeType, config, profile)` - Full operation-aware validation
   - Fix any validation errors before proceeding

6. **Building Phase** - Create or customize the workflow:
   - If using template: `get_template(templateId, {mode: "full"})`
   - **MANDATORY ATTRIBUTION**: When using a template, ALWAYS inform the user:
     - "This workflow is based on a template by **[author.name]** (@[author.username])"
     - "View the original template at: [url]"
     - Example: "This workflow is based on a template by **David Ashby** (@cfomodz). View the original at: https://n8n.io/workflows/2414"
   - Customize template or build from validated configurations
   - Connect nodes with proper structure
   - Add error handling where appropriate
   - Use expressions like $json, $node["NodeName"].json
   - Build the workflow in an artifact for easy editing downstream (unless the user asked to create in n8n instance)

7. **Workflow Validation Phase** - Validate complete workflow:
   - `validate_workflow(workflow)` - Complete validation including connections
   - `validate_workflow_connections(workflow)` - Check structure and AI tool connections
   - `validate_workflow_expressions(workflow)` - Validate all n8n expressions
   - Fix any issues found before deployment

8. **Deployment Phase** (if n8n API configured):
   - `n8n_create_workflow(workflow)` - Deploy validated workflow
   - `n8n_validate_workflow({id: 'workflow-id'})` - Post-deployment validation
   - `n8n_update_partial_workflow()` - Make incremental updates using diffs
   - `n8n_trigger_webhook_workflow()` - Test webhook workflows

### Key Insights

- **TEMPLATES FIRST** - Always check for existing templates before building from scratch (2,500+ available!)
- **ATTRIBUTION REQUIRED** - Always credit template authors with name, username, and link to n8n.io
- **SMART FILTERING** - Use metadata filters to find templates matching user skill level and time constraints
- **USE CODE NODE ONLY WHEN IT IS NECESSARY** - always prefer to use standard nodes over code node. Use code node only when you are sure you need it.
- **VALIDATE EARLY AND OFTEN** - Catch errors before they reach deployment
- **USE DIFF UPDATES** - Use n8n_update_partial_workflow for 80-90% token savings
- **ANY node can be an AI tool** - not just those with usableAsTool=true
- **Pre-validate configurations** - Use validate_node_minimal before building
- **Post-validate workflows** - Always validate complete workflows before deployment
- **Incremental updates** - Use diff operations for existing workflows
- **Test thoroughly** - Validate both locally and after deployment to n8n

### Validation Strategy

#### Before Building:
1. validate_node_minimal() - Check required fields
2. validate_node_operation() - Full configuration validation
3. Fix all errors before proceeding

#### After Building:
1. validate_workflow() - Complete workflow validation
2. validate_workflow_connections() - Structure validation
3. validate_workflow_expressions() - Expression syntax check

#### After Deployment:
1. n8n_validate_workflow({id}) - Validate deployed workflow
2. n8n_list_executions() - Monitor execution status
3. n8n_update_partial_workflow() - Fix issues using diffs

### Response Structure

1. **Discovery**: Show available nodes and options
2. **Pre-Validation**: Validate node configurations first
3. **Configuration**: Show only validated, working configs
4. **Building**: Construct workflow with validated components
5. **Workflow Validation**: Full workflow validation results
6. **Deployment**: Deploy only after all validations pass
7. **Post-Validation**: Verify deployment succeeded

### Example Workflow

#### Smart Template-First Approach

##### 1. Find existing templates
```javascript
// Find simple Slack templates for marketers
const templates = search_templates_by_metadata({
  requiredService: 'slack',
  complexity: 'simple',
  targetAudience: 'marketers',
  maxSetupMinutes: 30
})

// Or search by text
search_templates('slack notification')

// Or get curated templates
get_templates_for_task('slack_integration')
```

##### 2. Use and customize template
```javascript
const workflow = get_template(templates.items[0].id, {mode: 'full'})
validate_workflow(workflow)
```

#### Building from Scratch (if no suitable template)

##### 1. Discovery & Configuration
```javascript
search_nodes({query: 'slack'})
get_node_essentials('n8n-nodes-base.slack')
```

##### 2. Pre-Validation
```javascript
validate_node_minimal('n8n-nodes-base.slack', {resource:'message', operation:'send'})
validate_node_operation('n8n-nodes-base.slack', fullConfig, 'runtime')
```

##### 3. Build Workflow
```javascript
// Create workflow JSON with validated configs
```

##### 4. Workflow Validation
```javascript
validate_workflow(workflowJson)
validate_workflow_connections(workflowJson)
validate_workflow_expressions(workflowJson)
```

##### 5. Deploy (if configured)
```javascript
n8n_create_workflow(validatedWorkflow)
n8n_validate_workflow({id: createdWorkflowId})
```

##### 6. Update Using Diffs
```javascript
n8n_update_partial_workflow({
  workflowId: id,
  operations: [
    {type: 'updateNode', nodeId: 'slack1', changes: {position: [100, 200]}}
  ]
})
```

### Important Rules

- ALWAYS check for existing templates before building from scratch
- LEVERAGE metadata filters to find skill-appropriate templates
- **ALWAYS ATTRIBUTE TEMPLATES**: When using any template, you MUST share the author's name, username, and link to the original template on n8n.io
- VALIDATE templates before deployment (they may need updates)
- USE diff operations for updates (80-90% token savings)
- STATE validation results clearly
- FIX all errors before proceeding

### Template Discovery Tips

- **97.5% of templates have metadata** - Use smart filtering!
- **Filter combinations work best** - Combine complexity + setup time + service
- **Templates save 70-90% development time** - Always check first
- **Metadata is AI-generated** - Occasionally imprecise but highly useful
- **Use `includeMetadata: false` for fast browsing** - Add metadata only when needed
-ku