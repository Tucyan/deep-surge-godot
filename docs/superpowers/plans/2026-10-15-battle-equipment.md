# Battle and equipment implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development to implement this plan task-by-task. Preserve existing uncommitted changes and do not commit or push.

**Goal:** Implement the user's consolidated shield/resource-combination/equipment update in the current Godot game, with replaceable visual placeholders and no rebalance of existing content.

**Architecture:** GameSession remains the transactional command boundary. Battle rules own actions and shield lifetimes; equipment rules own generator storage and production; UI selection and preview never consume resources or advance live RNG. State remains JSON serializable, with strict known-version migration.

**Tech Stack:** Godot 4.7.2, GDScript, JSON content tables, existing SceneTree behavior and GPU UI fixtures.

## Scope and decisions

- User authorized `gpt-6-luna` with `high` reasoning for subagents and explicitly accepted configurable development defaults for unspecified new equipment parameters.
- Existing player stats, enemies' HP/damage, existing recipes, food/water, AP progression and existing equipment yields remain at their current values. New parameters are development defaults, not balanced or previously confirmed numbers.
- Five resource combinations only: wood, iron, rope, plastic, cloth. No direct corpse/food/water combat combination.
- New equipment IDs: `shieldRack`, `generator`, `fishingNet`, `crate`. New GLB assets are being created by the user; register stable replacement IDs and use clearly labelled temporary presentation.
- Battle rewards add two basic resources, three for explicitly hard/boss encounters. Preserve existing corpse/coin rewards pending a separate reward decision.
- Use current checkout `codex/hand-layout-stacking`, which contains active unsaved work. Local source baseline for this request: `../.planning/combat-equipment-v1-before/`. Do not reset these changes.

## Task 1: Transactional battle actions and equipment core

**Files:** `core/battle_rules.gd`, `core/game_session.gd`, `core/run_rules.gd`, `core/inventory.gd`, `core/auto_progress.gd`, `core/run_statistics.gd`, `content/catalog.gd`, `content/data/*.json`; add focused rule modules if needed.

- [ ] Add and run failing behavior tests in `tests/test_battle_actions.gd` and `tests/test_new_equipment.gd` before implementation. Test real GameSession commands rather than mock UI.
- [ ] Fixed `attack` and `block`: 1 AP, 1 damage / current-turn shield; never enter ordinary hand. Migrate old temporary punch instances.
- [ ] Add source/expiry-based shields, direct attack absorption, poison/pollution bypass, one-time plastic carry and earliest-expiry consumption. Enemy action resolves before expiring current-turn shields.
- [ ] Add atomic resource combinations and `buff_uid` attachment. Validate resource instance, target and revision before consuming anything. Rope suppresses explicit special attacks, including biter's separately specified cell damage and jelly poison.
- [ ] Add generator ready output and independent boost card storage, production augmentation, shield rack, fishing net and effective crate limit. User steering: full generator slots permit overflow output, with new overflow cards expiring at the next voyage settlement; expire before producing, retain expiry when claimed. No fuel pauses progress. Disabled/detached devices provide no benefits; resolve detachment before production.
- [ ] Persist new state with strict validation and migrate only recorded historical fingerprints. Old balance fingerprint: `be2b3aebf83c9a36beb2fc99c8a174de78eaf5ba2749883584b4e3b2b67cc9fe`; pre-request fingerprint: `a7bff4df6d81283c3f09e76b8af60e1298f985da4b90a4a3adfcac25709e4f9c`.
- [ ] Run focused rule/save/auto-progress regressions. Expected: clear PASS, deterministic rewards on JSON restore, failed commands leave snapshot unchanged.

Command contracts:

```gdscript
session.dispatch("battle_action", {"action":"block", "resource_uid":wood_uid})
session.dispatch("battle_action", {"action":"attack", "buff_uid":power_uid})
session.dispatch("play", {"uid":arrow_uid, "buff_uid":power_uid})
session.dispatch("claim_boost", {"cell":generator_cell, "id":"barrier"})
session.dispatch("boost_device", {"cell":filter_cell, "buff_uid":production_uid})
```

Projection: `view.boost_cards` entries contain uid/id/definition/source cell; `view.player.limit` is effective limit. Battle preview runs on an isolated state. Displayed selections never become pending consumed resources in GameState.

## Task 2: Specification review, then code review

- [ ] Independent subagent compares changed core against Task 1 and conversation scope, then reports actionable gaps.
- [ ] Implementer fixes gaps and reruns affected behavior tests.
- [ ] Independent quality review checks lifetime, rollback, save validation, RNG, stat counting and auto-advance. Resolve blocking issues before UI implementation.

## Task 3: Playable UI and replaceable models

**Files:** `pages/flow_battle.gd`, `flow_app.gd`, `pages/paged_reference.gd`, `pages/voyage_hud.gd`, `presentation/raft_actions.gd`, `presentation/raft_state_models.gd`, relevant asset manifest and documentation.

- [ ] Add failing UI command tests using actual page controls, not only source searches.
- [ ] Keep base actions outside hand fan. Show AP, shield sources/expiration and actionable enemy intent.
- [ ] Select resource or boost, then action, preview final result and explicitly confirm. Cancel, re-render and open details preserve live snapshot and RNG; stale selections fail safely.
- [ ] Expose generator fuel, completed output claims, stored boosts and production target selection through real UI. Keep maximum capacity and disabled reasons visible.
- [ ] Ensure new equipment can be crafted, installed, upgraded, inspected and picked with temporary labelled representation. No new model production or external downloads.
- [ ] Capture and inspect 1280x720 and 1600x900 actual GPU screenshots; verify command interaction, cancellation and integration with ordinary voyage/raft HUD.

## Task 4: Integration and delivery

- [ ] Review UI specification, then implementation quality with independent subagents.
- [ ] Run focused existing flow/story/save/crafting/auto-progress and asset checks. Update old punch-in-hand expectations only where the new rule requires it; preserve original attack values.
- [ ] Document actual default parameters, combat rules, save compatibility and model replacement mapping in `docs/battle-equipment.md`, update README and evidence report.
- [ ] Complete final independent review, fix material issues, record exact check results and remaining art limitations. No balance claims, commits or pushes.
