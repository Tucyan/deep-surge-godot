"""Repeatable public-action playthroughs for health-12-v1; no state injection."""
import argparse
from collections import Counter
import json
from pathlib import Path
from agent_client import AgentClient, data

ROOT = Path(__file__).resolve().parents[1]


def choose(o, actions, style, route):
    def first(command, predicate=lambda a: True):
        return next((a for a in actions if a['command'] == command and predicate(a)), None)
    def arg(command, key, value):
        return first(command, lambda a: a['args'].get(key) == value)
    p, phase = o['player'], o['phase']
    cards = {c['uid']: c for c in o['hand']}
    counts = Counter(c['id'] for c in o['hand'])
    devices = {c['equipment'].get('id') for c in o['cells'] if c['status'] == 'intact'}
    # Save medkits until at least three HP can be restored; food/water before travel.
    for a in actions:
        if a['command'] != 'play' or not a['effective']: continue
        c = cards[a['args']['uid']]
        if c['definition']['kind'] != 'survival': continue
        if c['id'] != 'medkit' or p['hp_max']-p['hp'] >= 3 or p['hp'] <= 3:
            return a
    if phase in ('navigation', 'preparation', 'aftermath'):
        tutorial = o.get('tutorial_operation')
        if tutorial:
            a = first(tutorial, lambda a: tutorial != 'craft' or a['args'].get('id') == 'filter')
            if a: return a
        a = first('install', lambda a: cards[a['args']['uid']]['id'] in ('crossbow','filter','planter','lamp'))
        if a: return a
        # Keep essential production working; fuel only one voyage in advance.
        for cell in o['cells']:
            if cell['status']=='damaged' and cell['equipment']:
                a=arg('repair_cell','cell',cell['id'])
                if a: return a
            if cell['status']=='intact' and cell['equipment'].get('id')=='lamp' and cell['equipment']['fuel']==0:
                a=first('fuel',lambda a: a['args']['cell']==cell['id'] and a['args']['material']=='corpse')
                if not a and counts['wood']>1: a=arg('fuel','cell',cell['id'])
                if a: return a
        if p['hp']<=6 and not counts['medkit']:
            a=arg('craft','id','medkit')
            if a: return a
        # Four initial cells force a choice of production, light and battle equipment.
        for device in ('crossbow','filter','planter','lamp'):
            if device in devices or counts[device]: continue
            if not any(c['status']=='intact' and not c['equipment'] for c in o['cells']): continue
            a=arg('craft','id',device)
            if a: return a
        for cell in o['cells']:
            if cell['status']=='intact' and cell['equipment'].get('id') in ('filter','planter') and cell['equipment']['level']==1:
                a=first('upgrade',lambda a: a['args'].get('cell')==cell['id'])
                if a: return a
        if phase=='navigation':
            def score(n):
                if n['id']=='camp': return 100
                if n.get('boss'): return 90
                if n.get('monster'): return 40 if style=='risk' and p['hp']>=6 else -10
                return 20
            node=max(o['candidates'],key=score)
            return arg('voyage','id',node['visit_id'])
        if phase=='aftermath' and o['ap']>0 and o['capacity']<p['limit'] and counts['wood']+counts['plastic']+counts['cloth']<5:
            a=first('salvage')
            if a: return a
        return first('enter' if phase=='preparation' else 'end_voyage')
    if phase=='story':
        a=first('advance')
        if a: return a
        scene=o.get('scene',{})
        if scene.get('id')=='ST.L1.S04': return arg('option','id',route)
        if scene.get('id')=='ST.L1.F15':
            return arg('option','id','seal') or arg('option','id','tow') or arg('option','id','release')
        if o['node'].get('monster'):
            if o['node'].get('boss') or scene.get('combat') or (style=='risk' and p['hp']>=6): return first('fight')
            return first('leave_encounter')
        return arg('option','id','rest') or first('option') or first('shop_enter')
    if phase=='battle':
        a=first('play',lambda a: cards[a['args']['uid']]['id'] in ('arrow','spear'))
        if a: return a
        pollution=counts['pollution']
        if pollution:
            a=first('play',lambda a: cards[a['args']['uid']]['id']=='pollution')
            if a: return a
        # A single wood block can cover a dangerous hit. Keep the other AP for damage.
        enemy=o['enemy']; shields=sum(s['amount'] for s in o['battle'].get('shields',[]))
        if o['battle']['ap']==1 and shields<enemy['damage'] and o['battle']['hp']>1:
            a=first('battle_action',lambda a: a['args'].get('action')=='block' and cards.get(a['args'].get('resource_uid'),{}).get('id')=='wood')
            if a: return a
        a=first('battle_action',lambda a: a['args'].get('action')=='block' and cards.get(a['args'].get('resource_uid'),{}).get('id')=='cloth') if o['battle']['poison_until']>=o['battle']['turn'] else None
        if a: return a
        a=first('battle_action',lambda a: a['args'].get('action')=='attack' and cards.get(a['args'].get('resource_uid'),{}).get('id')=='iron')
        return a or first('battle_action',lambda a:a['args']=={'action':'attack'}) or first('battle_end')
    if phase=='nightHub':
        if first('night_action'):
            if route=='scholar' and p['hp']>6 and p['sanity']>=65 and p['hunger']>=40 and p['hydration']>=40:
                a=first('night_action',lambda a:a['args']['id']!='rest')
                if a: return a
            return arg('night_action','id','rest')
        return first('night_actions') or first('night_ack') or first('finish_night')
    if phase=='discard':
        def value(a):
            c=cards.get(a['args']['uid'],{}); id=c.get('id')
            if id=='medkit': return 100 if p['hp']<8 else 25
            if id in ('food','water'): return 90
            if id=='wood': return 80
            if id=='cloth': return 60
            if id=='rope': return 50
            if id=='coin': return 40
            return 10
        return min((a for a in actions if a['command']=='discard'),key=value)
    if phase=='interaction': return first('shop_leave')
    return None


