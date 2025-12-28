# Task 005: Sync Status Badges & Save Guardrails

## Summary
Make pending/conflicted states visible, prevent duplicate submits, and ensure accessibility copy so families trust what happened after pressing “追加”.

## Acceptance Criteria
- Given a task with `syncStatus == .pending`, When it appears in `TaskListDetailView`, Then a badge (e.g., 「同期中」) is rendered next to the title, gated by `FeatureFlags.offlineBadgesEnabled`.
- Given a rejected Firestore write (simulated via emulator), When `SyncQueue` marks the task `.conflicted`, Then the badge shows an error style plus the retry action.
- Given the create/save button is tapped, When the client is waiting for preview acceptance, Then the form controls are disabled until the pending write completes or fails.
- Given VoiceOver is enabled, When focusing the badge/toast, Then localized accessibility labels hint at the state (“同期中、タップで詳細”).
- Given Unit/UI tests run, When pending/conflicted scenarios are simulated, Then assertions confirm badge presence/absence and retry logic (using `UITest` + `Unit test` indicated in docs/navigation-plan-checklist.md:40-47).

## Edge Cases / Empty States
- When `syncStatus` is missing (older documents), default to `.confirmed` without crashing.
- If the retry action is invoked on a task already deleted, dismiss the badge and show a toast instead of throwing.
- Ensure badges do not appear for completed tasks list sections unless status warrants it.

## Impact / 主なディレクトリ
- `iOS/shigodeki/Views/TaskListDetailView.swift`
- `iOS/shigodeki/Components/SyncStatusBadge` (new or existing helper)
- `iOS/shigodeki/Utilities/FeatureFlags.swift`
- Tests under `iOS/shigodekiTests/TagDisplayBugTests.swift` or new suites

## Process
1. Implement UI & logic changes.
2. Seek review focusing on UX/accessibility, capture comments.
3. Fix review findings (e.g., copy tweaks) before landing to satisfy the implementation→review→修正 loop.
