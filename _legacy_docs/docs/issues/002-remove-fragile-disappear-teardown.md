# Remove fragile onDisappear listener teardown

- Area: PhaseListView, PhaseTaskListView
- Problem: `removeAllListeners()` on `onDisappear` causes transient empty states upon returning, while re-attach races with UI rendering.
- Fix (implemented):
  - Remove `removeAllListeners()` from `onDisappear` for phase and list views.
  - Listener lifecycle now managed by `startListening...` replacing any existing listener (see Issue #001).
- Acceptance:
  - Navigating back-and-forth does not cause empty states
  - No listener leaks (verified by single-listener policy in managers)
- Files:
  - iOS/shigodeki/PhaseListView.swift
