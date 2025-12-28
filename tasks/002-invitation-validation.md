# Task 002: Invitation E2E Validation & Tooling

## Summary
Prove that families can invite and join without regressions by aligning normalization code, automating coverage, and documenting manual validation so PoC households can self-serve onboarding.

## Acceptance Criteria
- Given a family creator uses `FamilyCreationService`, When they share the displayed `INV-XXXXXX` code and another user enters variants like `inv-xxxxxx` or with O/0 swaps, Then `UnifiedInvitationService.joinWithInvitationCode` succeeds and increments `usedCount` by exactly +1.
- Given a stale/expired or deactivated code, When a user attempts to join, Then the UI surfaces `InvitationError.invalidOrExpired` and no Firestore writes occur.
- Given replayed joins (user already a member), When the code is re-submitted, Then the transaction short-circuits (no `usedCount` increment) yet the UX reports success for idempotency.
- Given the manual flow documented in `docs/validation-test.md`, When testers execute Create→Display→Join in staging and production, Then each checklist item is marked complete with timestamps/screenshots.
- Given CI (`iOS/shigodekiTests/UnifiedInvitationServiceTests`) runs, When new normalization cases (O/0/I/L, INV-prefix) are added, Then the suite covers the regression scenario described in `docs/family-invitation-error-analysis.md`.

## Edge Cases / Empty States
- Ensure invite validation handles codes not found in `invitations_unified` by showing a localized error rather than a silent toast.
- Document behavior when `maxUses` is reached so PoC hosts know how to rotate codes.
- Clarify join behavior for anonymous/demo accounts (unsupported) in the README/TestFlight manual.

## Impact / 主なディレクトリ
- `iOS/shigodeki/Managers/FamilyCreationService.swift`
- `iOS/shigodeki/Services/UnifiedInvitationService.swift`
- `iOS/shigodekiTests/UnifiedInvitationServiceTests.swift`
- `docs/validation-test.md`, `docs/testflight-beta-manual.md`

## Process
1. Implement normalization/test updates.
2. Request review focusing on reproducibility (include logs/screens).
3. Apply reviewer feedback (code + docs) so the implement→review→fix loop is completed once.
