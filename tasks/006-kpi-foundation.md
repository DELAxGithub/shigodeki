# Task 006: KPI & Project Card Foundation

## Summary
Provide the minimum analytics needed for the PoC—cached portfolio metrics and enriched project cards driven by `Project.metrics`, plus graceful loading states.

## Acceptance Criteria
- Given `FeatureFlags.projectCardsSummaryEnabled == true`, When a family opens `ProjectListView`, Then each card shows progress %, remaining tasks, avatar stack, upcoming items, backed by a cached `Project.metrics` struct (no per-row Firestore reads).
- Given the PoC family has multiple projects, When `ProjectPortfolioKPIViewModel` loads, Then portfolio KPIs (overdue count, completion trend, upcoming deadlines) are displayed atop the list with a spinner fallback while fetching.
- Given data is stale or fetch fails, When the user scrolls/pulls to refresh, Then cached metrics invalidate and background refresh jobs rerun without blocking the UI.
- Given tests execute, When metrics services are mocked, Then snapshot/unit tests confirm layout stability for both data and empty states.

## Edge Cases / Empty States
- Handle families with zero projects by showing guidance copy instead of empty graphs.
- For projects lacking assignees/due dates, hide avatar/next-task modules gracefully.
- Ensure caching respects Firestore listener updates (e.g., tasks completed in another session).

## Impact / 主なディレクトリ
- `iOS/shigodeki/Services/KPI/*`
- `iOS/shigodeki/ViewModels/ProjectPortfolioKPIViewModel.swift`
- `iOS/shigodeki/Views/ProjectListView.swift`, `ProjectRowView.swift`
- Tests: snapshot/layout + service unit tests

## Process
1. Build metrics service + UI, including caching logic.
2. Request review (include screenshots of KPI sections) and collect comments.
3. Apply review feedback (code/style) to complete the implement→review→修正 loop.
