extends SceneTree
## Dedicated test entry: loads data/core only, never main.tscn or SaveStore.
const Catalog=preload("res://content/catalog.gd")
const Agent=preload("res://adapters/agent_session.gd")
const MAX_LINE_BYTES := 8*1024*1024

func _init() -> void:
	run.call_deferred()

func run() -> void:
	ProjectSettings.set_setting("application/run/flush_stdout_on_print",true)
	var catalog=Catalog.new()
	if not catalog.load_catalog():
		print(JSON.stringify(Agent.failure(null,"content_error",catalog.error)))
		quit(1); return
	var agent=Agent.new(catalog)
	var line := PackedByteArray()
	var oversized := false
	while true:
		# Pipe reads wait for the requested byte count. Reading 1024 bytes would
		# deadlock short requests; frame bytes explicitly and decode UTF-8 once.
		var chunk: PackedByteArray=OS.read_buffer_from_stdin(1)
		if chunk.is_empty(): break
		if chunk[0]!=10:
			if line.size()<MAX_LINE_BYTES: line.append(chunk[0])
			else: oversized=true
			continue
		if oversized:
			print(JSON.stringify(Agent.failure(null,"request_too_large","请求超过8 MiB")))
			line.clear(); oversized=false; continue
		var parser:=JSON.new()
		var status: int=parser.parse(line.get_string_from_utf8())
		line.clear()
		if status!=OK:
			print(JSON.stringify(Agent.failure(null,"invalid_json","无效JSON"))); continue
		var request: Variant=parser.data
		if request is Dictionary and request.get("method")=="quit":
			print(JSON.stringify(Agent.success(request.get("id"),{"closed":true})))
			break
		print(JSON.stringify(agent.handle(request)))
	quit(0)
