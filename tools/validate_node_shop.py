"""Public-observation heuristic smoke runs for v10; not a balance study or LLM turn-by-turn play."""
import sys,json
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(PROJECT/'tools'))
from agent_client import AgentClient,data,choose_action

def decide(o,actions):
 def first(cmd,p=lambda a:True): return next((a for a in actions if a['command']==cmd and p(a)),None)
 hand={c['uid']:c for c in o['hand']}
 counts={}
 for c in hand.values(): counts[c['id']]=counts.get(c['id'],0)+1
 devices={c['equipment'].get('id'):c['equipment'] for c in o['cells'] if c['status']=='intact' and c['equipment']}
 if o['phase'] in ['navigation','preparation','aftermath']:
  play=first('play',lambda a:a['effective'])
  if play:return play
  if not o.get('tutorial_operation'):
   fuel=first('fuel',lambda a:a['args'].get('material')=='corpse' and devices.get('lamp',{}).get('fuel',0)<1) or first('fuel',lambda a:a['args'].get('material')=='wood' and devices.get('lamp',{}).get('fuel',0)<1)
   if fuel:return fuel
   for item in ['lamp','filter','planter','crossbow']:
    if item not in devices:
     install=first('install',lambda a:hand.get(a['args'].get('uid'),{}).get('id')==item)
     if install:return install
     craft=first('craft',lambda a:a['args'].get('id')==item)
     if craft:return craft
   repair=first('repair_cell',lambda a:any(c['id']==a['args'].get('cell') and c['equipment'] for c in o['cells']))
   if repair:return repair
   upgrade=first('upgrade',lambda a:a['args'].get('craft') and any(c['id']==a['args'].get('cell') and c['equipment'].get('id') in ['filter','planter'] for c in o['cells']))
   if upgrade:return upgrade
 if o['phase']=='story' and o['story_step']=='choice' and not o.get('scene'):
  opts={x['id']:x for x in o.get('event_options',[])}
  def card_value(id):
   if id=='food':return 1+min(3,(o['player']['hunger_max']-o['player']['hunger'])/20)
   if id=='water':return 1+min(3,(o['player']['hydration_max']-o['player']['hydration'])/20)
   if id=='calm':return 1+min(3,(o['player']['sanity_max']-o['player']['sanity'])/20)
   if id=='wood':return 1.4+(2 if counts.get(id,0)<2 else 0)
   if id=='plastic':return 1+(2 if ('filter' not in devices or 'planter' not in devices) and counts.get(id,0)<3 else 0)
   return 1.0
  def score(a):
   opt=opts.get(a['args'].get('id'),{})
   r=opt.get('preview',{})
   n=sum(card_value(k)*v for k,v in r.get('cards',{}).items())+r.get('random_resources',0)*1.5+r.get('ap',0)*1.2
   for stat,delta in r.get('attributes',{}).items(): n+=min(max(0,delta),o['player'][stat+'_max']-o['player'][stat])/(2 if stat=='hp' else 15)
   if r.get('rested'):n+=2
   if r.get('repair'):n+=4
   n-=opt.get('cost',0)*1.2+sum(card_value(k)*v for k,v in opt.get('cardCosts',{}).items())
   n-=sum(v/(1.5 if k=='hp' else 10) for k,v in opt.get('statCosts',{}).items())
   if a['args'].get('target'):n+=2*card_value(a['args']['target'])-card_value(hand[a['args']['input_uid']]['id'])
   if opt.get('risk'):n-=4
   if opt.get('battle'):n-=10
   return n
  options=[a for a in actions if a['command']=='option']
  if options:return max(options,key=score)
 return choose_action(o,actions)

if __name__=='__main__':
 records=[]
 for mode,seed in [('challenge',22),('challenge',0),('story',22)]:
  with AgentClient() as game:
   o=data(game.request('reset',{'seed':seed,'mode':mode}))['observation']
   for step in range(650):
    if o['terminal']:break
    actions=data(game.request('actions'))['actions'];a=decide(o,actions)
    if a is None:raise RuntimeError('No action '+o['phase'])
    o=data(game.request('act',{'action_id':a['action_id'],'revision':o['revision']}))['observation']
   result=data(game.request('result'));trace=data(game.request('trace'))
   path=(PROJECT/'evidence')/f'node-shop-{mode}-{seed}.trace.json'
   path.write_text(json.dumps(trace,ensure_ascii=False),encoding='utf-8')
   replay=data(game.request('replay',{'trace':trace}))
   row={k:v for k,v in result.items() if k!='report'};row.update(seed=seed,mode=mode,steps=len(trace['steps']),replayed=replay['steps'],errors=list(game.errors),trace=path.name)
   records.append(row);print(json.dumps(row,ensure_ascii=False),flush=True)
 (PROJECT/'evidence/node-shop-agent-runs.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
