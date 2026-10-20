"""Measure the real level curve per voyage for several battle-appetite styles.

Read-only: drives the public Agent actions and records level/xp observations.
It never injects state and never edits project content.
"""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import statistics
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from agent_client import AgentClient, data
from health_playtest import choose

ROOT = Path(__file__).resolve().parents[1]


def node_score(o, style):
    """Battle appetite: how eagerly a battle node is taken over a safe node.

    Only public fields are used: candidates expose category/kind, never monster/boss.
    """
    p = o['player']
    hp = p['hp']
    if style == 'maximal':
        battle, safe = 100, 20
    elif style == 'risk':
        battle, safe = (100, 20) if hp >= 6 else (-20, 20)
    elif style == 'balanced':
        battle, safe = (100, 20) if hp >= 4 else (-20, 20)
    else:  # careful: only take a battle when it is unavoidable
        battle, safe = (60, 20) if hp >= 9 else (-20, 20)

    def score(n):
        cat = n.get('category', '')
        if cat == 'camp':
            return 90
        if cat == 'boss':
            return 85
        if cat == 'battle':
            return battle
        return safe

    return score


def choose_styled(o, actions, style, route):
    """Reuse the reviewed policy, overriding only node appetite and fight willingness."""
    if o['phase'] == 'navigation':
        best = max(o['candidates'], key=lambda n: node_score(o, style)(n))
        for a in actions:
            if a['command'] == 'voyage' and a['args'].get('id') == best['visit_id']:
                return a
    if o['phase'] == 'story' and o['node'].get('monster'):
        scene = o.get('scene', {})
        wants = o['node'].get('boss') or scene.get('combat') or (
            style == 'maximal' or (style == 'risk' and o['player']['hp'] >= 6)
            or (style == 'balanced' and o['player']['hp'] >= 4)
            or (style == 'careful' and o['player']['hp'] >= 9))
        for a in actions:
            if a['command'] == ('fight' if wants else 'leave_encounter'):
                return a
    return choose(o, actions, 'risk' if style == 'maximal' else style, route)


def run(game, seed, origin, mode, style, route):
    o = data(game.request('reset', {'seed': seed, 'origin': origin, 'mode': mode}))['observation']
    counts = Counter()
    per_voyage = defaultdict(lambda: {'level': 1, 'xp': 0, 'battles': 0, 'fights': 0})
    for step in range(700):
        if o['terminal']:
            break
        actions = data(game.request('actions'))['actions']
        a = choose_styled(o, actions, style, route)
        if not a:
            raise RuntimeError(f'No legal decision: {mode} {seed} {style} {o["phase"]}')
        v = o['voyage']
        o = data(game.request('act', {'action_id': a['action_id'], 'revision': o['revision']}))['observation']
        counts[a['command']] += 1
        if a['command'] == 'fight':
            per_voyage[v]['fights'] += 1
        if a['command'] == 'battle_end':
            per_voyage[v]['battles'] += 1
        per_voyage[v]['level'] = o['level']
        per_voyage[v]['xp'] = o['xp']
    final = data(game.request('result'))
    battles = final.get('report', {}).get('stats', {}).get('battles', {})
    wins = sum(1 for b in battles.values() if b.get('outcome') == 'won')
    return {
        'style': style, 'seed': seed, 'origin': origin, 'mode': mode,
        'outcome': final['outcome'] or final['phase'],
        'completed': final['completed'],
        'voyages': o['voyage'],
        'final_level': o['level'],
        'fights': counts['fight'],
        'wins': wins,
        'curve': [per_voyage[k] for k in sorted(per_voyage)],
    }


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--seeds', nargs='+', type=int, default=[0, 1, 2, 3, 4, 5, 6, 7])
    ap.add_argument('--mode', default='challenge')
    ap.add_argument('--origins', nargs='+', default=['strong'])
    ap.add_argument('--styles', nargs='+', default=['maximal', 'risk', 'balanced', 'careful'])
    ap.add_argument('--route', default='scholar')
    args = ap.parse_args()

    rows = []
    with AgentClient() as game:
        for style in args.styles:
            for origin in args.origins:
                for seed in args.seeds:
                    try:
                        r = run(game, seed, origin, args.mode, style, args.route)
                        rows.append(r)
                        print(json.dumps({k: r[k] for k in ('style', 'seed', 'outcome', 'voyages', 'final_level', 'fights', 'wins')}, ensure_ascii=False), flush=True)
                    except Exception as exc:  # keep the sweep going
                        print(json.dumps({'style': style, 'seed': seed, 'error': str(exc)}, ensure_ascii=False), flush=True)
                    if game.errors:
                        print('\n'.join(game.errors), flush=True)

    out = ROOT / 'evidence/level-curve'
    out.mkdir(exist_ok=True)
    (out / f'raw-{args.mode}-{args.route}.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding='utf-8')

    summary = defaultdict(lambda: {'final': [], 'wins': [], 'voyages': [], 'voyage_level': defaultdict(list)})
    for r in rows:
        if 'error' in r:
            continue
        s = summary[r['style']]
        s['final'].append(r['final_level'])
        s['wins'].append(r['wins'] or 0)
        s['voyages'].append(r['voyages'])
        for i, v in enumerate(r['curve']):
            s['voyage_level'][i + 1].append(v['level'])
    lines = []
    for style, s in summary.items():
        rows_out = []
        for v in sorted(s['voyage_level']):
            vals = s['voyage_level'][v]
            rows_out.append({'voyage': v, 'n': len(vals), 'mean_level': round(statistics.mean(vals), 2),
                             'min': min(vals), 'max': max(vals)})
        lines.append({'style': style, 'n': len(s['final']), 'mean_final_level': round(statistics.mean(s['final']), 2),
                      'mean_wins': round(statistics.mean(s['wins']), 2), 'mean_voyages': round(statistics.mean(s['voyages']), 2),
                      'per_voyage': rows_out})
    (out / f'summary-{args.mode}-{args.route}.json').write_text(json.dumps(lines, ensure_ascii=False, indent=2), encoding='utf-8')
    for l in lines:
        print(json.dumps(l, ensure_ascii=False))
