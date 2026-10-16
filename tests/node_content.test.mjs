import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const read = name => JSON.parse(readFileSync(new URL(`../content/data/${name}.json`, import.meta.url), 'utf8'));
const nodes = read('nodes');
const entries = Object.values(nodes).flatMap(node => node.variants ?? [node]);
const event = id => entries.find(node => node.event === id);
const option = (id, choice) => event(id).options.find(o => o.id === choice);
const card = (id, amount=1) => ({type:'GiveCard',id,amount});

test('十二事件整合旧节点，旧入口保留而祭坛明确退池', () => {
  for(let n=1;n<=12;n++) assert.equal(entries.filter(x=>x.event===`E${String(n).padStart(2,'0')}`).length,1);
  assert.deepEqual(nodes.drift.variants.map(x=>[x.id,x.event]), [['salvage','E01'],['sealed','E05'],['lostBag','E04'],['cargo','E03']]);
  assert.deepEqual(nodes.storm.variants.map(x=>[x.id,x.event]), [['surface','E12'],['hold','E10']]);
  assert.equal(nodes.jelly.event,'E06');
  assert.equal(nodes.altar.retired,true);
  assert.deepEqual(nodes.altar.options.map(x=>x.id),['leave']);
  assert.equal(nodes.fallback.fallback,true);
  assert.ok(nodes.fallback.options.every(x=>x.effects.length===0 && x.cost===0));
  for(const id of ['battle','jellyBattle','crabBattle','ruin','boss']) assert.ok(nodes[id].monster);
  assert.doesNotMatch(nodes.ruin.description,/藏品|日记/);
});

test('类别、轮次、次数和冷却均显式定义', () => {
  const categories = ['supply','trade','service','risk','battle','camp','shop'];
  for(const node of [...Object.values(nodes),...entries]) {
    for(const key of ['id','name','kind','description','event','category','min_voyage','max_visits','cooldown']) assert.ok(Object.hasOwn(node,key),`${node.id}.${key}`);
    assert.ok(categories.includes(node.category),node.id);
    assert.ok(node.min_voyage >= 1,node.id);
    assert.ok(node.max_visits >= 1,node.id);
    assert.ok(node.cooldown >= 1,node.id);
  }
  const limits = {E01:[1,1],E02:[1,1],E03:[1,1],E04:[1,1],E05:[3,1],E06:[3,1],E07:[1,1],E08:[3,1],E09:[4,1],E10:[5,1],E11:[4,1],E12:[5,1]};
  for(const [id,[min,max]] of Object.entries(limits)) {
    assert.equal(event(id).min_voyage,min,id); assert.equal(event(id).max_visits,max,id); assert.equal(event(id).cooldown,3,id);
  }
  assert.equal(nodes.camp.max_visits,1); assert.equal(nodes.trader.max_visits,2);
  for(const id of ['camp','trader']) assert.equal(nodes[id].cooldown,3);
});

test('免费收益与付费加码遵守确认数值', () => {
  assert.deepEqual(option('E01','wood').effects,[card('wood',2)]);
  assert.deepEqual(option('E01','metal').effects,[card('iron'),card('rope')]);
  assert.deepEqual(option('E01','provisions').effects,[card('plastic'),card('cloth')]);
  assert.deepEqual(event('E02').options.filter(x=>x.id!=='leave').map(x=>x.effects),[[card('food')],[card('water')],[card('calm')]]);
  assert.deepEqual(option('E03','wood').effects,[card('wood')]);
  assert.equal(option('E03','salvage').cost,1);
  assert.deepEqual(option('E03','net').conditions,{equipment:'fishingNet'});
  assert.deepEqual(option('E03','net').effects,[card('wood'),card('iron'),card('plastic')]);
  assert.equal(option('E04','exchange').operation,'exchange');
  assert.equal(option('E04','exchange').cost,0);
  assert.deepEqual(option('E06','listen').statCosts,{sanity:6});
  assert.deepEqual(option('E06','listen').effects,[card('iron'),card('rope')]);
  assert.deepEqual(option('E07','share').cardCosts,{wood:1});
  assert.deepEqual(option('E07','share').effects,[card('food'),card('water')]);
  assert.deepEqual(option('E08','repair').conditions,{target:'damaged_cell'});
  assert.deepEqual(option('E08','repair').effects,[{type:'RepairCell'}]);
  assert.deepEqual(option('E09','force').statCosts,{hp:2});
  assert.deepEqual(option('E09','force').effects,[{type:'ChangeAP',delta:3}]);
  assert.deepEqual(nodes.camp.options.find(x=>x.id==='rest').effects,[{type:'ChangeCurrent',stat:'hp',delta:4},{type:'ChangeCurrent',stat:'hunger',delta:20},{type:'ChangeCurrent',stat:'hydration',delta:20},{type:'ChangeCurrent',stat:'sanity',delta:20}]);
  assert.deepEqual(nodes.camp.options.find(x=>x.id==='rhythm').effects,[{type:'ChangeCurrent',stat:'sanity',delta:25},{type:'AddBuff',id:'rested'}]);
});

