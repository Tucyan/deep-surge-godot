"""Refresh loading/setup/settings procedural sources while preserving asset metadata."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    'ui.loading.transition': 'presentation/loading_transition.gd',
    'ui.title.menu': 'presentation/title_menu.gd',
    'ui.title.home': 'pages/flow_home.gd',
    'ui.starting-resources': 'pages/new_game_setup.gd',
    'ui.settings-panel': 'presentation/settings_panel.gd',
    'ui.modal-layout': 'flow_app.gd',
}

def register():
    path = ROOT / 'assets/manifest.json'
    raw = path.read_bytes()
    manifest = json.loads(raw)
    assets = manifest['assets']
    for asset_id, source in SOURCES.items():
        digest = hashlib.sha256((ROOT / source).read_bytes()).hexdigest()
        entry = assets.setdefault(asset_id, {
            'path': 'res://' + source, 'source': source, 'version': 0,
            'dependencies': [], 'license': 'project-authored procedural UI; no external artwork',
        })
        if entry.get('sha256') != digest:
            entry['version'] += 1
        entry.update(sha256=digest, source_hash_verified_on='2026-10-18')
    assets['ui.loading.transition'].update(
        visual_random='none',
        runtime_mapping='Full-screen rotating compass, two moving arcs, three drifting wave lines, stage label and 160ms fade; blocks input until target draw; no fabricated percent; direct rule API remains synchronous',
    )
    entry = assets['ui.modal-layout']
    if 'ui.loading.transition' not in entry['dependencies']:
        entry['dependencies'].append('ui.loading.transition')
    entry['loading_and_refresh'] = 'UI new/resume/home/story-load transition; staged original rendering work; weak page context references; modal close skips unchanged view/policy work; home preparation replaces content only'
    assets['ui.settings-panel']['tab_build_policy'] = 'Only selected display/game/narrative tab is initially built; each additional tab built once per modal; native controls and callbacks reused while switching'
    assets['ui.starting-resources']['refresh_policy'] = 'Threaded local picker art warm-up during preparation; counts/buttons/summary/start label updated in place; tutorial and total limits retained'
    text = json.dumps(manifest, ensure_ascii=False, indent=2) + '\n'
    if b'\r\n' in raw:
        text = text.replace('\n', '\r\n')
    path.write_bytes(text.encode('utf-8'))

if __name__ == '__main__':
    register()
