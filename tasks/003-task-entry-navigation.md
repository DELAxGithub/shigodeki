# Task 003: Unified Task Entry & Back Navigation

## Summary
Ship the Phase1 UX: every task addition funnels through `TaskAddModal`, legacy inline buttons disappear when the flag is on, and a persistent "Familyに戻る" affordance prevents navigation dead-ends.

## Acceptance Criteria
- Given `FeatureFlags.taskAddModalEnabled == true`, When a user taps `＋` in `CreatePhaseTaskView`/`TaskListDetailView`/Dashboard quick actions, Then only `TaskAddModal` appears and manual/AI/Photo/Template buttons within the old forms are hidden or disabled.
- Given the same flag is false, When navigated, Then the legacy inline controls reappear (backward compatibility is preserved).
- Given any project-level screen, When the new toolbar/button is tapped, Then the user returns to the active `FamilyDetailView` without relying on the system back gesture.
- Given UI test `NavigationFlowTests` (or a new UITest), When it performs Family → Project → Task detail → Back, Then it asserts the new control exists and lands back on family context.
- Given telemetry is enabled, When `TaskAddModal` is shown and an option is tapped, Then `Telemetry.onTaskAddOptionChosen` is fired with the selected route.

## Edge Cases / Empty States
- Handle accounts with a single family by defaulting to the only family without showing picker dialogs.
- Ensure VoiceOver labels exist for the new "戻る" button and the modal entries (Japanese + English).
- When remote config fails to fetch, fall back to local defaults to avoid blocking task creation.

## Impact / 主なディレクトリ
- `iOS/shigodeki/Views/CreatePhaseTaskView.swift`
- `iOS/shigodeki/Views/TaskListDetailView.swift`
- `iOS/shigodeki/Components/TaskAddModal.swift`
- `iOS/shigodeki/ViewModels/FamilyViewModel.swift`
- UI tests under `iOS/shigodekiTests/newtips_validation/NavigationFlowTests.swift`

## Process
1. Implement UI/flag changes with feature toggles.
2. Send for design/UX-focused review, capturing at least one round of comments.
3. Update the code per review (include screenshot diffs) to complete the implement→review→修正 loop.
