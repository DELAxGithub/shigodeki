# Implementation Plan: Navigation Workspace Refresh

## Milestones
1. **Scaffolding & Data Services**
   - Add `DashboardViewModel` + supporting services (`TaskAssignmentService`, `DraftQueueService` wrappers) in `SharedManagerStore`.
   - Expose lightweight async APIs to fetch assigned tasks and pending drafts without duplicating listeners.
2. **Dashboard UI**
   - Create `DashboardView` with reusable `DashboardCard` components.
   - Wire navigation deep links into existing phase/task detail views.
   - Implement loading/empty states and feature-flag gating.
3. **Tab & FAB Refresh**
   - Swap `HomeHubView` for `DashboardView` in `MainTabView`.
   - Add floating action button (or toolbar button fallback on iPad) invoking `TaskAddModal`.
   - Ensure animation/performance remain stable (reference IntegratedPerformanceMonitor logs).
4. **Team Badge & Project Cleanup**
   - Extend `FamilyViewModel` with pending invite signal; apply `.badge` to the tab item.
   - Remove redundant shortcuts from `ProjectListView` so it focuses on structural editing.
5. **Docs & QA**
   - Update `docs/testflight-beta-manual.md` & `.puml` to reflect new navigation labels.
   - Add TestFlight checklist items verifying dashboard cards and badges.
   - Perform smoke tests on iOS 15/17 devices focusing on login, task review, AI preview, and invite flows.

## Dependencies
- Existing feature flags for preview/AI must remain functional; no new remote config required.
- `SharedManagerStore` must expose current user ID and cached task data.
- Requires coordination with documentation to update beta manual immediately before share.

## Rollout Strategy
- Ship behind a new flag `FeatureFlags.dashboardRefreshEnabled` (default `false`).
- Internal TestFlight build toggles flag on for validation.
- Gradual rollout: enable for beta cohort, gather feedback, then flip flag for production once stable.

## Validation
- Manual checklist covering:
  1. Dashboard cards populate with existing data (assigned tasks, AI drafts).
  2. Tapping cards routes to correct detail view and retains state.
  3. Floating action button opens TaskAddModal.
  4. Project tab still supports create/edit flows without duplicates.
  5. Team tab badge appears when pending invites exist and clears after viewing.
- Use existing perf runbook to spot regressions in listener counts or memory usage.
重複購読の回避
Dashboard→詳細へ遷移時、既存の SharedManagerStore のキャッシュを必ず使う（View側で新リスナーを貼らない）。
→ 測定：遷移前後でリスナー数が増えないこと（perf runbookに追加）。

カード単位のスロットル
同時に3カード hydrate するとき、async let＋coalesce(300–500ms) を DashboardViewModel に。フィルタ変更でも再計算が爆発しないように。

空/多件時の体感

Empty stateは2タップ以内の提案（例：AIで下書き作成 / テンプレ導入）をCTAで配置。

多件（100件超）なら**My Tasksは上位N（例：20）＋“すべて表示”**に。

FABの衝突
iPad/横向きやキーボード接続時はツールバーにフォールバック（既に記載の方針でOK。実装時に条件分岐を忘れずに）。

アクセシビリティ
カードはボタン役割＋accessibilityLabelで「カード名＋件数＋最初の1件」を読み上げ。Dynamic Typeで折返しが崩れないかをQA項目に。

Flags連動の可視性
previewAIEnabled=false の時はAIカード自体を隠す／もしくは「AIはβ機能です」ティップに。中途半端に空カードを出さない。

🧪 追加の受け入れチェック（5分で回せる）

リスナー数：Dashboard表示→カードタップ→戻るで増えていない。

p95：Dashboard初回描画<300ms、スクロールp95<16ms（既存ランブックの指標）。

復帰：バックグラウンド復帰時、3カードすべて同時に再読込しない（スロットルが効く）。

Deep Link：通知/URLで直接フェーズへ→戻るとDashboardに正しく帰還。

QAマニュアル整合：docs/testflight-beta-manual.md のスクショとラベルが新UIに一致。

ロールアウト順（無難）

dashboardRefreshEnabled=false のまま内部で動作確認

小規模βで true（テレメトリ：カード表示率/タップ率/滞在時間）

KPIと合わせて段階的に本番ON

結論：この設計で進行OK。上の“重複購読回避・スロットル・A11y”の3点だけ実装時に意識しておけば、体感と安定性が両立します。