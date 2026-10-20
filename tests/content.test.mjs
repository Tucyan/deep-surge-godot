import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {CARDS} from '../../玩法实验/src/content/cards.js';
import {NODES, MONSTERS} from '../../玩法实验/src/content/nodes.js';
import {EQUIPMENT, RECIPES} from '../../玩法实验/src/content/equipment.js';
import {META_SHOP, TECH} from '../../玩法实验/src/content/relics.js';

const read = table => JSON.parse(readFileSync(new URL(`../content/data/${table}.json`, import.meta.url), 'utf8'));

// The original lab remains a historical source. Godot now has explicitly approved
// revisions; assert those revisions instead of pretending the two games match.
for (const [table, source] of Object.entries({meta_shop:META_SHOP})) {
  test(`${table}: 历史内容与health-12-v1修订`, () => {
    const expected=structuredClone(source);
    if(table==='meta_shop') { expected.body.modifiers.hpMax=2; expected.body.description='永久生命上限+2，饱食、水分、精神上限各+5。'; }
    if(table==='relics') { expected.guardian.modifiers.hpMax=2; expected.guardian.description='生命上限+2。'; }
    const actual=read(table);
    assert.deepEqual(table==='relics' ? Object.fromEntries(Object.keys(source).map(id=>[id,actual[id]])) : actual,expected);
  });
}

test('v27二十件新藏品完整替换旧案且使用已实现效果', () => {
  const relics=read('relics');
  const enabled=Object.entries(relics).filter(([,d])=>d.enabled);
  assert.equal(enabled.length,20);
  assert.equal(Object.keys(relics).length,20);
  for(const id of ['rationTin','lifeboatTag','fittersBadge','spearParcel','borrowedPulse','luckyKnot']) assert.ok(!relics[id],id);
  const supported=new Set(['grant_max','restore','modifier','grant_card','install_level','temporary_max','probability']);
  for(const [id,d] of enabled) {
    assert.ok(Number.isInteger(d.price)&&d.price>0,id);
    assert.ok(d.effects.length>0,id);
    assert.equal(new Set(d.effects.map(e=>e.key)).size,d.effects.length,id);
    for(const effect of d.effects) assert.ok(supported.has(effect.type),effect.type);
  }
  assert.ok(relics.crimsonVial.effects.some(e=>e.type==='grant_max'));
  assert.ok(relics.crimsonVial.effects.some(e=>e.target==='survival.hydration_cost'));
  assert.equal(relics.foldingRule.effects[0].uses,1);
});

test('v22科技为两层六节点，第一层任意两点开放第二层', () => {
  const tech=read('tech');
  assert.deepEqual(Object.keys(tech),['knowledge','endurance','craft','spear','vitality','tactics']);
  assert.deepEqual(Object.values(tech).map(n=>n.price),[3,4,6,9,10,12]);
  assert.deepEqual(Object.values(tech).map(n=>n.tier),[1,1,1,2,2,2]);
  for(const node of Object.values(tech)) {
    assert.equal(node.required_previous,node.tier===1?0:2);
    assert.deepEqual(node.requires,[]);
  }
  for(const id of ['knowledge','endurance','craft']) assert.deepEqual(tech[id].modifiers,TECH[id].modifiers);
  assert.deepEqual(tech.vitality.modifiers,{hpMax:2});
  assert.deepEqual(tech.tactics.modifiers,{battleAp:1});
  assert.equal(tech.spear.description,'解锁矛架制造。');
});

