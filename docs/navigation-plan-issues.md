# GitHub Issue Drafts — Navigation Plan Alignment

Copy each block into a new GitHub issue when ready. Labels/owners are placeholders.

---

## Issue: Phase 1 – Unified Task Entry & Back Navigation
- **Labels**: `feature`, `navigation`
- **Summary**: Replace scattered AI/Photo/Template triggers with a single `TaskAddModal` entry point and add a persistent “Back to Family” control across the project layer.
- **Acceptance Criteria**:
  1. `CreatePhaseTaskView` launches only `TaskAddModal` (feature-gated) and legacy buttons are hidden when `Features.taskAddModal` is true.
  2. `TaskAddModal` routes to Manual / AI / Photo / Template flows via `TaskAddRoute` enum, each returning to the form.
  3. Project detail and deeper views expose a visible “Family” return action (toolbar button or tab switch) validated by UI test `NavigationTests.testBackToFamilyShortcut`.
  4. Telemetry events fired: `onTaskAddEntryShown`, `onBackToFamilyTapped`.

---

## Issue: Phase 2 – Preview Pipelines & Undo
- **Labels**: `safety`, `ai`
- **Summary**: Funnel AI/photo/template outputs through a standardized preview surface and add undo support after task creation.
- **Acceptance Criteria**:
  1. `TasksPreview` component shows generated items with metadata (title, assignee, due, rationale) before apply.
  2. Manual save path unchanged; AI/photo/template require `Preview → Accept → Save`.
  3. Post-save toast displays with “Undo” (5s). Undo uses `UndoManager` and reverts Firestore writes or queues compensating delete.
  4. Telemetry: `onPreviewAccepted`, `onPreviewShown`, `onTaskAdded`, `onUndo`, `onSyncQueued`, `onSyncSucceeded`, `onSyncFailed` (including payload schema documented).
- **TODOs**:
  - [ ] Add feature flags `undoEnabled`, `offlineBadgesEnabled` with RC/launch-arg overrides.
  - [ ] Extend `Task` model with `syncStatus` and backfill existing tasks to `.confirmed`.
  - [ ] Create `TaskDraft` conversions for manual/AI/photo/template flows; route into `TasksPreview`.
  - [ ] Implement optimistic create pipeline with Undo registration and toast feedback.
  - [ ] Build `SyncQueue` actor (dedupe, exponential backoff, idempotent create/delete API calls).
  - [ ] Surface Pending/Conflicted badge in task rows behind feature flag.
  - [ ] Ensure save buttons disable during in-flight operations to prevent double submits.
  - [ ] Add unit test for SyncQueue retry success and UI tests for preview, undo toast, badge clearance.

---

## Issue: Phase 3 – Family Project Cards Summary
- **Labels**: `ui`, `metrics`
- **Summary**: Enhance `ProjectRowView` with progress, remaining tasks, upcoming items, avatars, and last-updated info powered by cached metrics.
- **Acceptance Criteria**:
  1. Metrics service calculates `Project.metrics` without per-row Firestore calls; cache invalidates on project mutation.
  2. Cards display progress bar, remaining count, next three tasks (title + due), avatar stack of top contributors, relative `lastUpdated`.
  3. Feature flag `Features.projectCardsSummary` controls rollout.
  4. Snapshot tests updated for new layout.

---

## Issue: Phase 4 – KPI Dashboards
- **Labels**: `analytics`, `ui`
- **Summary**: Introduce portfolio-level KPIs on the project landing screen and phase-level KPIs/dependency summary on project detail.
- **Acceptance Criteria**:
  1. `MetricsService` aggregates portfolio KPIs (overdue counts, completion trend, deadline heatmap) asynchronously with caching.
  2. `ProjectListView` renders KPI modules above the list when data available; falls back to spinner/empty states.
  3. `ProjectDetailView` surfaces per-phase completion %, critical blockers, dependency summary cards.
  4. Background refresh jobs keep metrics fresh; instrumentation for load time.

---

## Issue: Phase 5 – Task List Ordering & Offline Badges
- **Labels**: `tasks`, `sync`
- **Summary**: Persist manual ordering of tasks and expose sync status badges for pending/conflicted entries.
- **Acceptance Criteria**:
  1. Drag-reorder updates `Task.orderIndex` via batch write, reflected after reload.
  2. `TaskListDetailView` sorts by `orderIndex`; legacy sort removed.
  3. Badge renders when `Task.syncStatus` is `.pending` or `.conflicted`, with retry action for pending states.
  4. Offline scenarios covered by unit/UI tests.
- **TODOs**:
  - [ ] Add reorder pipeline (view → TaskManager → Firestore explicit array write) and backfill initial `orderIndex` values.
  - [ ] Gate new ordering behavior behind `FeatureFlags.taskOrderIndexEnabled` (or reuse existing flag if decided) with remote override docs.
  - [ ] Update `TaskListDetailView` drag gesture to push optimistic order updates and fall back gracefully on errors.
  - [ ] Expose `SyncStatusBadge` component in task rows when `FeatureFlags.offlineBadgesEnabled` is true.
  - [ ] Provide retry affordance that invokes `SyncQueue.retryPending()` (or equivalent) and logs telemetry `onSyncRetryTapped`.
  - [ ] Tests: unit (order diff computation, retry queue), UI (drag persistence, badge visibility), offline simulation.

---

## Issue: Phase 0 – Feature Flags & Telemetry Baseline
- **Labels**: `infra`, `telemetry`
- **Summary**: Add feature flags, extended models, and baseline telemetry to support staged rollout.
- **Acceptance Criteria**:
  1. Flags (`taskAddModal`, `projectCardsSummary`, `kpiDashboards`, `offlineBadges`, `undo`) accessible via `FeatureToggle` helper with default matrix.
  2. Model fields: `Task.syncStatus`, `Task.orderIndex`, `Project.metrics` struct in shared models, migrations handled.
  3. Telemetry emits events listed in checklist with payload schema documented.
  4. Developer README updated with flag usage and new events.
