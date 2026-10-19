extends RefCounted
## Coverage is independent of replay: a green suite must first have real current
## fixtures for every required identity. Old traces are diagnostic-only.
static func evaluate(records: Array, required: Array, version: String, fingerprint: String) -> Dictionary:
	var seen := {}
	var current := 0
	var stale := 0
	var errors: Array = []
	for record in records:
		var id: String = str(record.get("id", ""))
		if id=="" or seen.has(id): errors.append("duplicate or empty route identity: " + id)
		seen[id] = false
		if record.get("version", "") != version:
			stale += 1
			continue
		if record.get("fingerprint", "") != fingerprint:
			errors.append("current route content mismatch: " + id)
			continue
		seen[id] = true
		current += 1
	for id in required:
		if not seen.get(id, false): errors.append("missing current route: " + str(id))
	if current==0: errors.append("zero current routes executed")
	return {"ok":errors.is_empty(), "current":current, "stale":stale, "errors":errors}
