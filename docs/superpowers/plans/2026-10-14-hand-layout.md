# Hand layout implementation plan

**Goal:** Settings for automatic hand ordering and identical resource stacks, with long press drag reordering.

**Architecture:** A presentation model owns preferences and UID order independently of session state. Both hand surfaces consume grouped view copies; commands still target one actual UID. Preferences use a separate ConfigFile; new games reset manual order.

**Tech Stack:** Godot GDScript, existing ItemCard/HandFan, SceneTree test runners.

- [x] Add and run `tests/test_hand_layout.gd` before implementing `presentation/hand_layout.gd`: grouping boundaries, ordering, unstacking, consumption, preferences and source immutability.
- [x] Connect model through `flow_app.gd` view, settings CheckButtons and both existing fan consumers; add quantity badges without changing action button lookup.
- [x] Delay click until release, enter drag after 0.4 seconds, move the group on release (including outside hand); retain UI order across redraws and disable auto sort after manual movement.
- [x] Add integrated input/settings tests, update old click tests to release and explicitly disable grouping for dense fixtures. Run headless regression tests and render screenshots at 1600×900 and 1280×720.
- [x] Document exact behavior and verification. Leave changes on requested branch without including prior changes in a commit.
