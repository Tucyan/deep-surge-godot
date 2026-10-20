# In-Game Interaction Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce measured in-game stalls by retaining existing controls and refreshing only the visible regions affected by high-frequency UI or game actions.

**Architecture:** Keep `GameSession.dispatch` as the only rules boundary. UI-only workbench selection refreshes existing workbench controls. Rule actions take a conservative partial path only when the current HUD/page structure remains compatible; update page contexts and the affected widgets, otherwise use the existing full render as fallback.

**Tech Stack:** Godot 4.7.2, GDScript, SceneTree integration tests and the graphical in-game stall probe.

---

## Scope and files

- `pages/craft_page.gd`: retain transmute/workbench controls for selection-only edits.
- `pages/flow_battle.gd`, `pages/voyage_hud.gd`: refresh the battle action region after a continuing combat action.
- `flow_app.gd`, `application/page_host.gd`, selected page helpers: add a conservative retained-HUD rule-action route and preserve correct revisions/contexts.
- `tests/test_partial_refresh.gd` and focused tests: assert node identity, visible state, rule/RNG behavior, and full-render fallback.
- `tests/probe_ingame_stalls.gd`: verify the same measured entry points after integration.

## Task 1: Workbench selection refresh

1. Add a test that captures the craft modal and relevant child identities, selects one resource and a new target through current controls, then expects the same page/controls and unchanged rule snapshot.
2. Run it and verify it fails specifically because the page/control is replaced.
3. Add minimal refresh methods in `craft_page.gd` that update selected allocation counts, target state, preview/output and execute-button state without rebuilding unrelated controls.
4. Run the focused test plus `test_craft_grid.gd`, `test_transmute_selection.gd` (if present), and `test_interaction_refresh.gd`.

## Task 2: Continuing battle action refresh

1. Add a test that selects and confirms a nonlethal action, expects existing world/HUD/hand and battle page identities to persist, and verifies enemy/AP/status labels match the dispatched session.
2. Run it and verify the current full HUD rebuild fails the identity assertion.
3. Add a battle-page refresh that replaces only state-dependent battle widgets and updates the page context after dispatch; detect phase changes and terminal outcomes and retain full-render fallback.
4. Run the battle refresh, action, supply, equipment, salvage, tutorial and partial-refresh tests.

## Task 3: Safe operation partial refresh

1. Add integration coverage for salvage, discard, install, transmute, and shop confirmation through existing request/dispatch routes; check correct state, contexts, receipts and node lifetimes.
2. Run tests before implementation and record expected failures.
3. Implement only operations with a proven stable retained HUD contract. Refresh the hand after UID changes; refresh capacity, resource/status labels and affected raft-cell visuals where needed. Operations changing phase/panel, triggering battle/settlement, or changing board topology must keep full-render fallback.
4. Run focused operation and persistence/receipt regression tests.

## Task 4: Integrated verification

- Run all focused interaction, battle, raft, craft, shop and acquisition UI tests.
- Re-run `probe_ingame_stalls.gd` in graphical mode with isolated `APPDATA`/`LOCALAPPDATA`; compare medians with the 2026-10-19 baseline JSON.
- Run the current required Agent routes, core/save suites and platform-specific checks only where the changed paths require them. Do not claim mobile/GPU/export coverage unless actually run.
- Record results and limitations in `evidence/ingame-stalls-20261020.md` and update the stall backlog.

Result (2026-10-20): re-ran the graphical probe twice in isolated APPDATA (186 samples each, 0 failures, exit 0). `battle_confirm_attack` 101.2 → 12.1 ms, `transmute_add_wood` 51.5 → 10.7 ms, `transmute_target_plastic` 83.1 → 14.3 ms, all with `render_ms` 0 and no HUD/page rebuild; shop, lamp craft, transmute execute, install, salvage and discard still take the full-render fallback. Workbench tab switching only drops the host rebuild (page still calls `build()`), so it stays near 49 ms. Numbers and limits: [ingame-stalls-20261020.md](../../../evidence/ingame-stalls-20261020.md). Android, touch and save-I/O coverage were not run.

## Non-goals

No save schema, rules, RNG, content, navigation route, loading animation, global cache, renderer or Android configuration changes. Do not remove correctness fallbacks to meet timing targets.
