extends RefCounted
## All arithmetic masked to uint32. Seed zero is legal; each stream has a salt.
const SALTS := {"initial":0x9e3779b9, "nodes":0x85ebca6b, "rewards":0xc2b2ae35, "battle":0x27d4eb2f, "environment":0x165667b1, "movement":0xd3a2646c}
static func create(seed: int) -> Dictionary:
	var result := {}
	for id in SALTS:
		var value: int = (seed ^ SALTS[id]) & 0xffffffff
		result[id] = {"value":value if value != 0 else 1, "cursor":0}
	return result
static func draw(streams: Dictionary, id: String) -> float:
	var stream: Dictionary = streams[id]
	var value: int = stream.value
	value = (value ^ (value << 13)) & 0xffffffff
	value = (value ^ (value >> 17)) & 0xffffffff
	value = (value ^ (value << 5)) & 0xffffffff
	stream.value = value
	stream.cursor += 1
	return float(value) / 4294967296.0
static func pick(streams: Dictionary, id: String, values: Array):
	return values[int(draw(streams, id) * values.size())]
