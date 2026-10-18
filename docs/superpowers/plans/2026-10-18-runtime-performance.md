# Runtime ocean performance plan

Scope: `presentation/toon_ocean.gd` CPU height queries and the equivalent zero-amplitude path in `assets/shaders/toon_ocean.gdshader`. Keep wave equations, visual settings, rules, randomness, save formats and replay unchanged. Execute inline within this authorized optimization task.

1. Run `tests/test_ocean_sampling_performance.gd` headless before editing production. The test compares to the original inverse algorithm at contact boundaries, transition, open water, far fade, multiple bounds and times. Count real displacement/noise calls to demonstrate redundant work (expected FAIL before optimization).
2. Run `tests/probe_runtime_performance.gd` with graphical Godot at 1280×720, seed 22. Use four occupied filter slots and one expansion preview, matching the existing water ghost fixture. Save baseline to `evidence/runtime-performance-before.json`.
3. In `displacement`, calculate `fade_at(g)` first and return `Vector3.ZERO` when zero. Keep every nonzero wave calculation and multiply by the captured fade. In `height_at`, use `if contact_at(Vector2(x,z)) == 1.0: return plane_at(x,z)` before the existing inversion. With complete contact, the initial inverse guess is already a fixed point (horizontal multiplier zero).
4. Re-run the new test (expected PASS), benchmark and existing ocean/ghost/navigation/recall/narrative/rules tests. Record six deterministic GPU views before the shader change, then compare exactly after adding an early flat-frame return in `wave_frame` for `f == 0.0`. Run same-process alternating shader comparison. Save after results. Use measured operation timings, not an assumed FPS gain; frame intervals include GPU and scheduling. A failed command is diagnosed, and a timed-out command is handed to the user per AGENTS.md.
5. Review the diff, document actual data and limits. No automatic commit, push or export.

Completed implementation and validation are recorded in [runtime performance verification](../../../evidence/runtime-performance-verification.md). Camera controls/framing were not changed; no additional camera suite was run.