test('v11正式商店商品集合、提高设备报价与卡牌类型明确', () => {
  const shops=read('shops'), cards=read('cards');
  const prices={wood:1,iron:1,plastic:1,rope:1,cloth:1,lamp:3,filter:4,planter:4,crossbow:5,shieldRack:5,spearRack:5,fishingNet:5,crate:5,generator:6};
  assert.deepEqual(Object.keys(shops).sort(),Object.keys(prices).sort());
  for(const [id,price] of Object.entries(prices)) {
    const item=shops[id];
    assert.equal(item.id,id); assert.equal(item.card,id);
    assert.equal(item.price,price,`${id}试测报价`);
    assert.equal(item.kind,cards[id].kind,id);
    assert.ok(['resource','equipment'].includes(item.kind),id);
    assert.equal(typeof item.name,'string');
  }
  assert.equal(Object.values(shops).filter(x=>x.kind==='resource').length,5);
  assert.equal(Object.values(shops).filter(x=>x.kind==='equipment').length,9);
});

test('v10整合旧节点身份，普通战斗与遗迹数值契约保持不变', () => {
  const nodes = read('nodes');
  for(const id of Object.keys(NODES)) assert.equal(nodes[id]?.id,id,`保留旧入口${id}`);
  const added=['provision','sharedMeal','workshop','winch','duel','fallback','sealedLarder','powderWreck','kelpDryingRack','silentWayfinder','boneHunter','shellGraveyard','drownedMint','rescuePontoon','coralShrine','riggersCache'];
  assert.deepEqual(Object.keys(nodes).sort(),[...Object.keys(NODES),...added].sort());
  assert.equal(nodes.ruin.difficulty, 'hard');
  for(const id of ['battle','jellyBattle','crabBattle','ruin','boss']) {
    for(const field of ['id','name','kind','monster','boss']) assert.deepEqual(nodes[id][field],NODES[id][field],`${id}.${field}`);
    assert.equal(nodes[id].category,'battle');
    assert.equal(nodes[id].max_visits,99);
    assert.equal(nodes[id].cooldown,1);
  }
  assert.equal(nodes.altar.retired,true);
  assert.deepEqual(nodes.altar.options.map(x=>x.id),['leave']);
  assert.deepEqual(nodes.trader.options.map(x=>x.id),['calm','leave']);
  assert.deepEqual(nodes.trader.options[0].effects,[{type:'ChangeCurrent',stat:'sanity',delta:5}]);
  assert.equal(nodes.drift.variants.length,3);
  assert.equal(nodes.storm.variants.length,2);
  for(const id of ['drift','storm']) assert.deepEqual(nodes[id].options,nodes[id].variants[0].options,`${id}兼容首变体`);
  assert.deepEqual(nodes.camp.options.filter(x=>x.id!=='leave').map(x=>x.id),['rest','provisions','rhythm']);
  assert.ok(nodes.fogGuide.options.filter(x=>x.id!=='leave').every(x=>x.cost===0 && !x.cardCosts && !x.statCosts && !x.special));
});

test('v10节点选项效果、敌人和卡牌引用完整，不再保留未开放机制', () => {
  const nodes=read('nodes'), cards=read('cards'), enemies=read('enemies'), equipment=read('equipment');
  const types=new Set(['GiveCard','ChangeCurrent','SetFlag','AddBuff','GiveRandomResource','ChangeAP','RepairCell','DamageTargetCell','GuideNavigation','GiveRelic','GiveRandomRelic']);
  const inspect = option => {
    assert.equal(typeof option.id,'string'); assert.equal(typeof option.name,'string'); assert.equal(typeof option.description,'string');
    assert.ok(Number.isInteger(option.cost) && option.cost>=0);
    for(const field of ['special','randomCardCost','detachCell','relicChance','relicProbability']) assert.equal(Object.hasOwn(option,field),false,`${option.id}.${field}`);
    for(const id of Object.keys(option.cardCosts ?? {})) assert.ok(cards[id],id);
    if(option.conditions?.equipment) assert.ok(equipment[option.conditions.equipment]);
    if(option.operation) assert.equal(option.operation,'exchange');
    if(option.battle) {
      assert.ok(enemies[option.battle.enemy]);
      const rewards=option.battle.rewards;
      assert.deepEqual(Object.keys(rewards).sort(),rewards.relics ? ['coin','corpse','relics','resources','xp'] : ['coin','corpse','resources','xp']);
      for(const field of ['coin','corpse','resources','xp']) assert.ok(Number.isInteger(rewards[field]) && rewards[field]>=0);
      for(const item of rewards.relics ?? []) assert.equal(read('relics')[item.id]?.enabled,true);
    }
    const effects=[...option.effects,...(option.outcomes ?? []).flatMap(x=>x.effects)];
    for(const effect of effects) {
      assert.ok(types.has(effect.type),effect.type);
      if(effect.type==='GiveCard') assert.ok(cards[effect.id],effect.id);
      if(effect.type==='GiveRelic') assert.equal(read('relics')[effect.id]?.enabled,true,effect.id);
      if(effect.type==='AddBuff') assert.ok(effect.id==='rested'||read('environments')[effect.id]);
    }
    for(const outcome of option.outcomes ?? []) assert.ok(Number.isInteger(outcome.weight) && outcome.weight>0);
  };
  for(const node of Object.values(nodes).flatMap(x=>[x,...(x.variants ?? [])])) {
    for(const option of [...(node.options ?? []),...(node.stages ?? []).flat()]) inspect(option);
  }
});