test('概率、目标格代价和事件战斗奖励明示并且不引入藏品', () => {
  const open=option('E05','open');
  assert.equal(open.cost,1); assert.equal(open.cardCosts,undefined);
  assert.deepEqual(open.outcomes.map(x=>x.weight),[70,30]);
  assert.deepEqual(open.outcomes[1].effects,[card('iron'),{type:'ChangeCurrent',stat:'hp',delta:-1}]);
  assert.match(open.description,/死亡/);
  const stages=event('E10').stages;
  assert.equal(stages.length,3);
  assert.equal(stages[0][0].next_stage,1);
  assert.deepEqual(stages[0][0].effects,[{type:'GiveRandomResource',amount:1}]);
  for(const [stage,weights,damage,amount] of [[1,[75,25],1,3],[2,[55,45],2,4]]) {
    const continuing=stages[stage].find(x=>x.id==='continue');
    assert.equal(continuing.cost,1); assert.deepEqual(continuing.outcomes.map(x=>x.weight),weights);
    assert.deepEqual(continuing.outcomes[0].effects,[{type:'GiveRandomResource',amount}]);
    assert.deepEqual(continuing.outcomes[1].effects,[{type:'ChangeCurrent',stat:'hp',delta:-damage}]);
    assert.match(continuing.description,/死亡/);
    assert.ok(stages[stage].some(x=>x.id==='leave'));
  }
  assert.equal(stages[1][0].outcomes[0].next_stage,2);
  assert.equal(stages[2][0].outcomes[0].next_stage,undefined);
  assert.deepEqual(option('E12','risk').conditions,{target:'empty_outer_cell',min_intact:2});
  assert.deepEqual(option('E12','risk').effects,[{type:'DamageTargetCell'},card('iron',3),card('wood'),card('plastic')]);
  assert.deepEqual(option('E12','secure').cardCosts,{rope:1});
  assert.deepEqual(option('E12','leave').effects,[{type:'SetFlag',key:'avoidWave',value:true}]);
  assert.deepEqual(option('E11','normal').battle,{enemy:'crab',rewards:{coin:1,corpse:1,resources:1,xp:5}});
  assert.deepEqual(option('E11','elite').battle,{enemy:'crab_elite',rewards:{coin:2,corpse:1,resources:2,xp:5}});
  assert.equal(option('E11','elite').min_voyage,7);
  assert.equal(read('enemies').crab_elite.hp,12); assert.equal(read('enemies').crab_elite.damage,2);
  assert.doesNotMatch(JSON.stringify(nodes),/relicChance|relicProbability|randomCardCost/);
});

test('主动风险及概率成败显式声明，安全选项不登记风险', () => {
  for(const node of entries) {
    const choices=node.stages ? node.stages.flat() : (node.options ?? []);
    for(const choice of choices) {
      const risky=(node.event==='E05' && choice.id==='open') || (node.event==='E10' && choice.id==='continue') || (node.event==='E12' && choice.id==='risk');
      assert.equal(choice.risk ?? false,risky,`${node.event}/${choice.id}`);
      if(risky && choice.outcomes) assert.deepEqual(choice.outcomes.map(x=>x.success),[true,false]);
    }
  }
  assert.equal(option('E12','risk').risk,true);
});
