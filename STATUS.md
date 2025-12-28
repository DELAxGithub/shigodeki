# STATUS

## 現状把握サマリー
- **認証とセッション管理**: `iOS/shigodeki/Managers/AuthenticationManager.swift` と `iOS/shigodeki/Views/LoginView.swift` で Apple/デモサインインを含むログイン導線が完成しており、`MainTabView` 経由でホーム/プロジェクト/チーム/設定タブへ遷移できる。
- **家族・プロジェクト管理のコア**: `iOS/shigodeki/Services/UnifiedInvitationService.swift` が正規化済みコードを生成・検証し、`FamilyView`/`FamilyDetailView`/`ProjectListView` によってメンバー参照やプロジェクト CRUD、フェーズ/タスク CRUD (`TaskListDetailView.swift`) が動作中。
- **AI / テンプレ導線**: `iOS/shigodeki/Views/TaskAIAssistantView.swift` と `iOS/shigodeki/Components/TaskAddModal.swift` で手動・AI・写真・テンプレのフローを切り替える UI が整備され、Claude/Gemini/OpenAI クライアント (`iOS/shigodeki/AI/*`) が存在。
- **テンプレ/課金ガード**: `TemplateLibraryView.swift` や `TemplatePreviewView.swift` が FeatureFlag に連動して課金 UI をマスクしており、PoC では無償テンプレを選択可能。
- **TidyPlanKit 連携下地**: `iOS/shigodeki/Components/PhotoTaskSuggestionSection.swift`・`iOS/shigodeki/Views/TaskAIAssistantView.swift` が `TidyPlanKit` のモデル (`iOS/shigodeki/Services/TidyPlan/Models.swift`) を参照し、写真→タスク生成の UI ステージングを完了している。

## 未実装 or 改善が必要な領域
- **Phase 0/1/2 のチェックリスト未完了**: `docs/navigation-plan-checklist.md` では TaskAddModal/preview/undo/sync queue/KPI など 46 項目が未チェックで、新規導線が PoC で有効化されていない。
- **Telemetry 収集不足**: `FeatureFlags` / `Telemetry` は存在するが、`docs/navigation-plan-checklist.md:7,28,33,38` が示すイベント群が未送信のため、家族 PoC の観測が困難。
- **Preview → Undo パイプライン**: `TaskAddModal` は用意されているが `FeatureFlags.unifiedPreviewEnabled` がデフォルト false であり、`DraftSaveFacade`/`SyncQueue` 連携もフラグ未設定のまま。
- **KPI/ダッシュボード**: `ProjectPortfolioKPIViewModel.swift` は存在するが `FeatureFlags.kpiDashboardsEnabled` が既定で false、`docs/navigation-plan-checklist.md:56-58` にある集計/UI/ローディング処理も未完成。
- **タスク並び順とバッジ**: `Task.orderIndex`/`syncStatus` フィールドは `iOS/shigodeki/Models/Task.swift` にあるものの、`docs/navigation-plan-checklist.md:61-65` の永続化・UI・テストが未着手。

## リスク / 壊れやすい箇所
- **セキュリティルールの広すぎる許可**: `iOS/firestore.rules:70-138` で families/projects のネスト配下は「認証済みなら誰でも read/write」になっており、PoC でも他家族のデータ読み書きが可能。
- **旧 `invitations` コレクション開放**: 同ルールの `match /invitations/{invitationId}` が引き続き誰でも read/write 可能でレガシーデータが露出。
- **手動検証の未完了**: `docs/validation-test.md` の完了条件に manual validation チェックが残っており、先日の招待バグ修正が実環境で未確認。
- **テストカバレッジ不足**: `iOS/shigodekiTests/Integration/*.swift.disabled` や `Memory/*.swift.disabled` など重要テストが無効化されており、回帰を検知できない。
- **リリース/配信欠如**: README.md(379,395,503 行) にある通り TestFlight 配信が未整備で、家族 PoC へ最新ビルドを届ける経路がない。

