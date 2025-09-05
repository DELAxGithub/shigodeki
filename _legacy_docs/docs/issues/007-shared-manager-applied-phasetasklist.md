# Apply SharedManagerStore in PhaseTaskListView

- Area: PhaseTaskListView, PhaseListView
- Change:
  - PhaseTaskListView now obtains `TaskListManager` from `SharedManagerStore` via `@EnvironmentObject` and async `getTaskListManager()`
  - Removed per-view instantiation in `PhaseListView` and simplified navigation destination
- Benefits:
  - Prevents per-navigation re-instantiation of `TaskListManager`
  - Reduces listener churn and transient empty states during navigation
- Follow-ups:
  - Migrate `ProjectDetailView` (phaseManager/aiGenerator/familyManager) to use `SharedManagerStore`
  - Audit remaining views (TaskDetailView, FamilyDetailView, etc.)
- Files:
  - iOS/shigodeki/PhaseListView.swift
