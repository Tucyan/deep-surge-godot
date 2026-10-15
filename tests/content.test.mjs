import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {CARDS} from '../../玩法实验/src/content/cards.js';
import {NODES, MONSTERS, SHOP} from '../../玩法实验/src/content/nodes.js';
import {EQUIPMENT, RECIPES} from '../../玩法实验/src/content/equipment.js';
import {META_SHOP, TECH, RELICS} from '../../玩法实验/src/content/relics.js';

const read = table => JSON.parse(readFileSync(new URL(`../content/data/${table}.json`, import.meta.url), 'utf8'));

// The original lab remains a historical source. Godot now has explicitly approved
// revisions; assert those revisions instead of pretending the two games match.
for (const [table, source] of Object.entries({shops:Object.fromEntries(SHOP.map(x=>[x.id,x])),meta_shop:META_SHOP,tech:TECH,relics:RELICS})) {
  test(`${table}: 历史内容与health-12-v1修订`, () => {
    const expected=structuredClone(source);
    if(table==='meta_shop') { expected.body.modifiers.hpMax=2; expected.body.description='永久生命上限+2，饱食、水分、精神上限各+5。'; }
    if(table==='relics') { expected.guardian.modifiers.hpMax=2; expected.guardian.description='生命上限+2。'; }
    assert.deepEqual(read(table),expected);
  });
}

test('节点保留既有内容与已确认生命缩放', () => {
  const nodes = read('nodes');
  assert.equal(nodes.ruin.difficulty, 'hard');
  delete nodes.ruin.difficulty;
  const expected=structuredClone(NODES);
  expected.camp.options[0].description=expected.camp.options[0].description.replace('生命+15','生命+6');
  expected.camp.options[0].effects[0].delta=6;
  expected.jelly.options[1].name=expected.jelly.options[1].name.replace('5点','2点');
  expected.jelly.options[1].description=expected.jelly.options[1].description.replace('5生命','2生命');
  expected.altar.options[1].statCosts.hp=3;
  expected.altar.options[1].description=expected.altar.options[1].description.replace('8 HP','3 HP');
  assert.deepEqual(nodes, expected);
});

const withoutText = object => Object.fromEntries(Object.entries(object).filter(([key]) => !['description','name','intent'].includes(key)));
test('卡牌费用与效果仅允许已列明的修订', () => {
  const cards = read('cards');
  for (const [id, source] of Object.entries(CARDS)) {
    const expected = structuredClone(source);
    if (expected.kind === 'equipment') expected.cost = 0; // prior free-install revision
    if (id === 'spear') expected.damage = 3; // prior spear revision
    if (id === 'medkit') Object.assign(expected, {kind:'survival',cost:0,effects:[{type:'ChangeCurrent',stat:'hp',delta:3}]});
    if (id === 'pollution') expected.heldEffects[0].delta=-1;
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
