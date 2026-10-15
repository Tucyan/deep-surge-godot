# Godot Settlement Implementation Plan

> **For agentic workers:** Use subagent-driven-development for the isolated page task; execute the coupled rules/inventory/session changes together. Review specification first, then code quality. No commits or pushes are requested.

**Goal:** Deliver two settlement pages with real run statistics, deterministic scores, saved reports, hold-to-accelerate logs, and return from analysis to logs.

**Architecture:** Inventory and rule mutations emit transaction-local statistics; GameSession rolls back failures and freezes reports after successful terminal commands. A pure scoring module owns formulas, while a standalone page owns playback state and never updates rules or awards points.

**Tech Stack:** Existing Godot 4.7.2, GDScript, Compatibility renderer, JSON snapshots; no downloads.

## Tasks

- [x] Add tests/test_settlement.gd before production edits. Assert new-game stats, rejected-command isolation, actual inventory consumption, immutable reports, JSON restore, legacy incomplete reports and score fixtures. Run `Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tests/test_settlement.gd`; expected initial FAIL because settlement is absent.
- [x] Create core/run_statistics.gd and core/settlement.gd. Record quantities/reasons, successful commands, player deltas, cell history, actual node/battle outcomes. Use the design's 350p+150G, normalized crisis rate, final-state survival, capped tags and per-component half-up rounding.
- [x] Modify core/inventory.gd, core/run_rules.gd, core/battle_rules.gd, core/campaign_rules.gd and core/game_session.gd to collect effects, freeze terminal reports after transaction completion and preserve existing node-based rewards. Retain previous schema1 content versions as explicit incomplete-stat compatibility paths.
- [x] Create pages/settlement_page.gd and tests/test_settlement_page.gd (isolated page task). Page owns log scrolling, 0.35s pointer/space hold threshold and 6x acceleration, release/focus reset, pause/manual review, skip/auto-finish, statistics tabs/paging and return to page1. Assert interaction leaves supplied report unchanged.
- [x] Integrate flow_app.gd, pages/voyage_hud.gd, pages/paged_reference.gd and homepage recall. Remove original logs route; terminal/resume goes to settlement; recall shows latest report and survives starting a new game. Update obsolete clean-UI expectation for removed logs route.
- [x] Run rules/save/full challenge/story tests, then GPU tests/test_settlement_visual.gd at 1600x900 and1280x720 using actual viewport input. Inspect screenshots, page bounds, space/pointer acceleration, return and read-only behavior.
- [x] Document actual validation and changes in evidence/settlement-verification.md, README, V0.2 design and frontend contracts. Record remaining limits honestly.

## Contracts for page implementation

`setup(view,catalog,assets)` receives `view.settlement` report. Report includes `scope`, `mode`, `origin`, `seed`, `outcome`, `completed`, `length`, `complete`, `score` (total/grade/components), `points` (granted/pending/bonus), `logs`, `stats`, `cards` array with name/kind and counters, `analysis` array. Optional missing values must degrade safely for legacy reports. Signals follow flow_base: command_requested("home",{}) and action_requested("settlement_exit",""). Page navigation/playback stays local. Class exposes `page_index` (0 logs/1 analysis), `scroll_position`, `accelerating`, `show_analysis()`, `show_logs()`. Logs use a clipped scrolling region; no resource downloads or generated images.
