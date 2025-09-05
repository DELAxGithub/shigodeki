# Audit @StateObject / @ObservedObject usage

- Area: Major screens (PhaseList/TaskList/TaskDetail etc.)
- Problem: Managers may be re-created when they should be long-lived, causing state reset and temporary empties.
- Proposed (next):
  - Ensure managers created by a view are `@StateObject`, and children receive them as `@ObservedObject` or via `@EnvironmentObject` from an AppStore.
  - Consider introducing `AppStore` and providing managers app-wide.
- Acceptance:
  - No unnecessary manager re-instantiation across navigation
  - Listener and state continuity across views
- Files (to audit):
  - iOS/shigodeki/PhaseListView.swift
  - iOS/shigodeki/TaskListMainView.swift
  - iOS/shigodeki/TaskDetailView.swift
  - iOS/shigodeki/FamilyDetailView.swift
  - iOS/shigodeki/ProjectListView.swift
