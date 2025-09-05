# Follow-up: expand SharedManagerStore wiring across views

- Area: Views still creating managers with `@StateObject` directly
- Problem: Duplicate manager instances per screen can reset state and listeners on navigation
- Proposed next steps:
  - Replace ad-hoc `@StateObject` creations (e.g., `AuthenticationManager()`, `TaskListManager()`) with instances obtained from `SharedManagerStore` via `@EnvironmentObject` + async `get*Manager()` calls
  - Prioritize high-traffic views: PhaseListView (authManager, taskListManager), ProjectDetailView (phaseManager, aiGenerator, familyManager), TaskDetailView
- Acceptance:
  - Managers are shared across screens (no re-instantiation on navigation)
  - Listener re-attach minimization and state continuity
- References:
  - Existing use in `MainTabView` and `ProjectListView`
