# Deep Surge 0.3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development for independent file-owned modules; root integrates dependencies and reviews specification compliance before code quality. Execute continuously within the user's authorized development request.

**Goal:** Implement the frozen [0.3 scope](../../design/v03-release-scope.md), including three-layer challenge, progressive deprivation, configurable node/weather generation, node-triggered battles and consistent saves/UI/Agent.

**Architecture:** Shared immutable catalogue definitions feed pure campaign/survival queries and a single dispatch-driven mutation path. Current global voyage clocks remain monotonic; explicit journey state adds per-layer progress. Node generation owns weather constraints and controlled temporary templates; environment and UI never independently replace candidates.

**Tech Stack:** Godot 4.7.2, GDScript, JSON, existing Python/Node standard-library verification tools. No installation or global configuration changes.

Workspace: `C:/Users/ALmerb/.codex/worktrees/deep-surge-v03` on `codex/v03-development`. Detailed shared APIs and file ownership: `.planning/v03-development/contracts.md`. Existing 0.2 docs retained as sources until current behavior is verified; original working tree untouched. Base session and recall tests PASS before implementation.

## Task 1: Campaign definitions and progressive survival (root)

Files: create `core/campaign_rules.gd`, `core/survival_rules.gd`, `content/data/journeys.json`, `content/data/layers.json`, `content/data/balance.json`, `tests/test_v03_campaign.gd`, `tests/test_v03_survival.gd`; modify `core/game_session.gd`, `core/run_rules.gd`, `content/catalog.gd`, `content/manifest.json`.

- [x] Write and execute failing integration checks using `s.dispatch("new", {"mode":"challenge","origin":"fool","seed":22})`, `check(s.state.length==25,"challenge has 25 voyages")`, and real settlement sequence `check(s.state.player.hp==hp_before-2,"second hunger shortage loses2")` with hydration maintained.
- [x] Add immutable journey/layer definitions and `Campaign.layer/profile/initialize/advance/valid/project` methods. Challenge lengths5/10/10, story11, tutorial3. Keep Boss completion separate from final success.
- [x] Implement `Survival.costs/quote/settle/valid` using locked per-stat voyage costs, independently accumulated counters, caps5/<=0 unbounded; story/tutorial bind legacy profile explicitly.
- [x] Integrate dispatch, real next-voyage transitions and catalogue reference validation/content fingerprint. Preserve all state at transitions. Run both new tests until PASS; malformed state and old version reject.

## Task 2: Nodes, candidate pools, battles and growth (node owner)

Files: `core/encounter_rules.gd`, new `core/navigation_rules.gd`, `core/battle_rules.gd`, `core/difficulty_rules.gd`, `core/origin_rules.gd`, `content/data/nodes.json`, `content/data/enemies.json`, `content/data/node_pools.json`, `content/data/navigation_profiles.json`, `content/data/battle_templates.json`, new `tests/test_v03_encounters.gd`.

- [ ] Test real node selection, random battle branch and template save provenance with expected behavior before production edits; execute RED.
- [ ] Move per-layer membership/weights/visit scope/window to profiles. Expose `Encounter.valid_node/leave/valid_content`, obey legal layer pools, safety and Boss priority. Weather hard category requirements exclude non-battles and supplement missing slots from controlled templates, never arbitrary enemy values.
- [ ] Normalize direct/random option battle requests, preserve chosen outcome ID and optional continuation, single transaction, same visit. Add ordinary chest node with70% hard battle and actual advertised reward; no chest-specific subsystem.
- [ ] Configure weak/mid/final Boss nodes and independent rewards; enemy baseline + layer + difficulty scaling exactly once; use Campaign.record_boss. Balance ordinary battle retreat/prebattle leave4; protect ruin/tutorial; use configurable growth/combat values.
- [x] Execute new behavioral tests and relevant existing node/battle/tutorial tests; report stale 0.2 fixtures separately without claiming total0.3 complete.

## Task 3: Weather lifecycle and navigation modifiers (weather owner)

Files: `core/environment_rules.gd`, `content/data/environments.json`, new `content/data/weather_profiles.json`, new `tests/test_v03_weather.gd`.

