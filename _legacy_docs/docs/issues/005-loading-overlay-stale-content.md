# Add loading overlay to keep stale content visible

- Area: Phase/Task list and detail screens
- Problem: While loading, UI either shows a bottom spinner or temporarily looks empty, which feels jumpy.
- Fix (implemented):
  - Introduced `Components/LoadingOverlay.swift` to overlay a spinner while keeping existing content visible (stale-while-revalidate UX)
  - Applied to:
    - `PhaseListView` (phases): `.loadingOverlay(phaseManager.isLoading, message: "フェーズを更新中...")`
    - `PhaseTaskListView` (lists): `.loadingOverlay(taskListManager.isLoading, message: "タスクリストを更新中...")`
    - `TaskListDetailView` (tasks): `.loadingOverlay(enhancedTaskManager.isLoading, message: "タスクを更新中...")`
- Acceptance:
  - No content collapse during refresh; spinner overlays
  - Existing content remains visible until new snapshot arrives
- Files:
  - iOS/shigodeki/Components/LoadingOverlay.swift
  - iOS/shigodeki/PhaseListView.swift
