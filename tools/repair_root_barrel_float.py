"""Lower only the loose barrel body and hoops in root-decor.glb onto the deck.

The Blender export merges the barrel into shared wood and iron meshes. This
post-export repair selects its vertices by the barrel's module-space bounds.
It is safe to rerun: the repaired barrel no longer matches the original height
window, and the manifest hash is refreshed after the first run.
"""
import hashlib
import json
import pathlib
import struct

ROOT = pathlib.Path(__file__).resolve().parents[1]
MODEL = ROOT / "assets/models/raft-modules/root-decor.glb"
MANIFEST = ROOT / "assets/manifest.json"
LOWER_BY = 0.34
SOURCE_SHA256 = "10ca32201dc7061b5abad356213866ad6a68105bfeb8fdc04196e9956b1235b6"


def main():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entry = manifest["assets"]["model.raft.module.root-decor"]
    if hashlib.sha256(MODEL.read_bytes()).hexdigest() == entry.get("sha256") and entry.get("barrel_repair_complete"):
        print("root-decor barrel repair already applied")
        return
    data = MODEL.read_bytes()
    if hashlib.sha256(data).hexdigest() != SOURCE_SHA256:
        raise ValueError("root-decor export changed; inspect barrel bounds before applying this repair")
    if data[:4] != b"glTF":
        raise ValueError("root-decor is not a GLB file")
    version, total_length = struct.unpack_from("<II", data, 4)
    if version != 2 or total_length != len(data):
        raise ValueError("unexpected GLB version or length")

    offset = 12
    chunks = []
    while offset < len(data):
        length, kind = struct.unpack_from("<I4s", data, offset)
        start = offset + 8
        chunks.append((kind, data[start:start + length]))
        offset = start + length
    document = json.loads(next(payload for kind, payload in chunks if kind == b"JSON"))
    binary = bytearray(next(payload for kind, payload in chunks if kind == b"BIN\0"))

    # Identify the barrel's wood body and iron hoops within the merged meshes.
    # Complete bounds of all 16 staves and both hoops; no deck/crate vertices.
    target_nodes = {}
    for node in document.get("nodes", []):
        mesh_index = node.get("mesh")
        if mesh_index is None:
            continue
        for primitive in document["meshes"][mesh_index]["primitives"]:
            material = document.get("materials", [])[primitive.get("material", 0)].get("name", "")
            if material in {"MAT-WarmWeatheredWood", "MAT-AgedIron.001"}:
                target_nodes.setdefault(material, []).append((node, primitive))

    touched = {"MAT-WarmWeatheredWood": 0, "MAT-AgedIron.001": 0}
    for material_name, entries in target_nodes.items():
        for node, primitive in entries:
            accessor_index = primitive["attributes"]["POSITION"]
            accessor = document["accessors"][accessor_index]
            view = document["bufferViews"][accessor["bufferView"]]
            if accessor["componentType"] != 5126 or accessor["type"] != "VEC3":
                continue
            view_start = view.get("byteOffset", 0)
            view_length = view["byteLength"]
            accessor_start = accessor.get("byteOffset", 0)
            stride = view.get("byteStride", 12)
            count = accessor["count"]
            if stride != 12:
                raise ValueError("unexpected interleaved POSITION data")
            tr = node.get("translation", [0.0, 0.0, 0.0])
            points = []
            for index in range(count):
                position = view_start + accessor_start + index * stride
                x, y, z = struct.unpack_from("<3f", binary, position)
                world_x, world_y, world_z = x + tr[0], y + tr[1], z + tr[2]
                if 0.28 < world_x < 0.64 and -0.78 < world_z < -0.29 and 0.49 < world_y < 1.07:
                    y -= LOWER_BY
                    struct.pack_into("<f", binary, position + 4, y)
                    touched[material_name] += 1
                points.append(struct.unpack_from("<3f", binary, position))
            accessor["min"] = [min(p[i] for p in points) for i in range(3)]
            accessor["max"] = [max(p[i] for p in points) for i in range(3)]
            if view_start + view_length > len(binary):
                raise ValueError("bufferView exceeds GLB binary chunk")

    if touched != {"MAT-WarmWeatheredWood": 384, "MAT-AgedIron.001": 1372}:
        raise ValueError(f"barrel geometry selection mismatch: {touched}")

    json_payload = json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    json_payload += b" " * ((4 - len(json_payload) % 4) % 4)
    binary_payload = bytes(binary)
    binary_payload += b"\0" * ((4 - len(binary_payload) % 4) % 4)
    chunks_out = [(b"JSON", json_payload), (b"BIN\0", binary_payload)]
    glb = bytearray(b"glTF" + struct.pack("<II", 2, 0))
    for kind, payload in chunks_out:
        glb += struct.pack("<I4s", len(payload), kind) + payload
    struct.pack_into("<I", glb, 8, len(glb))
    MODEL.write_bytes(glb)

    entry["sha256"] = hashlib.sha256(glb).hexdigest()
    entry["version"] = 6
    entry["barrel_repair_complete"] = True
    entry["source"] = ["asset-sources/raft-blender-v1/raft_modules_v005.blend", "tools/repair_root_barrel_float.py"]
    entry["repair"] = "barrel body and hoops lowered 0.34 m onto the second decorative raft deck"
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"lowered_by_m": LOWER_BY, "vertices": touched, "sha256": entry["sha256"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
