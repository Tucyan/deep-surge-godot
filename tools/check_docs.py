"""Check current context documents without third-party packages or game startup.

Plans, evidence and archives keep their historical code versions; they are not
treated as current contracts. Their files can still be link targets.
"""
import argparse
from datetime import date
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]


def without_fences(text):
    lines = []
    fence = None
    for line in text.splitlines():
        marker = re.match(r"\s*(`{3,}|~{3,})", line)
        if marker:
            kind = marker[1][0]
            if fence is None:
                fence = kind
            elif fence == kind:
                fence = None
            lines.append("")
        else:
            lines.append(line if fence is None else "")
    return "\n".join(lines)


def validate_document(path, project_root, expected_version, require_metadata=False):
    path, project_root = Path(path), Path(project_root)
    if not path.is_file():
        return [f"{path}: document missing"]
    text = path.read_text(encoding="utf-8-sig")
    errors = []
    prose = without_fences(text)
    for match in re.finditer(r"\]\((<[^>]+>|[^)]+)\)", prose):
        target = match[1].strip().strip("<>")
        if not target or target.startswith("#"):
            continue
        parsed = urlsplit(target)
        if parsed.scheme:
            continue
        destination = path.parent / unquote(parsed.path)
        if not destination.exists():
            line = prose.count("\n", 0, match.start()) + 1
            errors.append(f"{path}:{line}: missing link target {target}")
    if require_metadata:
        found = re.search(r"<!--\s*doc-status:.*?-->", text, re.S)
        metadata = dict(re.findall(r"([a-z-]+):\s*([^;<>]+)", found[0][4:-3])) if found else {}
        metadata = {key: value.strip() for key, value in metadata.items()}
        if metadata.get("doc-status") != "current":
            errors.append(f"{path}: current contract metadata missing")
        if metadata.get("doc-role") not in ("entry", "contract", "governance"):
            errors.append(f"{path}: document role missing or invalid")
        if metadata.get("content-version") != expected_version:
            errors.append(f"{path}: content version must be {expected_version}")
        try:
            date.fromisoformat(metadata.get("reviewed", ""))
        except ValueError:
            errors.append(f"{path}: ISO review date missing or invalid")
        for claim in re.findall(r"当前(?:内容)?版本(?:为|是|：|:)\s*`?(godot-flow-v02-\d+)", prose):
            if claim != expected_version:
                errors.append(f"{path}: stale current-version claim {claim}")
    return errors


def validate_sources(project_root, sources):
    return [f"missing registered source: {source}" for source in sources
            if not (Path(project_root) / source).is_file()]


def check_project(project_root=ROOT):
    root = Path(project_root)
    source = root / "core/game_session.gd"
    match = re.search(r'const VERSION\s*:?=\s*"([^"]+)"', source.read_text(encoding="utf-8-sig"))
    if not match:
        return ["GameSession content version not found"], 0, 0
    version = match[1]
    registry = json.loads((root / "docs/documentation-map.json").read_text(encoding="utf-8-sig"))
    errors = []
    current = set()
    for entry in registry["current"]:
        path = root / entry["path"]
        current.add(path.resolve())
        errors.extend(validate_document(path, root, version, True))
        errors.extend(validate_sources(root, entry.get("sources", [])))
    # Top-level topic documents get link checks, without promoting their past
    # verification/version statements to authoritative current contracts.
    files = set((root / "docs").glob("*.md")) | {root / "README.md"}
    # Also check the parent context when this is the nested yongxian checkout.
    if root.name == "deep-surge-godot":
        files |= {p for p in (root.parent / "README.md", root.parent / "AGENTS.md") if p.is_file()}
    for path in sorted(files):
        if path.resolve() not in current:
            errors.extend(validate_document(path, root, version))
    return errors, len(files), len(current)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    try:
        errors, documents, contracts = check_project(args.root)
    except (OSError, ValueError, KeyError) as error:
        errors, documents, contracts = [str(error)], 0, 0
    for error in errors:
        print("FAIL:", error)
    print(f"DOCS: {'FAIL' if errors else 'PASS'} ({documents} entry/topic files, {contracts} current documents, {len(errors)} errors)")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
