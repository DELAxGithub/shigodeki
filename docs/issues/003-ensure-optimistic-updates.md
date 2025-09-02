# Ensure optimistic updates across managers

- Area: TaskListManager, EnhancedTaskManager
- Problem: After create/update/delete, UI sometimes waits for the snapshot to reflect changes, leading to brief zero/empty displays.
- Fix (implemented):
  - Immediately update local collections after successful write
    - TaskListManager.createTaskList: append & sort if missing
    - EnhancedTaskManager.createTask: append & sort if missing
- Acceptance:
  - Create flows reflect instantly in UI without waiting for first snapshot
  - Snapshot arrival reconciles, without duplicates
- Files:
  - iOS/shigodeki/TaskListManager.swift
  - iOS/shigodeki/EnhancedTaskManager.swift
