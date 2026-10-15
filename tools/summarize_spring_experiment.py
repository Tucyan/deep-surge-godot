"""Validate paired supplies and summarize the isolated wood-spring experiments."""
from collections import defaultdict
import hashlib
import json
from pathlib import Path
from statistics import mean

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'evidence/spring-wood-experiment'
SCENARIOS={'random3':0,'wood1-random2':1,'wood2-random2':2,'wood1-other3':1,'wood1-random3':1}


def summarize():
    samples={}
    for variant,fixed in SCENARIOS.items():
        for p in sorted((OUT/variant).glob('*.json')):
            d=json.loads(p.read_text(encoding='utf-8')); s=d['summary']
            assert s['variant']==variant
            assert len(d['initial'])==7
            for spring in d['spring']:
                assert len(spring['cards'])==(4 if fixed==2 or variant in ('wood1-other3','wood1-random3') else 3),(p,spring)
                assert spring['cards'].count('wood')>=fixed
                if variant=='wood1-other3': assert spring['cards'].count('wood')==1
            s['devices_round5']=len(d['summary']['devices_by_round5'])
            s['six_devices_end']=all(id in s['devices_end'] for id in ('filter','planter','lamp','crossbow','fishingNet','crate'))
            s['full_build_end']=s['six_devices_end'] and s['devices_end'].get('filter',0)>=2 and s['devices_end'].get('planter',0)>=2
            s['first_expansion']=next((b['voyage'] for b in d['builds'] if b['command']=='expand'),None)
            s['lamp_burns']=sum(device['uses'] for device in d['report']['stats']['devices'].values() if device['id']=='lamp')
            samples[(variant,s['policy'],s['mode'],s['seed'])]=d
    pairs=0
    for (variant,policy,mode,seed),sample in samples.items():
        if variant=='random3':continue
        baseline=samples.get(('random3',policy,mode,seed))
        assert baseline is not None,(variant,policy,mode,seed)
        assert sample['initial']==baseline['initial'],'Initial hands changed'
        assert sample['trace']['initial']['state']['rng']==baseline['trace']['initial']['state']['rng'],'Initial RNG changed'
        base={x['voyage']:x['cards'] for x in baseline['spring']}
        rng=int(sample['trace']['initial']['state']['rng']['initial']['value'])
        for spring in sample['spring']:
            others=[]
            for _ in range(3):
                rng=(rng ^ (rng<<13)) & 0xffffffff
                rng=(rng ^ (rng>>17)) & 0xffffffff
                rng=(rng ^ (rng<<5)) & 0xffffffff
                others.append(['iron','plastic','rope','cloth'][int(rng/4294967296*4)])
            if spring['voyage'] in base:
                expected=['wood']+others if variant=='wood1-other3' else (['wood']+base[spring['voyage']] if variant=='wood1-random3' else ['wood']*SCENARIOS[variant]+base[spring['voyage']][:2])
                assert spring['cards']==expected,(variant,seed,spring)
                pairs+=1
    grouped=defaultdict(list)
    for sample in samples.values():
        s=sample['summary'];grouped[(s['variant'],s['policy'],s['mode'])].append(s)
    table=[]
    metrics=['wood_only_departures','other_only_departures','mixed_departures','expansions','crafts','upgrades','transmutes','salvages','discards','wood_discarded','all_resource_discarded','wood_remaining','wood_from_spring','other_from_spring','wood_obtained','devices_round5','lamp_burns']
    for key,rows in sorted(grouped.items()):
        r={'variant':key[0],'policy':key[1],'mode':key[2],'cases':len(rows),'wins':sum(s['outcome'] in ('survived','chapterComplete') for s in rows)}
        r.update({m:round(mean(s[m] for s in rows),3) for m in metrics})
        r['six_devices_end_cases']=sum(s['six_devices_end'] for s in rows)
        r['full_build_end_cases']=sum(s['full_build_end'] for s in rows)
        r['first_expansion_mean']=round(mean(s['first_expansion'] for s in rows if s['first_expansion'] is not None),3) if any(s['first_expansion'] is not None for s in rows) else None
        r['four_devices_cases']=sum(s['first_four_devices'] is not None for s in rows)
        r['four_devices_round_conditional_mean']=round(mean(s['first_four_devices'] for s in rows if s['first_four_devices'] is not None),3) if r['four_devices_cases'] else None
        r['wood_only_departure_rate']=round(sum(s['wood_only_departures'] for s in rows)/sum(s['departures'] for s in rows),4)
        r['other_only_departure_rate']=round(sum(s['other_only_departures'] for s in rows)/sum(s['departures'] for s in rows),4)
        table.append(r)
    meta=json.loads((OUT/'method.json').read_text(encoding='utf-8'))
    for name,digest in meta['source_hashes'].items():
        archived=OUT/'source'/name
        source=archived if archived.exists() else ROOT/name
        assert hashlib.sha256(source.read_bytes()).hexdigest()==digest,'Experiment source changed: '+name
    result={'samples':len(samples),'paired_springs_checked':pairs,'rows':table,'cases':[d['summary'] for d in samples.values()]}
    (OUT/'summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for row in table:print(json.dumps(row,ensure_ascii=False))
    print(f'PAIRED VALIDATION: PASS ({pairs} spring pairs, {len(samples)} full playthroughs)')


if __name__=='__main__':summarize()
