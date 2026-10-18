extends SceneTree
class TimedAssets extends "res://presentation/asset_catalog.gd":
	var calls: Dictionary={}
	func texture(id: String) -> Texture2D:
		var start:=Time.get_ticks_usec(); var result:=super.texture(id)
		var elapsed: int=Time.get_ticks_usec()-start
		if not calls.has(id): calls[id]=0
		calls[id]+=elapsed
		return result
func _init(): call_deferred("run")
func run():
	if DisplayServer.get_name()=="headless": quit(1); return
	root.size=Vector2i(1280,720)
	var app=load("res://flow_app.gd").new(); app.persistence=false; app.assets=TimedAssets.new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(app)
	await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	await create_timer(1).timeout
	var result:={}
	for i in range(2):
		app.assets.calls.clear()
		var start:=Time.get_ticks_usec(); app.handle_command("panel",{"id":"craft"})
		var sync: float=(Time.get_ticks_usec()-start)/1000.0
		await RenderingServer.frame_post_draw
		var draw: float=(Time.get_ticks_usec()-start)/1000.0
		result[str(i)]={"sync_ms":sync,"draw_ms":draw,"texture_load_us":app.assets.calls.duplicate()}
		app.handle_command("close"); await process_frame; await RenderingServer.frame_post_draw
	print("MODAL_FIRST_OPEN "+JSON.stringify(result))
	var file:=FileAccess.open("res://evidence/modal-first-open-profile.json",FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	app.queue_free(); await process_frame; quit(0)
