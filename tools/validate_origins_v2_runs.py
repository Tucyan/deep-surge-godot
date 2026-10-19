"""Short integration sample; not a balance or optimal-policy benchmark."""
import json
from pathlib import Path
from smart_playtest import AgentClient, play_run

target = Path(__file__).resolve().parents[1] / 'evidence/origins-v2-playthroughs.json'
rows = []
for origin in ('hoarder', 'zealot', 'engineer'):
    with AgentClient() as game:
        row = play_run(game, seed=22, origin=origin, max_steps=500, verbose=False)
        row['engine_errors'] = list(game.errors)
    rows.append(row)
    target.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding='utf-8')
    print(origin, row['phase'], row['outcome'], row['steps'], 'errors', len(row['engine_errors']), flush=True)
