"""v20 survival-after-discard regression routes: public actions, JSON traces and replay."""
import json
from pathlib import Path
from agent_client import AgentClient, data
from validate_node_shop import decide

ROOT = Path(__file__).resolve().parents[1]

def run(game, mode, seed, difficulty="standard", trace_prefix="survival-v20"):
    o = data(game.request('reset', {'seed':seed, 'mode':mode, 'difficulty':difficulty}))['observation']
    weather, hidden, navigation = set(), 0, set()
    for step in range(700):
        if o['terminal']:
            break
        weather.update(x['id'] for x in o['environments'])
        hidden += sum(x.get('visibility') != 'full' for x in o['candidates'])
        actions = data(game.request('actions'))['actions']
        # Exercise legal navigation remedies using only visible information.
        action = None
        if o['phase'] == 'navigation':
            action = next((a for a in actions if a['command']=='fix_heading'), None)
            if action is None and o['player']['sanity'] > 48:
                action = next((a for a in actions if a['command']=='scout'), None)
        action = action or decide(o, actions)
        if action is None:
            raise RuntimeError(f'No action: {mode} {seed} {o["phase"]}')
        if action['command'] in ('scout','fix_heading'):
            navigation.add(action['command'])
        o = data(game.request('act', {'action_id':action['action_id'], 'revision':o['revision']}))['observation']
    result = data(game.request('result'))
    assert result['terminal'], (mode,seed,'step limit')
    trace = data(game.request('trace'))
    path = ROOT/'evidence'/f'{trace_prefix}-{difficulty}-{mode}-{seed}.trace.json'
    path.write_text(json.dumps(trace,ensure_ascii=False),encoding='utf-8')
    # Deliberately cross a real JSON serialization boundary before replay.
    replay = data(game.request('replay', {'trace':json.loads(path.read_text(encoding='utf-8'))}))
    assert replay['steps']==len(trace['steps'])
    for c in result['report']['cards']:
        assert c['obtained']==c['remaining']+sum(c.get(k,0) for k in ('use_consumed','cost_consumed','deployed','discarded','lost','cleared','sold')), c
    return {'difficulty':difficulty,'mode':mode,'seed':seed,'phase':result['phase'],'outcome':result['outcome'],
            'completed':result['completed'],'steps':len(trace['steps']),'replayed':replay['steps'],
            'environments':sorted(weather),'hidden_observations':hidden,'navigation_actions':sorted(navigation),'trace':path.name}

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--trace-prefix', default='survival-v20')
    args=parser.parse_args()
    rows=[]
    with AgentClient() as game:
        for mode,seed in [('challenge',n) for n in (22,39,9,73,1000,7919,20261016,4294967295)]+[('story',22)]:
            row=run(game,mode,seed,trace_prefix=args.trace_prefix); rows.append(row); print(json.dumps(row,ensure_ascii=False),flush=True)
        for difficulty in ('hard','nightmare'):
            for mode in ('challenge','story'):
                row=run(game,mode,22,difficulty,trace_prefix=args.trace_prefix); rows.append(row); print(json.dumps(row,ensure_ascii=False),flush=True)
        assert not game.errors, list(game.errors)
    (ROOT/'evidence'/f'{args.trace_prefix}-runs.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
