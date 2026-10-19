# Architecture Health Implementation Plan

> **For agentic workers:** Execute inline using executing-plans, in the user-requested order 5 → 4 → 3 → 1 → 2. Preserve the existing dirty worktree; do not stage, commit, push or discard other changes.

**Goal:** Make Godot the unambiguous current project, isolate application responsibilities, restore meaningful current-version route gates, and fix the two reproduced boundary defects.

**Architecture:** Keep GameSession and existing UI/Agent contracts. Extract application coordinators with explicit app parameters and owned state; keep compatibility methods on FlowApp. Narrative slot metadata is cached and invalidated on mutation, with explicit refresh on entering the slot menu. Current-version routes must execute, while historical traces may remain stale without migration.

**Tech Stack:** Godot 4.7.2 / GDScript, existing Python stdlib AgentClient, Node built-in content tests. No new dependencies.

## 5. Current project documentation

- [x] Update root README and AGENTS: Godot is current; Three.js and Unity are historical; retain generic invariants and the explicit old-gallery exception.
- [x] Verify relative Markdown targets and `git diff --check`; no runtime changes in this step.

## 4. Application responsibilities and HUD cost

- [x] Add `tests/test_application_boundaries.gd`: start an isolated app; assert repeated HUD/navigation/modal operations do not call `list_saves`, cached metadata is invalidated by writes, and presentation retention ignores logs/statistics but invalidates after visible state changes.
- [x] Run that script and confirm the expected baseline failures before implementation.
- [x] Add `application/narrative_coordinator.gd`, `persistence_coordinator.gd`, `page_host.gd` and `hud_projection.gd`; move the existing responsibilities while preserving FlowApp methods/properties used by pages and tests.
- [x] Replace whole-state HUD signatures with the visible projection excluding logs/stats/hidden flags; compare a shallow visible-state projection, preserving direct-state-replacement correctness.
- [x] Add `NarrativeStore.has_saves()` and cached list metadata; invalidate after writes/active changes and explicitly refresh on opening the slot menu.
- [x] Run application boundaries, interaction refresh, navigation partial refresh, narrative flow/repairs, reward recovery, recall, loading transition and tutorial regressions in isolated APPDATA. Fix extraction regressions before moving on.

## 3. Current-version route gate

- [x] First run the old route script and record its zero-executed PASS.
- [x] Add a route coverage helper/test: no current routes, missing required route, incompatible fingerprint and duplicate route identity must fail; complete current coverage must pass. Historical entries are counted separately.
- [x] Replace hardcoded v22 paths with `tests/fixtures/routes/manifest.json`; required routes cover both modes and all three difficulties, including a known success and failure case.
- [x] Generate current snapshots/steps using real public Agent actions with the existing policy; store compact JSON traces without rewriting historical evidence. Replay through a JSON round trip, assert terminal status, card conservation and same-version save restoration.
- [x] Run coverage helper and real route script; report executed/stale/failed separately. A current gate never succeeds with zero executed routes.

## 1. Mode-switch transaction

- [x] Run the existing failing `test_mode_contract.gd`; strengthen it with session/narrative identity, pending slot state and successful-switch assertions.
- [x] Add `application/session_coordinator.gd`: create and validate a candidate challenge session; publish the gameplay/narrative pair only on success. Preserve current-session revision checks at the boundary.
- [x] Verify invalid origin/seed/starting-resource/revision attempts preserve both sessions, slot binding, pending selection and snapshots; valid challenge start clears only in-memory narrative attachment as before.

## 2. Action catalogue completeness

- [x] Add a regression using a normally installed filter: quote dismantle is allowed, and list_actions must contain that exact cell operation. Verify preview preserves the original snapshot.
- [x] Add the missing dismantle candidate before the intact-cell filter so damaged installed devices remain represented when the core permits them.
- [x] Verify Agent can act via the enumerated ID, stale revision is rejected, AP/material changes match direct dispatch, and replay remains valid. Re-run route gate after catalogue change.

## Final verification and evidence

- [x] Inspect the task-only delta against a filesystem baseline (the repo already contains unrelated changes).
- [x] Run the relevant core/UI/narrative/Agent tests, Node content tests and current route gate. Bound subprocesses; a real timeout ends attempts and is handed to the user.
- [x] Write `evidence/architecture-health-verification.md` with exact counts, commands and limitations; do not claim GPU/mobile/export verification without running it.
