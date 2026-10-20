"""由 output/manifest.json 生成试听页 output/../audition.html。

只做渲染，不合成音频；音频由 bake.gd 在 Godot 里烘出来。
运行：python experiments/blip-voice-audition/build_page.py
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent
MANIFEST = ROOT / "output" / "manifest.json"
PAGE = ROOT / "audition.html"

WAVE_NAMES = {0: "方波", 1: "锯齿波", 2: "三角波", 3: "正弦波"}
PITCH_NAMES = {0: "随机", 1: "按字固定", 2: "完全一致"}
GROUP_ORDER = ["界面反馈", "事件节点", "环境与战斗", "结果结算", "流程", "对白音色"]
GROUP_NOTE = {
    "界面反馈": "点击、确认、取消、不可用——最频繁的一层，音量压得最低。",
    "事件节点": "预选、扣 AP、抽牌、拾遗物——节点事件里一步动作的落点。",
    "环境与战斗": "预警、遭遇、命中——低频为主，靠截止点制造压迫感。",
    "结果结算": "成功与失败两条对称轮廓，避免玩家分不清结果。",
    "流程": "起航与胜利，用在段落开头结尾，长度明显更长。",
    "对白音色": "同一句真实文案、不同参数；第一条就是 opening_intro.gd 现在用的旁白，作为音量与语速基准。",
}

ITEM_TPL = """    <article class="item" data-src="{file}" data-dur="{duration}">
      <button class="play" type="button" aria-label="播放 {label}"><span class="glyph">▶</span></button>
      <div class="body">
        <div class="head"><h3>{label}</h3><code>{stem}</code></div>
        <p class="desc">{desc}</p>
        {sample}
        <p class="params">{params}</p>
        <div class="track"><i></i></div>
      </div>
      <div class="meta"><span class="dur">{duration_s}s</span><span class="peak">{peak_db} dB</span></div>
    </article>"""


def fmt_params(item):
    p = item["params"]
    if item["kind"] == "sfx":
        return " · ".join([
            WAVE_NAMES.get(p["wave"], "?"),
            f'基频 {p["base_freq"]:.0f} Hz',
            f'低通 {p["lowpass_cutoff"]:.0f} Hz',
            f'下滑 {p["glide"]:.2f}',
            f'增益 {p["gain"]:.2f}',
        ])
    bits = [WAVE_NAMES.get(p.get("wave", 0), "?"), f'基频 {p.get("base_freq", 0):.0f} Hz']
    for key, name, unit in [
        ("pitch_jitter", "抖动", "半音"),
        ("declination", "句尾降调", "半音"),
        ("note_duration", "单音", "s"),
        ("char_interval", "字间隔", "s"),
        ("lowpass_cutoff", "低通", "Hz"),
        ("glide", "下滑", ""),
        ("gain", "增益", ""),
    ]:
        if key in p:
            value = p[key]
            text = f"{value:.0f}" if key == "lowpass_cutoff" else f"{value:g}"
            bits.append(f"{name} {text}{(' ' + unit) if unit else ''}")
    if "pitch_mode" in p:
        bits.append("音高 " + PITCH_NAMES.get(p["pitch_mode"], "?"))
    bits.append(f'预设 {item["preset"]}')
    return " · ".join(bits)


def main():
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    items = data["items"]
    groups = {}
    for item in items:
        groups.setdefault(item["group"], []).append(item)

    sections = []
    for name in GROUP_ORDER:
        if name not in groups:
            continue
        rows = []
        for item in groups[name]:
            peak_db = 20 * __import__("math").log10(max(item["peak"], 1e-6))
            sample = f'<p class="sample">「{item["sample"]}」</p>' if item.get("sample") else ""
            rows.append(ITEM_TPL.format(
                file=item["file"].replace("output/", "output/"),
                duration=item["duration"],
                duration_s=f'{item["duration"] * 1000:.0f} ms' if item["duration"] < 1 else f'{item["duration"]:.2f} s',
                peak_db=f"{peak_db:+.1f}",
                label=item["label"],
                stem=item["id"],
                desc=item["desc"],
                sample=sample,
                params=fmt_params(item),
            ))
        sections.append(f"""  <section>
    <h2>{name}<span class="count">{len(groups[name])}</span></h2>
    <p class="note">{GROUP_NOTE.get(name, '')}</p>
