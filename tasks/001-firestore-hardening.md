# Task 001: Firestore Hardening for Family & Invitation Writes

## Summary
Lock down Firestore so PoC data stays private: enforce explicit-array updates for family membership, tighten invitation write rules, and remove the legacy `/invitations` surface while keeping `UnifiedInvitationService` transactions green.

## Acceptance Criteria
- Given an authenticated user **not** in `families/{id}.members`, When they `get` or `update` that family, Then Firestore rejects the request with `permission-denied` (verified via emulator tests under `iOS/test/family-access.test.js`).
- Given a successful join transaction, When a member is added, Then both `families/{id}.members` and `users/{uid}.familyIds` are written via explicit array diffs (no `arrayUnion`) and the rules permit exactly +1 additions as described in `AGENTS.md`.
- Given any authenticated client, When it tries to `create`/`update`/`delete` documents in `/invitations/{id}`, Then the write is rejected because the legacy match block has been removed.
- Given an invitation consumption, When `usedCount` increments, Then Firestore enforces `usedCount == previous + 1` and rejects +2 or -1 mutations.
- Given the `test/connection` helper path, When building a non-debug configuration, Then the unauthenticated `allow read` escape hatch is disabled.

## Edge Cases / Empty States
- Handle the case where `families/{id}` or `users/{uid}` documents are missing fields by initializing empty arrays during the transaction.
- Invite documents older than 30 days must still be readable for auditing but cannot be reused (expired state is surfaced at the app layer).
- Backfill scripts must cope with documents that already store `members`/`familyIds` in inconsistent order; document any migrations.

## Impact / 主なディレクトリ
- `iOS/firestore.rules`
- `iOS/shigodeki/Services/UnifiedInvitationService.swift`
- `iOS/test/*.test.js` (emulator rule tests)
- `docs/validation-test.md`

## Process
1. Implement rule + service changes.
2. Request a code review focused on security scenarios and document reviewer findings.
3. Address every finding (even minor nits) with a follow-up patch so that the loop「実装→レビュー→修正」is exercised at least once.