- [ ] Add failing tests for weather category modifiers and once-per-voyage rain damaging2~3 distinct intact cells; verify RED.
- [ ] Implement referenced layer weather pools/weights/protection plus pure `navigation_modifiers/survival_modifiers`; formally configured full-combat weather active inⅡ/Ⅲ. Coordinate schema with node owner.
- [ ] Add rain: two-voyage/+15hunger initial trial parameters, damage distinct intact functional cells at start_round before production, no immediate detachment, environment RNG only. Insufficient cells uses available intact cells; lifecycle flags prevent repeats. These are documented trial values, not user-frozen values.
- [x] Validate duration/effect/profile references and restore state; preserve fog/pending-refresh behavior. Execute own + existing environment tests and report.

## Task 4: Public projections and in-game help (UI owner)

Files: `pages/voyage_hud.gd`, `presentation/hud/status_hud.gd` if needed, `presentation/game_help.gd`, `adapters/agent_session.gd`, new `tests/test_v03_projection.gd`.

- [ ] Write failing checks for `journey.layer_label=="Ⅰ"`, no raw RNG in Agent, projected deprivation,total/costs and updated HUD heading. Execute RED.
- [ ] Show Roman-only layer label + local voyage progress for challenge; preserve story/tutorial meaningful heading. Show actual upcoming deprivation damage and cumulative counters via readable tooltip/status, no invented UI mechanics.
- [ ] Update help and retreat wording to4; expose common public journey/survival projection to Agent. Never reveal future pools, hidden chest outcomes or live random state.
- [x] Execute projection and HUD tests with isolated data; integrated graphical screenshot remains pending.

## Task 5: Integration, same-version saves and rewards (root)

Files: `core/run_rules.gd`, `core/run_rewards.gd`, `core/settlement.gd`, `application/hud_projection.gd` as required, new integration tests.

- [ ] Test real5→6 and15→16 transition with snapshots, production/aging, death and withdrawn Boss handling. Expected only global+1/local reset and current layer added to cleared.
- [ ] Replace old length/fee/node assumptions with canonical configuration-aware checks; validate journey consistency, counters and generated node provenance. ReportIDs scoped to actual journey, final-only unlock/reward behavior.
- [x] Execute JSON roundtrip in navigation/event/battle/aftermath/discard; reject malformed counters/layers/fees/template enemies. Keep profile write-failure gate and legacy gallery exception unchanged.

## Task 6: Current-version routes, docs and review (root + reviewers)

Files: `tools/generate_regression_routes.py`, route fixtures/manifest, affected current docs/topics, new `evidence/v03-development-verification.md`, document checker version recognition.

- [ ] Run fixed-seed standard/hard/nightmare challenge and story via real Agent public commands; generate and replay current-version fixtures. A failed strategy is a recorded failure, not a fabricated win; ensure at least one25-station challenge survival and formal weather/chest are exercised by legitimate actions.
- [ ] Run session/tutorial/difficulty/recall/narrative/save/acquisition/UI relevant suites, Node content tests, Python interface and docs tests. Commands are existing Godot `--headless --path . --script res://tests/<name>.gd` with isolated APPDATA/LOCALAPPDATA; log actual results.
- [ ] Run graphical HUD test/capture in isolated data, inspect screenshot and separately record real touch/export limits. Do not call headless acceptance proof of mobile/export success.
- [ ] Sync current mechanisms, environment, difficulty, Agent, save and settlement docs only to implemented verified behavior; leave scope/history clearly distinct. `python tools/check_docs.py`, `python -m unittest discover -s tests -p test_check_docs.py -v`, `git diff --check` must pass.
- [ ] Request specification review then code-quality review, repair findings, rerun affected checks. Keep branch/worktree for user review; no push or merge without explicit instruction.

## Execution constraints

Long-running/permission/download failures at most3 attempts; an actual timeout stops retries and is handed to the user. Use bounded commands/logs and progress updates; do not install dependencies. No old save migration. Do not stage nested repositories, delete source/experimental files or access real player saves. Trial balance values are documented and may change based on actual route results.
