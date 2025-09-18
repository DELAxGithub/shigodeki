# Shigodeki Navigation Alignment Checklist

Derived from `shigodeki-navigation-plan.puml` (revised). Tracks the delta between current implementation and target experience.

## Phase 0 — Foundation
- [ ] Add feature flags: `Features.taskAddModal`, `projectCardsSummary`, `kpiDashboards`, `offlineBadges`, `undo` (toggleable via remote config or build settings)
- [ ] Emit baseline telemetry events: `onTaskAdded`, `onUndo`, `onPreviewAccepted`, `onBackToFamilyTapped`
- [ ] Extend models:
  - [ ] `Task.syncStatus: pending | confirmed | conflicted`
  - [ ] `Project.metrics` container (progress, remainingCount, nextThree, lastUpdated, topContributors)
  - [ ] `Task.orderIndex` persisted for manual ordering

## Phase 1 — “迷わない” Entry Points
- [ ] Introduce `TaskAddModal` (single sheet) launched from `CreatePhaseTaskView`
- [ ] Remove / flag-gate legacy inline AI・Photo・Template buttons
- [ ] Add persistent “Back to Family” control in project layer (toolbar or tab switch)
- [ ] Add UI test: Family → Project → Task detail → back via new control

## Phase 2 — Preview + Undo Safety Nets
- [ ] Feature flags
  - [ ] Add `undoEnabled` and `offlineBadgesEnabled` flags with RC/launch-arg overrides
- [ ] Model updates
  - [ ] Extend `Task` with `syncStatus: .pending/.confirmed/.conflicted`
  - [ ] Ensure Task persistence/backfill defaults to `.confirmed`
- [ ] Preview funnel
  - [ ] Route manual, AI, photo, template flows to `TasksPreview`
  - [ ] Populate `TaskDraft` from each source (stub AI/photo/template if needed)
  - [ ] Fire telemetry `onPreviewShown`
- [ ] Accept → optimistic save
  - [ ] Convert accepted drafts into optimistic tasks (`.pending`)
  - [ ] Register `UndoManager` action (local delete + compensating sync op)
  - [ ] Show toast via `ToastCenter` with undo callback
  - [ ] Telemetry `onPreviewAccepted`, `onTaskAdded`
- [ ] Sync queue
  - [ ] Implement `SyncQueue` actor with exponential backoff & dedupe
  - [ ] Enqueue create/delete ops on accept/undo
  - [ ] Mark tasks `.confirmed` on success; `.conflicted` on server reject
  - [ ] Telemetry `onSyncQueued`, `onSyncSucceeded`, `onSyncFailed`
- [ ] UI polish
  - [ ] Pending/Conflicted badge component behind `offlineBadgesEnabled`
  - [ ] Disable save button during in-flight create
  - [ ] Accessibility strings for preview, toast, badges
- [ ] Tests
  - [ ] UITest: preview shows before save for each route
  - [ ] UITest: undo toast appears & undo removes optimistic task
  - [ ] Unit test: SyncQueue retries with backoff and clears `.pending`
  - [ ] UITest: pending badge visible until mock sync ack


## Phase 3 — Family Project Cards
- [x] Compute & cache `Project.metrics` via service (no N+1 queries)
- [x] Render progress bar + remaining count + next three tasks + avatar stack + relative `lastUpdated`
- [x] Gate behind `Features.projectCardsSummary`

## Phase 4 — KPI Dashboards
- [ ] Portfolio metrics service feeding `ProjectListView` (heatmap, overdue counts, completion trend)
- [ ] Project detail widgets: per-phase KPIs, dependency summary, critical blockers list
- [ ] Loading states and background refresh stitched into SharedManagerStore

## Phase 5 — Task List Enhancements
- [ ] Persist drag-reorder to `Task.orderIndex` (explicit array write + migration/backfill of existing tasks)
- [ ] Update task list sort + drag gestures to respect `orderIndex` behind a rollout flag
- [ ] Display sync status badge when `Task.syncStatus != confirmed` (gated by `Features.offlineBadgesEnabled`)
- [ ] Surface retry affordance for pending tasks (ties into `SyncQueue` diagnostics)
- [ ] Tests: reorder persistence round-trip, badge visibility, pending retry happy path, offline regression

### Rollout Gates
1. Phase 1 completion → ship new entry/back flows behind flag
2. Phase 2 completion → enable preview+undo for beta
3. Phase 3 completion → promote enhanced family cards
4. Phase 4 completion → public KPI dashboards
