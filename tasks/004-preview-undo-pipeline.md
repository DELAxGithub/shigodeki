# Task 004: Preview → Undo Pipeline Completion

## Summary
Deliver the Phase2 draft pipeline so every task entry route hits `TasksPreview`, optimistic saves register Undo handlers, and telemetry proves the flow works.

## Acceptance Criteria
- Given `FeatureFlags.unifiedPreviewEnabled == true`, When a user selects Manual/AI/Photo/Template in `TaskAddModal`, Then `TasksPreview` presents a draft list populated from `TaskDraftSource` for that route before any Firestore write occurs.
- Given the user taps "適用" in the preview, When `DraftSaveFacade` commits, Then the created tasks are marked `.pending`, enqueued via `SyncQueue.enqueue(.confirmPhaseCreate...)`, and `Telemetry.onPreviewAccepted` + `Telemetry.onTaskAdded` fire with payload metadata.
- Given the toast appears, When "Undo" is tapped within 5 seconds, Then the optimistic task is removed locally, a delete op enqueues, and `SyncQueue.cancelConfirm` prevents flicker.
- Given Remote Config toggles `previewAIEnabled` / `previewPhotoEnabled` / `previewTemplateEnabled` individually, When a route is disabled, Then the modal shows 「近日公開」 and blocks navigation.
- Given no network connectivity, When a user accepts the preview, Then tasks remain `.pending` and `SyncQueue` retries with exponential backoff until success (observable via logs/tests).

## Edge Cases / Empty States
- Provide fallback copy when AI/photo providers return empty results: preview should show an informative empty state rather than auto-closing.
- Ensure Undo actions no-op if the task has already been confirmed/deleted server-side.
- Telemetry payloads must redact sensitive text before logging.

## Impact / 主なディレクトリ
- `iOS/shigodeki/Services/DraftPipeline/*`
- `iOS/shigodeki/Utilities/SyncQueue.swift`
- `iOS/shigodeki/Views/TaskAIAssistantView.swift`
- `iOS/shigodeki/Components/TaskAddModal.swift`
- `iOS/shigodeki/Telemetry/*` (if exists)
- Tests: `iOS/shigodekiTests/AIIntegrationTests.swift`, new UITests

## Process
1. Ship preview/undo code paths and supporting tests.
2. Request review emphasizing data integrity and UX (include video of the flow).
3. Address reviewer findings (code or copy) to close the implement→review→修正 loop before merging.
