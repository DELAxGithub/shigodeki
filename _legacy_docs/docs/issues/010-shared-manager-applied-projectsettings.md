# Apply SharedManagerStore in ProjectSettingsView

- Area: ProjectSettingsView
- Change:
  - Replaced `@StateObject` AuthenticationManager/FamilyManager with shared instances
  - Load families via shared manager on `.task {}`
  - Made invite creation robust to missing auth state
- Benefits:
  - Consistent manager lifecycle, fewer transient empty states
- Files:
  - iOS/shigodeki/ProjectSettingsView.swift
