# Task 008: TestFlight Readiness & Telemetry Wiring

## Summary
Create a repeatable way to ship PoC builds: automate TestFlight uploads, document tester steps, and ensure baseline telemetry events reach Firebase/analytics dashboards.

## Acceptance Criteria
- Given a CI/manual script runs, When triggered with PoC configuration, Then it builds, signs, and uploads a TestFlight build plus release notes, and records the build number in README or CHANGELOG.
- Given the build is installed via TestFlight, When testers follow `docs/testflight-beta-manual.md`, Then every checklist item (team creation, invite, task flows, settings) can be completed without undocumented workarounds.
- Given telemetry hooks (`onTaskAddOptionChosen`, `onPreviewShown`, `onTaskAdded`, `onSyncQueued`), When testers perform the actions, Then events appear in the analytics dashboard or log export within 5 minutes.
- Given the release checklist (README Roadmap/TestFlight sections), When v0.1 PoC build ships, Then the docs note the date, active feature flags, and verification steps for future agents.

## Edge Cases / Empty States
- Document fallbacks when Apple submission is rate-limited (e.g., manual upload instructions).
- Provide instructions for testers who lack AI API keys (use demo profile instead of blocking the run).
- Capture metrics for failed telemetry posts (network off) so the team knows if instrumentation is flaky.

## Impact / 主なディレクトリ
- `README.md`, `docs/testflight-beta-manual.md`
- `scripts/run-tests.sh`, `scripts/safe-branch.sh`, any build automation
- Telemetry logging utilities
- CI configuration (if stored in repo)

## Process
1. Add automation + doc updates.
2. Request review (include link to a freshly distributed build + telemetry sample screenshots).
3. Apply reviewer feedback and rerun the build to demonstrate the implement→review→修正 loop.
