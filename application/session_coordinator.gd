extends RefCounted
## Validate the entire replacement before publishing either active session.
const Session = preload("res://core/game_session.gd")
const NarrativeSession = preload("res://narrative/narrative_session.gd")

static func prepare_challenge(current: RefCounted, narrative_content: RefCounted, args: Dictionary) -> Dictionary:
	if args.get("mode", "") != "challenge":
		return {"ok":false, "error":"请选择挑战模式"}
	var candidate := Session.new(current.catalog)
	candidate.profile = current.profile.duplicate(true)
	# The submitted revision belongs to the current page. Preserve that boundary
	# instead of validating it against a new session's default revision zero.
	candidate.revision = current.revision
	candidate.last_settlement = current.last_settlement.duplicate(true)
	if not candidate.dispatch("new", args):
		return {"ok":false, "error":candidate.error}
	return {"ok":true, "session":candidate, "narrative":NarrativeSession.new(narrative_content)}
