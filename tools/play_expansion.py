"""v15 public-action expansion smoke play; a heuristic sample, not a win-rate study."""
import json
from pathlib import Path
from collections import Counter
from agent_client import AgentClient, data
from smart_playtest import SmartPlayer

ROOT = Path(__file__).resolve().parents[1]

def choose(player, o, actions):
    hand = {c['uid']: c for c in o['hand']}
    devices = {c['equipment']['id'] for c in o['cells'] if c['status']=='intact' and c['equipment']}
    def first(cmd, pred=lambda a: True):
        return next((a for a in actions if a['command']==cmd and pred(a)), None)
    if o['phase'] in ('navigation','preparation','aftermath') and not o.get('tutorial_operation'):
        install = first('install', lambda a: hand.get(a['args'].get('uid'),{}).get('id')=='fishingNet')
        if install:
            return install
        if {'lamp','filter','planter'} <= devices and 'fishingNet' not in devices:
            craft = first('craft', lambda a: a['args'].get('id')=='fishingNet')
            if craft and any(c['status']=='intact' and not c['equipment'] for c in o['cells']):
                return craft
    if o['phase']=='battle' and o['battle']['ap']>=2:
        shields=sum(s['amount'] for s in o['battle'].get('shields',[]))
        if shields<o['battle'].get('enemy_direct_damage',0) and not any(c['id'] in ('wood','rope','plastic','iron') for c in hand.values()):
            salvage=first('salvage')
            if salvage:
                return salvage
    return player.choose_action(o,actions)

def run(game, mode, seed=22):
    o=data(game.request('reset',{'mode':mode,'seed':seed,'difficulty':'nightmare','origin':'strong'}))['observation']
    player=SmartPlayer(verbose=False)
    counts=Counter(); nets=0; battle_salvages=0
    for step in range(800):
        if o['terminal']:
            break
        nets=max(nets,sum(c['status']=='intact' and c['equipment'].get('id')=='fishingNet' for c in o['cells']))
        actions=data(game.request('actions'))['actions']
        a=choose(player,o,actions)
        assert a is not None, o['phase']
        counts[a['command']]+=1
        battle_salvages+=int(o['phase']=='battle' and a['command']=='salvage')
        o=data(game.request('act',{'action_id':a['action_id'],'revision':o['revision']}))['observation']
    result=data(game.request('result')); assert result['terminal'], 'step limit'
    trace=data(game.request('trace'))
    path=ROOT/'evidence'/f'expansion-v15-play-{mode}-{seed}.trace.json'
    path.write_text(json.dumps(trace,ensure_ascii=False),encoding='utf-8')
    replay=data(game.request('replay',{'trace':json.loads(path.read_text(encoding='utf-8'))}))
    assert replay['steps']==len(trace['steps'])
    return {'mode':mode,'seed':seed,'difficulty':'nightmare','outcome':result['outcome'],'phase':result['phase'],'completed':result['completed'],'battle_salvages':battle_salvages,'max_intact_nets':nets,'steps':len(trace['steps']),'replayed':replay['steps'],'commands':dict(counts),'trace':path.name}

if __name__=='__main__':
    rows=[]
    with AgentClient() as game:
        for mode in ('challenge','story'):
            row=run(game,mode); rows.append(row); print(json.dumps(row,ensure_ascii=False),flush=True)
        assert not game.errors,list(game.errors)
    (ROOT/'evidence/expansion-v15-play.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
