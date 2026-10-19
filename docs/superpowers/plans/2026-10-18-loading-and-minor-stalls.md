# Loading transitions and minor stalls implementation plan

> Execute sequentially in this session; preserve the existing uncommitted hand-release fix. User explicitly requests transitions only for S01–S03 and performance changes for S04–S08. No export, commit or push.

**Goal:** Animated loading for entering/resuming/leaving the game; targeted performance fixes for setup/settings interactions.

**Architecture:** A presentation-only transition layer wraps UI-originated new/resume/home commands. Existing command semantics remain synchronous for direct callers; transitions block duplicate input and render animated frames before/after the unchanged work. Setup prewarms its known resource art, refreshes picker counters in place. Settings builds tabs lazily; modal open/close avoids repeated scans and preparation-only changes refresh their small region. No rule/RNG changes.

**Tech Stack:** Existing Godot4.7.2 GDScript, CanvasItem drawing and local resources.

## Sequential tasks

- [x] Test isolation: `tests/test_setup_settings_performance.gd` verifies `persistence=false` does not write meta to its disposable test path. Guard new-game meta write in `flow_app.gd` with `if persistence:`. Snapshot real user data hash before testing and compare after.
- [x] S01–S03: `presentation/loading_transition.gd` draws moving compass/waves with `_process`, input shield, changing stage label and fade. Add UI command entry wrapper; duplicate requests are ignored. Keep original dispatch/render work; demonstrate multiple different rendered frames and cleanup/error paths in a graphical regression.
- [x] S04: `new_game_setup.gd` starts existing `assets.warm_textures(RESOURCES.map(...), self)` on preparation creation. Test cache contains all picker resources after warm and rule state is unchanged. Measure fresh-process picker opening.
- [x] S05: split `settings_panel.gd` builders into display/game/narrative; create only current tab, lazily create others once on selection. Test hidden content is absent initially, tab switches preserve entered preferences, no duplicated callbacks.
- [x] S06: remove modal layer before building a new `hud_view()` when base signature matches; retain base controls/context and input restoration. Test original disabled buttons/camera/raft restore and current revision, compare open/close CPU.
- [x] S07: retain preparation contents for same-mode setup request; avoid repeated full title/HUD rebuild when switching home/setup. Only update home content host, retaining backdrop. Test preparation choice still opens correctly after return/new session and public state is unchanged.
- [x] S08: store counter/plus/minus/summary/start refs in setup; update values/disabled states in place in `change_resource`. Verify total/per-type/tutorial limits, focus/control identity, start label and actual selected args.
- [x] Measure before/after S04–S08 in isolated graphical probe; do not report transition duration as a speed gain for S01–S03. Run related existing UI/hand/mobile/tutorial regressions. Register procedural asset dependencies/hashes, verify docs links and report known limits.

Regression commands use the installed Godot console with `--path . --script res://tests/<name>.gd --quit-after 1500`; graphical tests require a renderer and an explicit PASS, not just quit-after exit0. No command/download/permission retry over3; hand timeouts back to user per AGENTS.