def run(game, seed, origin, mode, style, route, out):
    o=data(game.request('reset',{'seed':seed,'origin':origin,'mode':mode}))['observation']
    minimum=o['player']['hp']; counts=Counter(); events=[]; history=[]
    for step in range(700):
        if o['terminal']: break
        actions=data(game.request('actions'))['actions']
        a=choose(o,actions,style,route)
        if not a: raise RuntimeError(f'No legal decision: {mode} {seed} {o["phase"]}')
        previous=o
        result=data(game.request('act',{'action_id':a['action_id'],'revision':o['revision']}))
        o=result['observation']; counts[a['command']]+=1
        minimum=min(minimum,o['player']['hp'])
        if o['player']['hp']!=previous['player']['hp']:
            events.append({'step':step,'voyage':o['voyage'],'phase':previous['phase'],'command':a['command'],'before':previous['player']['hp'],'after':o['player']['hp'],'args':a['args']})
        if previous['phase']=='navigation' or a['command']=='night_action':
            history.append({'step':step,'voyage':previous['voyage'],'hp':previous['player']['hp'],'sanity':previous['player']['sanity'],'command':a['command'],'args':a['args']})
    if not o['terminal']: raise RuntimeError('700 step limit reached; no retry')
    final=data(game.request('result'))
    trace=data(game.request('trace'))
    label=f'{mode}-{origin}-{seed}-{style}-{route}'
    (out/f'{label}.json').write_text(json.dumps({'final':final,'minimum_hp':minimum,'counts':dict(counts),'health_events':events,'decisions':history,'trace':trace},ensure_ascii=False),encoding='utf-8')
    summary={'case':label,'outcome':final['outcome'] or final['phase'],'completed':final['completed'],'voyage':o['voyage'],'hp':o['player']['hp'],'hp_max':o['player']['hp_max'],'minimum_hp':minimum,'battles':counts['fight'],'steps':step,'heals':sum(e['after']>e['before'] for e in events)}
    print(json.dumps(summary,ensure_ascii=False),flush=True)
    if game.errors: raise RuntimeError('\n'.join(game.errors))
    return summary


if __name__=='__main__':
    ap=argparse.ArgumentParser(); ap.add_argument('--seeds',nargs='+',type=int,default=[0,1,2,22]); ap.add_argument('--mode',default='challenge'); ap.add_argument('--origins',nargs='+',default=['fool','strong']); ap.add_argument('--style',default='careful'); ap.add_argument('--route',default='scholar'); args=ap.parse_args()
    out=ROOT/'evidence/health-playtests'; out.mkdir(exist_ok=True)
    summaries=[]
    with AgentClient() as game:
        for origin in args.origins:
            for seed in args.seeds: summaries.append(run(game,seed,origin,args.mode,args.style,args.route,out))
    (out/f'summary-{args.mode}-{args.style}-{args.route}.json').write_text(json.dumps(summaries,ensure_ascii=False,indent=2),encoding='utf-8')
