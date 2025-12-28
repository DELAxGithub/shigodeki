# Task 007: Task Ordering & Pending Retry Flow

## Summary
Persist manual order, surface retries, and make drag/drop deterministic so PoC participants can curate their phase plans without losing state.

## Acceptance Criteria
- Given `FeatureFlags.taskOrderIndexEnabled == true`, When a user drags tasks within a phase/list, Then the client computes a new explicit `orderIndex` array and writes it in a single batch/transaction; reloading shows the same order.
- Given older tasks lack `orderIndex`, When they are loaded, Then a migration/backfill assigns sequential indexes without disturbing completion state.
- Given a task shows `.pending` with a retry button, When the user taps retry, Then `SyncQueue.enqueue(.confirmPhaseCreate...)` or `.deletePhaseTask` reruns with telemetry `onSyncRetryTapped`.
- Given UI/Unit tests run, When reorder/undo/retry flows are exercised, Then assertions verify Firestore writes happen exactly once and badges clear after confirmation (covering docs/navigation-plan-checklist.md:61-65).

## Edge Cases / Empty States
- Handle simultaneous drag operations from multiple devices by reconciling order indexes via timestamp or last-writer-wins strategy.
- Make sure completed tasks maintain their order relative to incomplete ones per existing UX conventions.
- Provide copy for retry failures (e.g., when offline) so the user knows why the state persisted.

## Impact / 主なディレクトリ
- `iOS/shigodeki/Managers/TaskOrderingManager.swift`
- `iOS/shigodeki/Services/TaskCRUDService.swift`
- `iOS/shigodeki/Views/PhaseTaskListView.swift`
- Tests: new drag/retry UITests + unit coverage for diff computation

## Process
1. Land ordering/retry code with tests.
2. Request review targeting data integrity (double-check batch writes).
3. Implement reviewer feedback to close the implement→review→修正 loop.
