# Paper Grain Performance Implementation Plan

> **For agentic workers:** Execute inline with executing-plans; retain existing checkout edits and do not commit or push.

**Goal:** Remove thousands of sustained paper grain draw calls while preserving the hand tray appearance and behavior.

**Architecture:** Keep the existing frame and ornaments. Render the unchanged dot grid with one 2D MultiMesh using a shared 64-segment circle mesh. Each frame owns its instance buffer, cached until integer size changes; no background viewport, image dependency or persistent global size cache.

**Tech Stack:** Godot 4.7.2, GDScript, ArrayMesh, MultiMesh, graphical screenshot/draw-call regression.

- [x] Freeze the original `presentation/nautical_frame.gd` as a test-only fixture and add `tests/test_paper_grain.gd`. Render legacy and current frames at different sizes/scales; compare RGBA and require <100 draws for the paper frame. Run graphically with isolated APPDATA/LOCALAPPDATA; expect legacy appearance to match but current draw budget to fail before implementation.
- [x] Replace only the nested dot `draw_circle` loop with cached MultiMesh rendering in `presentation/nautical_frame.gd`. Preserve `range(12,int(size.x)-12,5)` / `range(12,int(size.y)-12,7)`, radius .55, color formula, ordering and opacity; no gameplay edits.
- [x] Run the graphical regression, compare saved images, and test resize/recreation and non-paper frames. Rerun the fixed-seed `probe_frame_bottleneck.gd` with a new output filename. Run hand fan and UI/display integration regressions under isolated storage.
- [x] Update the `ui.hud.nautical-frame` asset version/hash and processing metadata in `assets/manifest.json`; run `tools/check_supplied_assets.py`, `tools/check_docs.py` and whitespace checks. Record measurements, limitations and validation in `evidence/paper-grain-performance-20261019.md`. Review the final diff and retain changes locally.