## Issue Backlog (全51件)
| # | P | 項目 | 理由/根拠 |
|---|---|------|-----------|
| 1 | P0 | Phase0: Remote feature flags (`taskAddModal`/`projectCardsSummary`/`kpiDashboards`/`offlineBadges`/`undo`) | 未チェック in docs/navigation-plan-checklist.md:6。フラグが無いと PoC で導線を安全に切り替えられない。|
| 2 | P1 | Phase0: Emit baseline telemetry (`onTaskAdded` 等) | docs/navigation-plan-checklist.md:7。主要操作を観測できず実証結果を測れない。|
| 3 | P1 | Phase0: Document/execute overall model extensions | docs/navigation-plan-checklist.md:8。新フィールド導入方針が未合意で migrations が進められない。|
| 4 | P0 | Phase0: Define `Task.syncStatus` schema | docs/navigation-plan-checklist.md:9。同期状態を記録できず Undo/バッジ設計が止まる。|
| 5 | P1 | Phase0: Define `Project.metrics` container | docs/navigation-plan-checklist.md:10。家族カード/KPI に必要な値がモデルに存在しない。|
| 6 | P1 | Phase0: Persist `Task.orderIndex` | docs/navigation-plan-checklist.md:11。Drag reorder を反映できない。|
| 7 | P0 | Phase1: Introduce unified `TaskAddModal` entry from `CreatePhaseTaskView` | docs/navigation-plan-checklist.md:14。各導線が乱立したまま。|
| 8 | P1 | Phase1: Remove or flag-gate legacy inline AI/Photo/Template buttons | docs/navigation-plan-checklist.md:15。旧 UI が残りユーザー混乱。|
| 9 | P0 | Phase1: Persistent “Back to Family” control | docs/navigation-plan-checklist.md:16。PoC の家族間移動が迷子になる。|
|10 | P1 | Phase1: UI test for Family→Project→Task→Back flow | docs/navigation-plan-checklist.md:17。新導線の回帰を検知できない。|
|11 | P0 | Phase2: Feature flag override plumbing | docs/navigation-plan-checklist.md:20。Undo/バッジ用フラグが RemoteConfig から切り替えられない。|
|12 | P0 | Phase2: Add `undoEnabled` & `offlineBadgesEnabled` flags | docs/navigation-plan-checklist.md:21。該当機能を PoC ビルドで制御不可。|
|13 | P1 | Phase2: Model update coordination | docs/navigation-plan-checklist.md:22。新フィールド導入に伴う互換性テストが不足。|
|14 | P0 | Phase2: Extend `Task` struct/class with syncStatus states | docs/navigation-plan-checklist.md:23。アプリ層に状態が無いとオフライン UX を示せない。|
|15 | P0 | Phase2: Ensure Task persistence/backfill defaults `.confirmed` | docs/navigation-plan-checklist.md:24。旧データが `.pending` のまま残るリスク。|
|16 | P0 | Phase2: Implement preview funnel shell | docs/navigation-plan-checklist.md:25。AI/写真 ルートが即保存のまま。|
|17 | P0 | Phase2: Route manual/AI/photo/template flows to `TasksPreview` | docs/navigation-plan-checklist.md:26。Preview 画面を通らず Undo 機構と連動できない。|
|18 | P0 | Phase2: Populate `TaskDraft` from each source | docs/navigation-plan-checklist.md:27。下書きデータが欠けてプレビューに表示できない。|
|19 | P1 | Phase2: Fire telemetry `onPreviewShown` | docs/navigation-plan-checklist.md:28。プレビュー利用率を測れない。|
|20 | P0 | Phase2: Accept→optimistic save pipeline shell | docs/navigation-plan-checklist.md:29。トースト/Undo への入り口が無い。|
|21 | P0 | Phase2: Convert accepted drafts into `.pending` optimistic tasks | docs/navigation-plan-checklist.md:30。Undo/SyncQueue が働かない。|
|22 | P0 | Phase2: Register UndoManager + compensating delete | docs/navigation-plan-checklist.md:31。ユーザーが戻せず PoC の信頼性が下がる。|
|23 | P1 | Phase2: Show toast via `ToastCenter` with undo action | docs/navigation-plan-checklist.md:32。Undo 動線の可視化が無い。|
|24 | P1 | Phase2: Emit telemetry `onPreviewAccepted`/`onTaskAdded` | docs/navigation-plan-checklist.md:33。作成成功率を把握できない。|
|25 | P0 | Phase2: SyncQueue foundation | docs/navigation-plan-checklist.md:34。非同期確定処理が存在しない。|
|26 | P0 | Phase2: Implement `SyncQueue` actor/backoff | docs/navigation-plan-checklist.md:35。`iOS/shigodeki/Utilities/SyncQueue.swift` には雛形があるが未起動。|
|27 | P0 | Phase2: Enqueue create/delete ops on accept/undo | docs/navigation-plan-checklist.md:36。Undo が Firestore に反映されない。|
|28 | P0 | Phase2: Mark tasks `.confirmed` / `.conflicted` | docs/navigation-plan-checklist.md:37。同期完了が UI に戻らず永遠に pending。|
|29 | P1 | Phase2: Emit telemetry for SyncQueue (`onSyncQueued/Succeeded/Failed`) | docs/navigation-plan-checklist.md:38。同期失敗率を監視できない。|
|30 | P1 | Phase2: UI polish bucket | docs/navigation-plan-checklist.md:39。手動保存ボタンやアクセシビリティ未調整。|
|31 | P1 | Phase2: Pending/Conflicted badge component | docs/navigation-plan-checklist.md:40。家族が状態を識別できない。|
|32 | P1 | Phase2: Disable save button during inflight create | docs/navigation-plan-checklist.md:41。二重投稿を防げない。|
|33 | P2 | Phase2: Accessibility strings for preview/toast/badges | docs/navigation-plan-checklist.md:42。VoiceOver 品質が保証されない。|
|34 | P1 | Phase2: Testing umbrella | docs/navigation-plan-checklist.md:43。新基盤の自動テストが不足。|
|35 | P1 | Phase2: UITest for preview gating per route | docs/navigation-plan-checklist.md:44。導線別プレビューを検証できない。|
|36 | P1 | Phase2: UITest for undo toast & removal | docs/navigation-plan-checklist.md:45。Undo 成否を確認できない。|
|37 | P1 | Phase2: Unit test for SyncQueue retries | docs/navigation-plan-checklist.md:46。バックオフや pending 解除を保証できない。|
|38 | P2 | Phase2: UITest for pending badge clearance | docs/navigation-plan-checklist.md:47。バッジの見え方を継続確認できない。|
|39 | P1 | Phase4: Portfolio metrics service feeding `ProjectListView` | docs/navigation-plan-checklist.md:56。家族全体 KPI を表示できない。|
|40 | P1 | Phase4: Project detail KPI/dependency widgets | docs/navigation-plan-checklist.md:57。Phase 状況の可視化が不足。|
|41 | P2 | Phase4: Loading states & background refresh | docs/navigation-plan-checklist.md:58。KPI 取得中が空白のまま。|
|42 | P1 | Phase5: Persist drag-reorder via explicit array write | docs/navigation-plan-checklist.md:61。順序が Firestore に残らない。|
|43 | P1 | Phase5: Sort & gestures respect `orderIndex` behind flag | docs/navigation-plan-checklist.md:62。表示順が毎回ズレる。|
|44 | P1 | Phase5: Display sync status badge (`Task.syncStatus != .confirmed`) | docs/navigation-plan-checklist.md:63。家族が同期状況を認識できない。|
|45 | P1 | Phase5: Retry affordance for pending tasks | docs/navigation-plan-checklist.md:64。保留タスクを再送できない。|
|46 | P1 | Phase5: Tests for reorder/badges/pending retry/offline | docs/navigation-plan-checklist.md:65。新基盤の QA が不足。|
|47 | P0 | Firestore nested rules allow any authed read/write | iOS/firestore.rules:70-138 で `{document=**}` を全面許可し、他家族データ流出リスク。|
|48 | P1 | Legacy `/invitations` path still world-writable | iOS/firestore.rules:96-105 に TODO が残り、不要なコレクションが公開されたまま。|
|49 | P0 | Invitation fix manual validation pending | docs/validation-test.md:34-45 が未完了チェックで、本番 join フローの再現確認がされていない。|
|50 | P1 | Disabled integration/memory tests | iOS/shigodekiTests/*/*.swift.disabled が多数残り、CI がクリティカルパスを検査できない。|
|51 | P1 | TestFlight distribution missing | README.md:379,395,503 が「TestFlight未配信」のままで PoC 端末へ deploy 不能。|
