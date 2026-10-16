import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from agent_client import AgentClient,data
ROOT=Path(__file__).resolve().parents[1]
game=AgentClient()
obs=data(game.request('reset',{'seed':22,'mode':'challenge','origin':'strong'}))['observation']
def show():
 global obs
 obs=data(game.request('observe'))
 actions=data(game.request('actions'))['actions']
 out={k:obs[k] for k in ['revision','phase','voyage','length','ap','player','coins','capacity','completed','terminal','story_step','result_text'] if k in obs}
 out['hand']=[{k:c[k] for k in ['uid','id','temporary'] if k in c} for c in obs['hand']]
 out['cells']=[{'id':c['id'],'status':c['status'],'equipment':c['equipment']} for c in obs['cells']]
 for k in ['candidates','node','enemy','battle','event_options','shop','boost_cards']:
  if obs.get(k):out[k]=obs[k]
 out['actions']=[{'cmd':a['command'],'args':a['args'],**({'effective':False} if not a['effective'] else {})} for a in actions if a['command']!='expand']
 (ROOT/"evidence/personal-play-current.json").write_text(json.dumps(out,ensure_ascii=False),encoding="utf-8")
 print("READY",obs["phase"],obs["voyage"],obs["revision"],flush=True)
show()
try:
 for line in sys.stdin:
  try:
   request=json.loads(line)
   if request.get('finish'):
    trace=data(game.request('trace'));result=data(game.request('result'))
    (ROOT/'evidence/personal-play-v11-challenge-22.trace.json').write_text(json.dumps(trace,ensure_ascii=False),encoding='utf-8')
    (ROOT/'evidence/personal-play-v11-challenge-22.result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    replay=data(game.request('replay',{'trace':trace}))
    print(json.dumps({'outcome':result['outcome'],'completed':result['completed'],'replayed':replay['steps'],'stderr':list(game.errors)},ensure_ascii=False),flush=True);break
   for action in request.get('do',[]):
    actions=data(game.request('actions'))['actions'];args=action.get('args',{})
    choices=[a for a in actions if a['command']==action['cmd'] and a['args']==args]
    if not choices:raise ValueError('No exact legal action '+str(action))
    obs=data(game.request('act',{'action_id':choices[0]['action_id'],'revision':obs['revision'],'arguments':action.get('arguments',{})}))['observation']
   show()
  except Exception as e: print(json.dumps({'error':str(e)},ensure_ascii=False),flush=True);show()
finally:game.close()
