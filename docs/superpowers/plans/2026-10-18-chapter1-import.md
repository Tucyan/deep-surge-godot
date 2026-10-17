# Chapter 1 Implementation Plan

> Execute sequentially in this chat; user authorized implementation.

**Goal:** Story mode owns new/load slots and plays imported nodes 1–11; challenge retains shared gameplay without named save/load.

**Architecture:** Convert source flow to local StoryPlayer scenes, one beat per voyage. Keep imported effects in narrative state. Store narrative and validated gameplay snapshot in the same atomic slot. Preserve legacy opening/gallery.

**Tech Stack:** Godot 4 GDScript, JSON, Python standard library importer.

- [ ] Add test_chapter1_import.gd: assert length 11, mandatory first beat, branch-specific trust/items, no cross-node autoplay; drive real player. Run to see expected failure.
- [ ] Preserve source ZIP under asset-sources/chapter1-vn; add tools/import_chapter1.py; output original source and 11 scenes with source spans and branch metadata; validate full references and deterministic output.
- [ ] Extend narrative content/session for flags/items/clues and exact path validation; save final narrative-only effects once. Keep local core numbers.
- [ ] Set story length 11, schedule before each voyage; adapt VN long choices with bounded wrapped layout.
- [ ] Route home start/continue through mode choice; story picker new/load; remove no-story toggle and settings slot switch; challenge resume only current in-memory run.
- [ ] Save paired story snapshot in slot; validate load fully before replacing state. Keep legacy files preserved; old story-only slots show incompatible notice.
- [ ] Run tests with isolated APPDATA, headless import and GPU screenshots; document tested results and explicit conflicts.