[[ROWS_{name}]]
  </section>""")
        sections[-1] = sections[-1].replace(f"[[ROWS_{name}]]", "\n".join(rows))

    total = sum(i["duration"] for i in items)
    html = TEMPLATE.format(
        cue_count=data["cues"],
        voice_count=data["profiles"],
        total=f"{total:.1f}",
        sections="\n".join(sections),
    )
    PAGE.write_text(html, encoding="utf-8")
    print(f"wrote {PAGE} ({len(items)} items, {total:.1f}s)")


TEMPLATE = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>深潮 · Blip Voice 音效试听</title>
<style>
  :root {{
    --bg: #f5f7f9; --card: #ffffff; --line: #e2e6ec; --ink: #1b2027;
    --muted: #69737f; --accent: #17667f; --accent-soft: #e6f2f6;
    --mono: Consolas, "Cascadia Mono", ui-monospace, monospace;
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; padding: 40px 24px 72px; background: var(--bg); color: var(--ink);
    font: 15px/1.6 -apple-system, "Segoe UI", "Microsoft YaHei", sans-serif;
  }}
  main {{ max-width: 1040px; margin: 0 auto; }}
  header {{ margin-bottom: 36px; }}
  h1 {{ font-size: 25px; margin: 0 0 6px; letter-spacing: .01em; }}
  .sub {{ color: var(--muted); font-size: 14px; margin: 0; }}
  .summary {{ display: flex; flex-wrap: wrap; gap: 8px; margin-top: 18px; }}
  .chip {{
    background: var(--card); border: 1px solid var(--line); border-radius: 999px;
    padding: 5px 13px; font-size: 13px; color: var(--muted);
  }}
  .chip b {{ color: var(--ink); font-weight: 600; }}
  .caveat {{
    margin-top: 16px; padding: 12px 16px; border-left: 3px solid var(--accent);
    background: var(--accent-soft); border-radius: 0 8px 8px 0; font-size: 13.5px; color: #245062;
  }}
  section {{ margin-top: 40px; }}
  h2 {{ font-size: 16px; margin: 0 0 4px; display: flex; align-items: center; gap: 9px; }}
  .count {{
    font: 11px/1 var(--mono); color: var(--muted); background: #eceff3;
    border-radius: 5px; padding: 4px 6px;
  }}
  .note {{ margin: 0 0 14px; color: var(--muted); font-size: 13px; }}
  .item {{
    display: grid; grid-template-columns: 46px 1fr 92px; gap: 16px; align-items: start;
    background: var(--card); border: 1px solid var(--line); border-radius: 12px;
    padding: 15px 17px; margin-bottom: 10px; transition: border-color .15s, box-shadow .15s;
  }}
  .item:hover {{ border-color: #cdd6e0; }}
  .item.on {{ border-color: var(--accent); box-shadow: 0 0 0 3px var(--accent-soft); }}
  .play {{
    width: 46px; height: 46px; border-radius: 50%; border: 1px solid var(--line);
    background: #fbfcfd; color: var(--accent); cursor: pointer; font-size: 15px;
    display: flex; align-items: center; justify-content: center; padding: 0;
    transition: background .15s, transform .1s;
  }}
  .play:hover {{ background: var(--accent-soft); }}
  .play:active {{ transform: scale(.94); }}
  .item.on .play {{ background: var(--accent); color: #fff; border-color: var(--accent); }}
  .item.on .play .glyph {{ font-size: 12px; }}
  .head {{ display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; }}
  h3 {{ font-size: 15px; margin: 0; font-weight: 600; }}
  code {{ font: 12px var(--mono); color: #9aa4b0; }}
  .desc {{ margin: 3px 0 0; font-size: 13.5px; color: #3f4855; }}
  .sample {{ margin: 6px 0 0; font-size: 13.5px; color: #3f4855; font-style: normal; }}
  .sample::before {{ content: "文案 "; color: var(--muted); font-size: 12px; }}
  .params {{ margin: 6px 0 0; font: 11.5px/1.7 var(--mono); color: #8b96a2; }}
  .track {{ height: 3px; background: #eef1f5; border-radius: 2px; margin-top: 10px; overflow: hidden; }}
  .track i {{ display: block; height: 100%; width: 0; background: var(--accent); }}
  .meta {{ text-align: right; font: 12px/1.7 var(--mono); color: var(--muted); }}
  .dur {{ display: block; color: var(--ink); }}
  footer {{ margin-top: 48px; color: var(--muted); font-size: 12.5px; }}
</style>
</head>
<body>
<main>
  <header>
    <h1>深潮 · Blip Voice 音效试听</h1>
    <p class="sub">全部由 addons/blip_voice 的程序化合成器烘出，没有任何外部音频素材。此页仅供审核，游戏代码尚未接入。</p>
    <div class="summary">
      <span class="chip"><b>{cue_count}</b> 条音效</span>
      <span class="chip"><b>{voice_count}</b> 条对白音色</span>
      <span class="chip">总长 <b>{total}</b> 秒</span>
      <span class="chip">44.1 kHz · 16 bit · 单声道</span>
    </div>
    <p class="caveat">两条产线的电平是分开设计的：音效按 AudioStreamPlayer 0 dB 播放烘到接近满刻度；对白音色保持和 opening_intro.gd 现有旁白同一增益链，所以听起来会明显更轻——这是刻意的，方便你比较音色本身而不是比较响度。</p>
  </header>
{sections}
  <footer>重烘：Godot --headless --path . --script res://experiments/blip-voice-audition/bake.gd　重生成本页：python experiments/blip-voice-audition/build_page.py</footer>
</main>
<script>
  var audio = new Audio();
  var current = null;
  var raf = null;
  document.querySelectorAll('.item').forEach(function (item) {{
    var bar = item.querySelector('.track i');
    var glyph = item.querySelector('.glyph');
    item.querySelector('.play').addEventListener('click', function () {{
      if (current === item) {{
        if (audio.paused) {{ audio.play(); }} else {{ audio.pause(); }}
        return;
      }}
      if (current) {{
        current.classList.remove('on');
        current.querySelector('.glyph').textContent = '▶';
        current.querySelector('.track i').style.width = '0';
      }}
      current = item;
      audio.src = item.dataset.src;
      audio.currentTime = 0;
      audio.play();
    }});
    item._bar = bar; item._glyph = glyph;
  }});
  audio.addEventListener('play', function () {{
    if (!current) return;
    current.classList.add('on');
    current.querySelector('.glyph').textContent = '❚❚';
    tick();
  }});
  audio.addEventListener('pause', function () {{
    if (!current) return;
    current.classList.remove('on');
    current.querySelector('.glyph').textContent = '▶';
    cancelAnimationFrame(raf);
  }});
  audio.addEventListener('ended', function () {{
    if (!current) return;
    current.classList.remove('on');
    current.querySelector('.glyph').textContent = '▶';
    current.querySelector('.track i').style.width = '100%';
  }});
  function tick() {{
    if (!current || !audio.duration) {{ raf = requestAnimationFrame(tick); return; }}
    current.querySelector('.track i').style.width = (audio.currentTime / audio.duration * 100) + '%';
    raf = requestAnimationFrame(tick);
  }}
</script>
</body>
</html>
"""

if __name__ == "__main__":
    main()
