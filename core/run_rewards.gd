extends RefCounted
## A story slot and the shared profile can be committed independently. Both
## carry the same immutable receipt, keyed by the existing gameplay run ID.

static func grant(profile: Dictionary, state: Dictionary) -> void:
	if state.get("mode", "") == "story":
		var id := str(state.get("run_id", ""))
		var receipts: Dictionary = profile.get("run_rewards", {}).duplicate(true)
		if receipts.has(id): return
		receipts[id] = {"points":int(state.completed), "result":str(state.result)}
		profile.run_rewards = receipts
	profile.points += int(state.completed)
	if state.result not in profile.endings: profile.endings.append(state.result)

## Only the loaded run's receipt can repair a missing shared reward. Never
## replace shared totals/purchases or merge receipts belonging to other runs.
## Legacy terminal slots have no receipt and are not retroactively rewarded.
static func recover(profile: Dictionary, state: Dictionary, saved_profile: Dictionary) -> bool:
	if state.get("mode", "") != "story" or state.get("phase", "") != "finished" or not state.get("awarded", false): return false
	var id := str(state.get("run_id", ""))
	var receipts: Dictionary = profile.get("run_rewards", {}).duplicate(true)
	var saved: Dictionary = saved_profile.get("run_rewards", {})
	if receipts.has(id) or not saved.has(id): return false
	var receipt: Dictionary = saved[id]
	receipts[id] = receipt.duplicate(true)
	profile.run_rewards = receipts
	profile.points += int(receipt.points)
	if receipt.result not in profile.endings: profile.endings.append(receipt.result)
	return true

static func valid(receipts: Variant) -> bool:
	if not receipts is Dictionary: return false
	for id in receipts:
		if not id is String or id.is_empty(): return false
		var receipt: Variant = receipts[id]
		if not receipt is Dictionary: return false
		var points: Variant = receipt.get("points")
		if not (points is int or points is float): return false
		if not is_finite(float(points)) or float(points) != floor(float(points)) or points < 0 or points > 15: return false
		if not receipt.get("result") is String or receipt.result.is_empty(): return false
	return true
