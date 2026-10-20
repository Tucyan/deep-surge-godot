# Godot Safe Integration Implementation Plan

> Execute continuously in this session. Use subagent-driven-development for the scoped implementation and independent specification/quality reviews. Preserve both original worktrees; no push, reset, clean, or old-save migration.

**Goal:** Safely integrate the current origins-v1 UI/relic work and v03-development rules into a recoverable, verified integration branch.

**Architecture:** Capture immutable byte copies and Git snapshot refs with a private index. Create an isolated Godot worktree from the captured v03 snapshot, merge the captured origins snapshot, resolve text conflicts and semantic contracts. Retain source snapshots and provenance separately from runtime content. Keep schema2 and use one new content version for the integrated catalogue.

**Tech Stack:** Existing Godot 4.7.2, GDScript, Python standard library, Git. No installations, downloads, global configuration, player-save access, remote changes or pushes.

## Tasks

1. complete — Freeze both inputs into tmp/godot-safe-merge-20261020/input-a and input-b; SHA256 every included file and verify source stability. Create codex/snapshot-* commits using a private GIT_INDEX_FILE without touching either original index/branch. Create codex/integrate-v03-relics in an external worktree; the app-native creator cannot select the nested Godot repository, so use the applicable Git fallback.
2. complete — Merge source snapshots in the integration worktree. Preserve both versions of colliding evidence in historical evidence folders; keep v03 core/config logic, origins UI/art/relics, semantic union of nodes. Explicitly resolve version, help, HUD, docs and route conflicts. Preserve all original files in snapshots; do not import tmp into runtime delivery.
3. complete — Test first: verify new nodes are eligible in the three layers under run quotas, art survives safe public projection while hidden branches remain private, new relic effects survive same-version restore and layer changes, and story UI remains hidden. Run failing tests before minimal contract repairs. Adapt the new relic fixture to legitimate 0.3 state without weakening save checks.
4. complete — Validate core/save/0.3/relic/retained-UI and relevant layout suites with isolated APPDATA/LOCALAPPDATA. Regenerate 7 current public Agent routes with bounded checkpoint/resume segments and independently replay each; do not claim stale-only passing. Stop any timed-out command and hand it to user unless its identified cause is resolved under user rule.
5. complete — Synchronize current docs, content version, provenance and new integration verification evidence. Run check_docs, inspect complete diff, independent spec then quality review, and preserve a reviewable integration commit. Do not alter original worktrees or push. Report exact branch/path, snapshot refs, fresh validation and remaining platform limits.

## Validation commands

- `python tools/verify_v03.py test_session test_save test_v03_campaign test_v03_survival test_v03_journey_flow test_v03_encounters test_v03_weather test_v03_difficulty_stage_design test_v03_stage_balance test_v03_public test_v03_projection test_v03_shop test_relic_expedition test_relic_rewards --frames 600`
- `python tools/verify_v03.py test_craft_partial_refresh test_operation_partial_refresh test_interaction_refresh test_mobile_transmute_layout test_mobile_readability test_acquisition_ui test_relic_art --frames 600`
- `python tools/generate_regression_routes.py --help`, then each route's bounded generation/resume/verify-only command.
- `python tools/check_docs.py`; `python -m unittest discover -s tests -p test_check_docs.py`; targeted graphical tests with `--graphical` and isolated directories.

## Recovery

Source originals remain in place. `snapshots.json` will record commits, refs, source paths, raw file manifests and integrated worktree path. The private-index snapshot process must not stage source files or move their branch tips. No recursive deletion or move is needed.
