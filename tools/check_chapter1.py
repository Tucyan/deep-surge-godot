"""Verify archive preservation, text-span provenance and local gameplay overrides."""
import json
import re
import zipfile
from xml.etree import ElementTree as ET
from import_chapter1 import ROOT, OUT, ARCHIVE


def main():
    with zipfile.ZipFile(ARCHIVE) as archive:
        for name in ["vn_source_blocks.json", "vn_display_units.json", "vn_scene_flow.json", "QA_TEXT_INTEGRITY.json"]:
            assert archive.read(name) == (OUT / "source" / name).read_bytes(), name
        source = json.loads(archive.read("vn_source_blocks.json"))
        with zipfile.ZipFile(__import__("io").BytesIO(archive.read("DeepSurge_Chapter1_Formatted.docx"))) as docx:
            document = ET.fromstring(docx.read("word/document.xml"))
            ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
            paragraphs = []
            for p in document.findall("w:body/w:p", ns):
                value = ""
                for child in p.iter():
                    tag = child.tag.rsplit("}", 1)[-1]
                    if tag == "t": value += child.text or ""
                    elif tag in ["br", "cr"]: value += "\n"
                    elif tag == "tab": value += "\t"
                paragraphs.append(value)
            assert paragraphs == [b["text"] for b in source["blocks"]], "DOCX/source mismatch"
    blocks = {b["id"]: b["text"] for b in source["blocks"]}
    overrides = json.loads((OUT / "source/local-display-overrides.json").read_text(encoding="utf-8"))
    count = 0
    for number in range(1, 12):
        scene = json.loads((OUT / f"scenes/chapter1_{number:02}.json").read_text(encoding="utf-8"))
        ids = {n["id"] for n in scene["nodes"]}
        assert scene["entry"] in ids
        for node in scene["nodes"]:
            count += 1
            bid = node.get("source_block_id")
            if bid:
                text = overrides[bid]["text"] if node.get("display_override") else blocks[bid]
                assert text[node["source_offset"]:node["source_offset"] + len(node["text"])] == node["text"]
            else:
                assert node.get("system_text"), node["id"]
            assert node.get("next", "") in ids | {""}
            for choice in node.get("choices", []):
                assert choice["next"] in ids
                if choice.get("source_block_id"):
                    bid = choice["source_block_id"]
                    text = overrides[bid]["text"] if choice.get("display_override") else blocks[bid]
                    assert choice["text"] == text.split("\n", 1)[0]
            text = node["text"]
            assert not re.search(r"RestCount|Meta|轮回点\s*\+|生命值\s*[+－-]|SAN值-10|第 1[245] 节点", text), text
    print(f"CHAPTER1 INTEGRITY: 408 DOCX paragraphs match source; 4 JSON originals byte-identical; {count} runtime nodes have verified provenance; {len(overrides)} explicit local adaptations.")


if __name__ == "__main__":
    main()
