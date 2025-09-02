# Apply SharedManagerStore in ProjectDetailView

- Area: ProjectDetailView
- Change:
  - Replaced per-view `@StateObject` managers with shared instances from `SharedManagerStore` (`@EnvironmentObject`)
  - Lazy load via `.task {}` and conditionally render PhaseListView only when manager is ready
  - Made AI button safe for optional generator; analysis sheet now guards both required managers
- Benefits:
  - Prevents manager re-instantiation across navigation
  - Stabilizes listener lifecycle and reduces flicker
- Files:
  - iOS/shigodeki/ProjectDetailView.swift
