"""Reproducible conversion of the supplied VN archive to local narrative scenes.

Archive instructions are reference material. Local gameplay is authoritative.
No code from the archive is executed. Text slices always reference original blocks.
"""
import hashlib
import json
import re
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "asset-sources/chapter1-vn/DeepSurge_Chapter1_VN_Import_All.zip"
OUT = ROOT / "narrative/content"
ENTRIES = ["n01", "n02", "n03", "n04_intro", "n05_incident"] + [f"n{i:02}_intro" for i in range(6, 12)]
NAMES = {"塞琳": "celine", "涅德": "ned", "柯尔": "kohl", "芮安": "ryan"}
QUEST_ITEMS = {"老海妖骨凿", "学者骨质罗盘", "避水海兽獠牙护符"}


def adapt_block(block):
    """Only conflicting gameplay/HUD annotations change; keep prose archived."""
    text, bid = block["text"], block["id"]
    explicit = {
        "p0014": "（请选择接下来的剧情行动。）",
        "p0031": "【航行提示】：制造、安装与食水使用，请在航行界面按当前规则操作。",
        "p0041": "（你握紧手边的武器，准备迎接水下的阴影。）",
        "p0045": "【剧情演出】：进攻与招架。",
        "p0121": "剧情调查将在第06～11节点展开。",
        "p0172": "【剧情提示】：接下来每个节点先进行剧情抉择，再继续航行。",
        "p0407": "【剧情进度】：当前提供的正文到第11节点为止，后续调查剧情尚未提供。",
    }
    if bid in explicit:
        return explicit[bid]
    text = text.replace("生命值-5 饱食度-10 口渴值-10", "").replace("（SAN值-10）", "")
    text = re.sub(r"（获得(?:废铁|木头)[^）]*）", "", text)
    text = re.sub(r"（周目轮回点\s*\+1）", "", text)
    text = text.replace("永久点亮 / 具备 Meta 属性", "本档线索").replace("永久点亮 / Meta 属性", "本档线索").replace("永久保留 Meta 属性", "本档线索")
    text = text.replace("；获得卡牌：食物", "").replace("（大幅增强精神坚韧度与抗致幻能力）", "（剧情道具）")
    if bid in ["p0186", "p0217", "p0261", "p0312", "p0362", "p0388"]:
        text = re.split(r"【(?:通用休息结算|结算)】", text)[0] + "【剧情记录】：本夜选择休息，未获得线索。累计三次休息将进入坏结局。"
    if bid in ["p0213", "p0256", "p0308", "p0358", "p0384"]:
        text = re.sub(r"（.*）", "（累计三次休息将进入坏结局）", text)
    text = text.replace("休息恢复", "休息").replace("（通用休息判定）", "")
    # Old automatic gameplay and 15-night counters are superseded by local flow.
    lines = []
    for line in text.split("\n"):
        if "【状态结算】" in line:
            continue
        if "【系统提示】" in line and ("晚" in line or "夜间" in line):
            line = "【剧情提示】：请选择今晚的行动方向。"
        if ("【时限更新】" in line or "剩余时间：" in line or "剩余调查时限：" in line or "第一阶段倒计时更新：" in line):
            line = f"【剧情进度】：第{block['node']:02}节点；当前章节共11节点。"
        if "· 已掌握线索：依玩家的选择" in line:
            line = "· 已掌握的线索可在设置的剧情页查看。"
        lines.append(line)
    return "\n".join(lines)


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    with zipfile.ZipFile(ARCHIVE) as archive:
        source = json.loads(archive.read("vn_source_blocks.json"))
        flow = json.loads(archive.read("vn_scene_flow.json"))
        for name in ["vn_source_blocks.json", "vn_display_units.json", "vn_scene_flow.json", "QA_TEXT_INTEGRITY.json"]:
            target = OUT / "source" / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(name))
    blocks = {b["id"]: b for b in source["blocks"]}
    display = {bid: adapt_block(block) for bid, block in blocks.items()}
    overrides = {bid: {"text": text, "reason": "Local gameplay, per-slot clues and 11-node scope override imported system annotations."}
                 for bid, text in display.items() if text != blocks[bid]["text"]}
    write(OUT / "source/local-display-overrides.json", overrides)
    scenes = {s["id"]: s for s in flow["scenes"]}
    ignored = []

    def effects(entries):
        result = []
        for effect in entries:
            action, key = effect["action"], effect["key"]
            if action == "delta_trust":
                result.append({"action": "affinity", "key": NAMES[key], "value": effect["value"]})
            elif action in ["set_flag", "start_quest"]:
                result.append({"action": "flag", "key": key})
            elif action == "unlock_clue":
                result.append({"action": "clue", "key": key})
            elif action == "grant_item" and key in QUEST_ITEMS:
                result.append({"action": "item", "key": key})
            elif action == "increment" and key == "RestCount":
                result.append({"action": "rest", "key": key, "value": 1})
            elif action == "trigger_ending":
                result.append({"action": "ending", "key": key})
            else:
                ignored.append(effect)
        return result

    for number, entry in enumerate(ENTRIES, 1):
        included = [s for s in flow["scenes"] if s["node"] == number and s["id"] != "be03"]
        if number >= 6:
            included.append(scenes["be03"])
        ids = {s["id"] for s in included}
        nodes, chains = [], {}
        menu_blocks = {c["source_block_id"] for s in included for c in (s["menu"] or [])}

        def text_nodes(block_id, text, offset=0, prefix=""):
            parts = []
            pos = offset
            for line in text.splitlines(keepends=True):
                clean = line.rstrip("\r\n")
                for start in range(0, len(clean), 120):
                    chunk = clean[start:start + 120]
                    node = {"id": f"{prefix}{block_id}_{pos + start}", "text": chunk,
                            "source_block_id": block_id, "source_offset": pos + start}
                    if block_id in overrides:
                        node["display_override"] = True
                    assert display[block_id][pos+start:pos+start+len(chunk)] == chunk
                    parts.append(node)
                pos += len(line)
            return parts

        # Every scene has a terminal marker; it also owns the scene effects.
        for s in included:
            chain = []
            for block_id in s["block_ids"]:
                if block_id in menu_blocks:
                    continue
                chain.extend(text_nodes(block_id, display[block_id], prefix=s["id"] + "_"))
            marker = {"id": s["id"] + "_end", "text": "请选择接下来的行动。" if s["menu"] else "本段剧情结束。",
                      "system_text": True, "narrative_effects": effects(s["on_enter"] + s["on_exit"])}
            if s["id"] == "n11_outro":
                marker["text"] = "当前版本剧情到此为止。请完成第11节点航行；后续剧情尚未提供。"
            if s.get("terminal"):
                marker["ending"] = s["terminal"]
            chain.append(marker)
            for a, b in zip(chain, chain[1:]):
                a["next"] = b["id"]
            chains[s["id"]] = chain
            nodes.extend(chain)

        for s in included:
            marker = chains[s["id"]][-1]
            target = s.get("next")
            if target in ids:
                marker["next"] = chains[target][0]["id"]
            if s.get("post_effect_redirect"):
                marker["rest_redirect"] = chains["be03"][0]["id"]
            if not s["menu"]:
                continue
            marker["choices"] = []
            for c in s["menu"]:
                assert c["target"] in ids
                raw = display[c["source_block_id"]]
                label = raw.split("\n", 1)[0]
                choice = {"id": c["id"], "text": label, "next": chains[c["target"]][0]["id"],
                          "source_block_id": c["source_block_id"], "condition": c.get("condition") or {},
                          "narrative_effects": effects(c.get("effects", []))}
                if c["source_block_id"] in overrides:
                    choice["display_override"] = True
                # Only the chosen option's response is played, before its target.
                if "\n" in raw:
                    response = text_nodes(c["source_block_id"], raw[len(label)+1:], len(label)+1, c["id"] + "_reply_")
                    for a, b in zip(response, response[1:]): a["next"] = b["id"]
                    if response:
                        response[-1]["next"] = choice["next"]
                        choice["next"] = response[0]["id"]
                        nodes.extend(response)
                marker["choices"].append(choice)
            # Investigation submenus always offer a safe local route back to rest.
            if s["id"] in ["n10_investigate", "n11_investigate"]:
                marker["choices"].append({"id": "return_to_rest", "text": "返回休息", "system_text": True,
                                          "next": chains[f"n{number:02}_rest"][0]["id"]})
        story = {"schema_version": 1, "id": f"chapter1.n{number:02}", "title": f"第一章 · 节点 {number:02}/11",
                 "imported_chapter1": True, "entry": chains[entry][0]["id"], "nodes": nodes}
        write(OUT / f"scenes/chapter1_{number:02}.json", story)
    write(OUT / "chapter_l1.json", {"schema": 1, "id": "chapter1", "version": "chapter1-local-v1", "length": 11,
          "beats": [{"id": f"C1-N{i:02}", "after_voyage": i, "scene": f"chapter1.n{i:02}", "before_voyage": True} for i in range(1, 12)],
          "scene_files": [f"res://narrative/content/scenes/chapter1_{i:02}.json" for i in range(1, 12)]})
    write(OUT / "characters.json", {"schema": 1, "characters": [{"id": id, "name": name, "levels": [{"min": 0, "label": "初识"}, {"min": 5, "label": "信任"}]} for name, id in NAMES.items()]})
    write(OUT / "source/local-adaptation.json", {"archive_sha256": hashlib.sha256(ARCHIVE.read_bytes()).hexdigest(),
          "clue_catalog": flow["clue_catalog"], "ignored_gameplay_effects": ignored,
          "policy": "Local gameplay wins; imported numbers/materials/cards/meta rewards remain text only. Quest items and clues are narrative-only. No node12-15 or old campaign/night rules."})
    print("Imported 408 source blocks, 11 local scenes; original archive and JSON preserved.")


if __name__ == "__main__":
    main()
