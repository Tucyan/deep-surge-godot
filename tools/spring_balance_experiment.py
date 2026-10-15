"""Isolated paired spring experiment. Never changes the live project's rules."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import shutil
from agent_client import AgentClient, data
from health_playtest import choose as survival_choose

ROOT=Path(__file__).resolve().parents[1]
LAB=ROOT.parent/'tmp/spring-wood-experiment'
OUT=ROOT/'evidence/spring-wood-experiment'
VARIANTS={'random3':0,'wood1-random2':1,'wood2-random2':2,'wood1-other3':1,'wood1-random3':1}
RECIPES=json.loads((ROOT/'content/data/recipes.json').read_text(encoding='utf-8'))
GOALS=[('filter',1),('planter',1),('lamp',1),('crossbow',1),('filter',2),('planter',2),('fishingNet',1),('crate',1)]


def prepare(variant):
    target=LAB/variant
    target.mkdir(parents=True,exist_ok=True)
    for folder in ('core','content','adapters'):
        shutil.copytree(ROOT/folder,target/folder,dirs_exist_ok=True)
    # Keep the published comparison reproducible after adopting a new live rule.
    archived=OUT/'source'
    for folder in ('core','content'):
        if (archived/folder).exists(): shutil.copytree(archived/folder,target/folder,dirs_exist_ok=True)
    (target/'tools').mkdir(exist_ok=True)
    shutil.copy2(ROOT/'tools/agent_stdio.gd',target/'tools/agent_stdio.gd')
    (target/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Spring experiment"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
    p=target/'core/run_rules.gd'; text=p.read_text(encoding='utf-8')
    original='for i in range(3): ctx.give(R.pick(s.rng,"initial",I.RESOURCES),1,false,"spring")'
    assert text.count(original)==1
    fixed=VARIANTS[variant]
    replacement='var experimental_draws: Array=[]\n\tfor i in range(3): experimental_draws.append(R.pick(s.rng,"initial",I.RESOURCES))\n'
    if variant=='wood1-random3':
        replacement='ctx.give("wood",1,false,"spring")\n\tfor i in range(3): ctx.give(R.pick(s.rng,"initial",I.RESOURCES),1,false,"spring")'
    elif variant=='wood1-other3':
        replacement='ctx.give("wood",1,false,"spring")\n\tfor i in range(3): ctx.give(R.pick(s.rng,"initial",["iron","plastic","rope","cloth"]),1,false,"spring")'
    elif fixed:
        replacement+=f'\tctx.give("wood",{fixed},false,"spring")\n\tfor i in range(2): ctx.give(experimental_draws[i],1,false,"spring")'
    else:
        replacement+='\tfor item in experimental_draws: ctx.give(item,1,false,"spring")'
    p.write_text(text.replace(original,replacement),encoding='utf-8')
    return target


def tasks(o):
    devices={}
    cards=Counter(c['id'] for c in o['hand'])
    for c in o['cells']:
        if c['status']=='intact' and c['equipment']:
            d=c['equipment']; devices[d['id']]=max(devices.get(d['id'],0),d['level'])
    empty=any(c['status']=='intact' and not c['equipment'] for c in o['cells'])
    result=[]; seen=set()
    for id,level in GOALS:
        current=devices.get(id,0)
        if current>=level or id in seen: continue
        seen.add(id)
        if current==0 and cards[id]:
            result.append({'id':id,'op':'install' if empty else 'expand','costs':{} if empty else {'wood':2},'ap':0 if empty else 1})
        elif current==0:
            result.append({'id':id,'op':'craft' if empty else 'expand','costs':RECIPES[id]['ingredients'] if empty else {'wood':2},'ap':1})
        else:
            result.append({'id':id,'op':'upgrade','costs':RECIPES[id]['ingredients'],'ap':1 if cards[id] else 2})
    return result


def choose(o,actions,policy):
    selected=survival_choose(o,actions,'careful','scholar')
    # Preserve teaching AP before arriving at fixed tutorial nodes. Building before
    # arrival spends the same AP needed by the mandatory day-two craft/upgrade.
    if o['mode']=='story' and o['phase']=='navigation' and o['voyage']<=3:
        if selected and selected['command']=='play': return selected
        return next((a for a in actions if a['command']=='voyage'),None)
    if policy=='survival': return selected
    phase=o['phase']; cards={c['uid']:c for c in o['hand']}; counts=Counter(c['id'] for c in o['hand'])
    def first(command,predicate=lambda a:True):
        return next((a for a in actions if a['command']==command and predicate(a)),None)
    # All combat/story/navigation choices and survival consumables remain the same.
    if phase not in ('navigation','preparation','aftermath') or o.get('tutorial_operation'):
        return selected
    if selected and selected['command'] in ('play','repair_cell','fuel'): return selected
    if o['player']['hp']<=6 and counts['medkit']==0:
        a=first('craft',lambda a:a['args']['id']=='medkit')
        if a:return a
    a=first('install',lambda a: cards[a['args']['uid']]['id'] in dict(GOALS))
    if a:return a
    work=tasks(o)
    for task in work:
        if task['op']=='expand':
            a=first('expand')
        elif task['op']=='craft':
            a=first('craft',lambda a:a['args']['id']==task['id'])
        elif task['op']=='upgrade':
            cells={c['id'] for c in o['cells'] if c['equipment'].get('id')==task['id'] and c['equipment']['level']==1}
            a=first('upgrade',lambda a:a['args'].get('cell') in cells)
        else:a=None
        if a:return a
    # Use the existing 3->2 conversion when the next build needs only wood.
    if work and counts['wood']<work[0]['costs'].get('wood',0) and sum(counts[x] for x in ('iron','plastic','rope','cloth'))>=4:
        a=first('transmute',lambda a:a['args'].get('target')=='wood')
        if a:return a
    if phase=='aftermath' and work and o['capacity']<o['player']['limit']:
        a=first('salvage')
        if a:return a
    # Do not accidentally inherit the four-cell construction order after custom work.
    return first('enter' if phase=='preparation' else 'end_voyage') if phase!='navigation' else next((a for a in actions if a['action_id']==selected['action_id']),None)


def discard_choose(o,actions,policy):
    if policy!='builder' or o['phase']!='discard': return None
    cards={c['uid']:c for c in o['hand']}; counts=Counter(c['id'] for c in o['hand'])
    def value(a):
        id=cards.get(a['args']['uid'],{}).get('id')
        if id in ('food','water'):return 95
        if id=='medkit':return 90 if o['player']['hp']<8 else 55
        if id=='wood':return 15 if counts[id]>4 else 85
        if id=='plastic':return 20 if counts[id]>4 else 65
        if id=='cloth':return 20 if counts[id]>3 else 70
        if id in ('iron','rope'):return 20 if counts[id]>3 else 60
        return 10
    return min((a for a in actions if a['command']=='discard'),key=value)


def checkpoint(o,policy):
    counts=Counter(c['id'] for c in o['hand']); work=tasks(o)
    if policy=='survival':work=[t for t in work if t['id'] in ('filter','planter','lamp','crossbow') and t['op']!='expand']
    usable=[t for t in work if t['ap']<=o['ap'] and t['costs']]
    wood_only=[t for t in usable if counts['wood']<t['costs'].get('wood',0) and all(counts[k]>=v for k,v in t['costs'].items() if k!='wood')]
    other=[t for t in usable if counts['wood']>=t['costs'].get('wood',0) and any(counts[k]<v for k,v in t['costs'].items() if k!='wood')]
    mixed=[t for t in usable if counts['wood']<t['costs'].get('wood',0) and any(counts[k]<v for k,v in t['costs'].items() if k!='wood')]
    return {'voyage':o['voyage'],'wood':counts['wood'],'ap':o['ap'],'pending':work,'wood_only':bool(wood_only),'other_only':bool(other),'mixed':bool(mixed),'devices':{c['equipment']['id']:c['equipment']['level'] for c in o['cells'] if c['status']=='intact' and c['equipment']},'cells':sum(c['status']!='detached' for c in o['cells'])}


def run(game,variant,policy,seed,mode='challenge'):
    o=data(game.request('reset',{'seed':seed,'origin':'fool','mode':mode}))['observation']
    counts=Counter(); departures=[]; spring=[]; current_spring=[]; builds=[]; wood_costs=Counter()
    initial=[c['id'] for c in o['hand']]; max_capacity=0
    for step in range(850):
        if o['terminal']:break
        actions=data(game.request('actions'))['actions']
        a=discard_choose(o,actions,policy) or choose(o,actions,policy)
        if a is None:raise RuntimeError(f'No action {variant} {seed} {o["phase"]}')
        before=o
        if a['command']=='voyage':departures.append(checkpoint(o,policy))
        result=data(game.request('act',{'action_id':a['action_id'],'revision':o['revision']}))
        o=result['observation'];counts[a['command']]+=1; max_capacity=max(max_capacity,o['capacity'])
        if a['command'] in ('craft','install','upgrade','expand'):builds.append({'voyage':before['voyage'],'command':a['command'],'args':a['args']})
        current_spring=[]
        for event in result['events']:
            if event.get('kind')!='card':continue
            if event.get('id')=='wood' and event.get('field')=='cost_consumed':wood_costs[event.get('reason','')]+=event.get('amount',0)
            if event.get('field')=='obtained' and event.get('reason')=='spring':current_spring.extend([event['id']]*event['amount'])
        if current_spring:spring.append({'voyage':o['voyage'],'cards':current_spring})
    if not o['terminal']:raise RuntimeError(f'850 step limit {variant}/{seed}; no retry')
    final=data(game.request('result')); report=final['report']; resource_rows={r['id']:r for r in report['cards'] if r['id'] in ('wood','iron','plastic','rope','cloth')}
    label=f'{variant}-{policy}-{mode}-{seed}'
    summary={'variant':variant,'policy':policy,'mode':mode,'seed':seed,'outcome':final['outcome'] or final['phase'],'completed':final['completed'],'length':o['length'],'hp':o['player']['hp'],'spring_rounds':len(spring),'wood_from_spring':sum(s['cards'].count('wood') for s in spring),'other_from_spring':sum(sum(c!='wood' for c in s['cards']) for s in spring),'wood_only_departures':sum(c['wood_only'] for c in departures),'other_only_departures':sum(c['other_only'] for c in departures),'mixed_departures':sum(c['mixed'] for c in departures),'departures':len(departures),'expansions':counts['expand'],'crafts':counts['craft'],'upgrades':counts['upgrade'],'transmutes':counts['transmute'],'salvages':counts['salvage'],'discards':counts['discard'],'wood_discarded':resource_rows.get('wood',{}).get('discarded',0),'all_resource_discarded':sum(r.get('discarded',0) for r in resource_rows.values()),'wood_obtained':resource_rows.get('wood',{}).get('obtained',0),'wood_remaining':resource_rows.get('wood',{}).get('remaining',0),'wood_costs':dict(wood_costs),'devices_by_round5':next((x['devices'] for x in departures if x['voyage']==5),{}),'devices_end':{c['equipment']['id']:c['equipment']['level'] for c in o['cells'] if c['status']=='intact' and c['equipment']},'max_capacity':max_capacity,'first_four_devices':next((x['voyage'] for x in departures if all(id in x['devices'] for id in ('filter','planter','lamp','crossbow'))),None)}
    path=OUT/variant;path.mkdir(parents=True,exist_ok=True)
    (path/f'{policy}-{mode}-{seed}.json').write_text(json.dumps({'summary':summary,'initial':initial,'checkpoints':departures,'spring':spring,'builds':builds,'report':report,'trace':data(game.request('trace'))},ensure_ascii=False),encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=False),flush=True)
    if game.errors:raise RuntimeError('\n'.join(game.errors))
    return summary


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--variant',choices=list(VARIANTS),required=True);ap.add_argument('--seeds',nargs='+',type=int,default=[0,7,22,42,20261015,987654321,2147483647,4294967295]);ap.add_argument('--policies',nargs='+',default=['survival','builder']);ap.add_argument('--mode',default='challenge');args=ap.parse_args()
    before=hashlib.sha256((ROOT/'core/run_rules.gd').read_bytes()).hexdigest()
    project=prepare(args.variant)
    with AgentClient(project=project) as game:
        for policy in args.policies:
            for seed in args.seeds:run(game,args.variant,policy,seed,args.mode)
    assert hashlib.sha256((ROOT/'core/run_rules.gd').read_bytes()).hexdigest()==before,'Live spring source changed'
