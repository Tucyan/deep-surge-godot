"""Bounded balance sample; records every completed run before starting another."""
import json
from pathlib import Path
from smart_playtest import AgentClient, play_run

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / 'evidence' / 'origins-balance-sample.json'
rows = []
for seed in (22, 31, 42):
    for origin in ('strong', 'fool', 'restless', 'hoarder', 'zealot', 'skeptic', 'engineer', 'merchant'):
        with AgentClient() as game:
            result = play_run(game, seed=seed, origin=origin, max_steps=500, verbose=False)
            result.pop('report', None)
            result['engine_errors'] = list(game.errors)
        rows.append(result)
        TARGET.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding='utf-8')
        print(seed, origin, result['outcome'], result['steps'], flush=True)
