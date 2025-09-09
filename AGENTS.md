# AGENTS.md

This document describes how AI coding agents (e.g., Codex CLI, Claude, etc.) should work in this repository. It captures working agreements, guardrails, and key architectural notes so that changes remain safe, minimal, and consistent.

## Purpose

- Enable fast, precise edits with high signal-to-noise.
- Preserve system integrity (Firestore, Rules, iOS app) while iterating.
- Make recurring operational tasks (rules deploy, diagnostics) predictable.

## Guardrails

1. Use the patch workflow only
   - Apply changes via `apply_patch` (diff-based). Do not run `git commit` unless explicitly requested.
   - Keep diffs minimal and scoped to the task. Avoid drive‑by refactors.

2. No secrets or network assumptions
   - Do not inject credentials or change project IDs.
   - Assume network may be restricted; prefer instructions over remote actions.

3. Respect existing styles and constraints
   - Follow current Swift style and file organization.
   - Do not add license headers or rename files unless requested.

4. Validate critical paths
   - Prefer small, targeted runtime checks (e.g., listeners, simple reads) via existing app flows rather than heavy test scaffolding.

## High‑Value Patterns In This Repo

- Firestore transactions
  - Always perform all reads before any writes inside a transaction.
  - Prefer explicit array writes (read → compute next array → update) instead of `arrayUnion` when rules need to validate exact diffs.

- Invitations (Unified)
  - Single source of truth: `invitations_unified/{code}` (docId = normalized code).
  - Validation reads are allowed; listing is not.
  - `usedCount` may be incremented by exactly +1 in a transaction (rules enforce this).
  - Family join writes update both `families/{id}.members` and `users/{uid}.familyIds` using explicit arrays.

- Realtime UI
  - Prefer `addSnapshotListener` for: families (members), family‑owned projects, project detail, project members subcollection (for live member count).

## Firestore Rules (Ops Cheat‑Sheet)

- Deploy
  - `firebase use <project>` (e.g., `shigodeki-dev`)
  - `firebase deploy --only firestore:rules --project <project>`

- Verify what’s live
  - `firebase firestore:rules:get --project <project> > /tmp/rules.live`
  - `diff -u iOS/firestore.rules /tmp/rules.live`

- Expected key allowances
  - `invitations_unified/{code}`:
    - `get`: authenticated
    - `list`: false
    - `update`: creator OR `usedCount` exactly `+1`
  - `families/{id}` and `users/{uid}`:
    - Allow explicit‑array updates that add exactly one element (self) and preserve existing elements.

## iOS App Notes

- UnifiedInvitationService
  - Normalize input before lookups.
  - In `runTransaction`, read all docs first (invite, family, user), then write updates.
  - Do not mix async/await inside Firestore transaction blocks.

- Views and Operations
  - FamilyDetailView: listen to `families/{id}`; reload members/projects when `members` change.
  - FamilyProjectOperations: for family‑owned projects, query `projects` where `ownerType == "family"` and `ownerId == familyId`.
  - ProjectSettingsView: listen to project doc; count members via `projects/{id}/members` subcollection for accuracy.

## Working Procedure (Default)

1. Understand scope
   - Ask for constraints if ambiguous. Avoid speculative refactors.
2. Plan succinctly
   - State high‑level steps (1–5 items). Keep one step in progress.
3. Patch surgically
   - Use `apply_patch`. Keep diffs focused. Maintain existing patterns.
4. Validate
   - Prefer lightweight, local verifications (logs, listeners, simple queries).
5. Hand off
   - Summarize what changed, how to verify, and any follow‑ups.

## Adopted Standards from CLAUDE.md

The following repo standards apply to agents as well and should be respected in edits and proposals:

- Single Responsibility + 300‑Line Rule
  - 1 file = 1 clear responsibility; prefer files under ~300 lines.
  - When a file grows, extract subviews/components/helpers rather than adding complexity.

- Bug Fixing Protocol（再現→失敗テスト→修正→回帰→説明）
  - Reproduce the issue deterministically.
  - Prefer adding a failing unit/UI test first (when test scaffolding exists and scope allows).
  - Fix minimally, then run related tests to prevent regressions.
  - Document root cause and verification steps.

- TDD Principles
  - No new behavior without tests when feasible; focus tests on critical logic and boundary conditions.
  - Keep tests independent and fast. Do not chase coverage for numbers alone.

- Scope and PR Hygiene (for human workflows)
  - 1 PR = 1 responsibility; avoid mixing renames/moves with logic changes.
  - Keep diffs small; declare what’s in/out of scope; don’t expand scope mid‑work.

- Branch Freshness
  - Avoid long‑lived stale branches. Rebase or recreate from `main` before starting significant work.

## Diagnostics Quick Reference

- Code search (fast): `rg -n "pattern" iOS`
- Show file slice: `sed -n 'START,ENDp' path/to/file`
- Watch invited flow logs: filter for `UnifiedInvitationService`, `FamilyViewModel`, `JoinFamilyView`.

## When To Escalate

- Cross‑cutting changes (schema, rules, app‑wide patterns).
- Destructive operations (deletes, mass renames).
- Network‑bound ops (npm/pod install, emulator spins) when sandboxed.

## Non‑Goals

- Do not introduce new dependencies or build steps unless explicitly requested.
- Do not alter analytics/telemetry without approval.

---

If something here conflicts with explicit user instructions, follow the user and note the divergence in your summary.
