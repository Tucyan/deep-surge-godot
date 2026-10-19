# Tutorial Enchantment and Sale Implementation Plan

> **For agentic workers:** Use executing-plans to implement this plan task-by-task in this authorized session.

**Goal:** Teach one attack enchantment, one defense enchantment and one shop sale using actual gameplay operations.

**Architecture:** Extend tutorial state-derived steps and guards without changing ordinary battle or shop balance. Resource enchantment uses existing `battle_action` with `resource_uid`; successful dispatch records tutorial milestones. Protect the corpse needed for sale and provide battle teaching materials once. Keep rule/UI random streams unchanged by previews.

**Tech Stack:** Godot 4.7.2, GDScript, existing headless and graphical tests.

- [x] Add failing end-to-end coverage in `tests/test_tutorial_enchantment.gd`: exact resource/AP consumption, wrong action rollback, preview and save restoration, shield absorption, sale proceeds and lesson completion.
- [x] Extend `core/tutorial_rules.gd` with attack/defense enchantment and sale steps. Preserve corpse during second discard; update `presentation/hand_fan.gd` explanations accordingly.
- [x] Update `pages/battle_hud_view.gd`, `pages/flow_battle.gd`, `pages/shop_page.gd` and mobile hints in `flow_app.gd`: terminology, prompted preview, sale tab and available actions.
- [x] Update existing tutorial tests for new mandatory steps; run core, UI, mobile, save and ordinary battle/shop regressions. Capture and inspect graphical evidence.
- [x] Update `docs/difficulty.md`, `docs/current-game-mechanics.md` and verification record with actual results and limitations. No commit/push requested.
