extends RefCounted
## Retention compares presentation inputs, never the growing event/log history.
## Shallow copies are enough: no nested state is modified during projection.
static func signature(app) -> String:
	var state: Dictionary = app.session.state.duplicate(false)
	for hidden in ["logs", "stats", "rng", "pool", "origin_state"]:
		state.erase(hidden)
	# The battle HUD displays the current encounter's log. Earlier encounters and
	# diagnostic history do not participate, but new visible combat text must.
	if app.session.phase() == "battle":
		var logs: Array = app.session.state.get("logs", [])
		var start := 0
		for index in range(logs.size()-1, -1, -1):
			if str(logs[index]).contains("迎战"):
				start = index
				break
		state.logs = logs.slice(start)
	return JSON.stringify([app.session.screen, state, app.session.profile,
		app.session.last_settlement, app.size, app.display_settings.ui_scale,
		app.display_settings.mobile])
