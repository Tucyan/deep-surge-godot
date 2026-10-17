# Tutorial and narrative repair implementation plan

> For agentic workers: use subagent-driven-development for independent repair tasks and requesting-code-review for final review. All steps preserve the existing uncommitted work.

**Goal:** Repair the seven reviewed bugs, begin the tutorial with explicit starting-card selection, and prevent hints/event choices from overlapping the HUD.

**Architecture:** Keep gameplay in the existing core, narrative in its independent session/store, and setup/layout in pages and flow_app. Do not change gameplay save version or add a second rules implementation. Tutorial scenario outcomes remain arranged but user-facing text explains operations and mechanics without calling out that arrangement.

**Tech Stack:** Godot 4.7.2 GDScript, existing local assets, headless regression scripts and RTX4060 OpenGL screenshots.

- [x] Back up targeted working files, use repair branch, and isolate all test storage through APPDATA.
- [x] Add failing narrative regression tests for slot binding rollback, save-error visibility/retry, affinity filtering/reachability, and highest-tier clear persistence.
- [x] Apply minimal narrative/session/store fixes and replay the existing 53+19 checks plus the new27.
- [x] Add failing tutorial core checks for chosen-card validation, step totals, lost merchant payment, production/settlement/card rules, and user-visible logs.
- [x] Protect the merchant currency, validate the selected eight-card multiset, and correct lesson text without explaining arranged outcomes.
- [x] Add failing setup/first-launch tests, then require explicit choice and initial-card selection; rebuild the form when crossing tutorial/ordinary difficulty.
- [x] Add screenshot-geometry regressions, reserve compact hint and AP/hand bounds, and make event columns scroll independently; test battle hint bounds as well.
- [x] Update actual UI signal/mouse checks and synchronize setup/startup/layout documentation.
- [x] Complete final regression run, GPU screenshot inspection, spec review and code quality review; record evidence and limitations.

Implementation paths: `flow_app.gd`, `pages/new_game_setup.gd`, `pages/flow_story.gd`, `core/tutorial_rules.gd`, `core/game_session.gd`, `core/run_rules.gd`, `core/difficulty_rules.gd`, `presentation/hand_fan.gd`, `adapters/narrative_store.gd`, `narrative/narrative_session.gd` and narrative threshold JSON.

Verification paths: `tests/test_narrative_repairs.gd`, `tests/test_tutorial_rules_repairs.gd`, `tests/test_tutorial_setup.gd`, `tests/test_tutorial_event_layout.gd`, `tests/tutorial_start.gd`, `tests/tutorial_ui.gd`, existing narrative/difficulty/save/UI/action-query checks. GPU output uses the `tutorial-repair-*` prefix and does not overwrite prior evidence.

No automatic commit, merge or push. Existing ordinary-route traces remain v22 and are not accepted as current v23 full-route evidence.
