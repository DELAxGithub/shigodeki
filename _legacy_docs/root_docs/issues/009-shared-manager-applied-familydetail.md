# Apply SharedManagerStore in FamilyDetailView

- Area: FamilyDetailView
- Change:
  - Replaced per-view `@StateObject` managers with shared instances from `SharedManagerStore` (`AuthenticationManager`, `FamilyManager`, `ProjectManager`)
  - Lazy load via `.task {}` and guarded usages of optionals in UI
  - Applied `LoadingOverlay` using `isLoadingMembers || familyManager?.isLoading`
- Benefits:
  - Prevents manager re-instantiation, reduces UI flicker
  - Safer lifecycle across navigation
- Files:
  - iOS/shigodeki/FamilyDetailView.swift