const withoutText = object => Object.fromEntries(Object.entries(object).filter(([key]) => !['description','name','intent'].includes(key)));
test('卡牌费用与效果仅允许已列明的修订', () => {
  const cards = read('cards');
  for (const [id, source] of Object.entries(CARDS)) {
    const expected = structuredClone(source);
    if (id === 'wood') expected.fuel=2;
    if (expected.kind === 'equipment') expected.cost = 0; // prior free-install revision
    if (id === 'spear') expected.damage = 3; // prior spear revision
    if (id === 'medkit') Object.assign(expected, {kind:'survival',cost:0,effects:[{type:'ChangeCurrent',stat:'hp',delta:3}]});
    if (id === 'pollution') { expected.heldEffects[0].delta = -1; expected.cost = 1; }
    assert.ok(cards[id], `缺少既有卡牌 ${id}`);
    const actual = withoutText(cards[id]);
    // Punch's old return trait no longer represents an ordinary hand card.
    if (id === 'punch') { delete actual.traits; delete expected.traits; }
    assert.deepEqual(actual, withoutText(expected), id);
  }
});

test('敌人生命与异常不变，直接伤害使用低生命试测值', () => {
  const enemies = read('enemies');
  for (const [id, source] of Object.entries(MONSTERS)) {
    const expected={...source, damage:{biter:1,jelly:1,crab:2,sentinel:2,boss:2}[id]};
    for (const key of ['hp','damage','buff','pollution']) assert.deepEqual(enemies[id][key], expected[key], `${id}.${key}`);
  }
});

test('既有设备生产与旧配方保持已批准修订', () => {
  const equipment = read('equipment'), recipes = read('recipes');
  for (const [id, source] of Object.entries(EQUIPMENT)) {
    const expected = structuredClone(source);
    if (id === 'spearRack') expected.battleStartOnly = true;
    if (id === 'medkit') expected.healing=[3,5,6];
    assert.deepEqual(withoutText(equipment[id]), withoutText(expected), id);
  }
  for (const [id, source] of Object.entries(RECIPES)) {
    const expected = structuredClone(source);
    if (id === 'repair') expected.ingredients = {iron:1,rope:1}; // existing salvage revision
    assert.deepEqual(recipes[id], expected, id);
  }
});

test('四种新设备可制造且内容引用有效', () => {
  const cards = read('cards'), equipment = read('equipment'), recipes = read('recipes');
  for (const id of ['shieldRack','generator','fishingNet','crate']) {
    assert.equal(cards[id]?.kind, 'equipment', id);
    assert.ok(equipment[id], id);
    assert.equal(recipes[id]?.output, id);
    for (const material of Object.keys(recipes[id].ingredients)) assert.equal(cards[material]?.kind, 'resource');
  }
  for (const recipe of Object.values(recipes)) assert.ok(cards[recipe.output], recipe.output);
});
