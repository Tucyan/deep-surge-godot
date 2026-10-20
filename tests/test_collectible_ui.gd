extends SceneTree
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	var catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	var s=load("res://core/game_session.gd").new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}),"new")
	s._auto_advancing=true; s.state.coins=100
	s.state.node=catalog.entry("nodes","trader"); s.state.node.visit_id="ui-shop"
	s.state.phase="story"; s.state.story_step="choice"
	check(s.dispatch("shop_enter"),"shop")
	var page=load("res://pages/shop_page.gd").new(); root.add_child(page)
	page.size=Vector2(1280,720); page.theme=load("res://presentation/widgets.gd").theme()
	page.setup(s.view(),catalog,null)
	var commands: Array=[]
	page.command_requested.connect(func(cmd,args):commands.append({"command":cmd,"args":args}))
	var offer: Dictionary=s.view().shop.relic_stock[0]
	page.select_buy(offer)
	await process_frame; await process_frame
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(Vector2(page.confirmation.position),Vector2(page.confirmation.size))),"collectible confirmation in viewport")
	check(commands.is_empty(),"selection does not purchase")
	var directory: String=ProjectSettings.globalize_path("res://.planning/collectibles/ui")
	DirAccess.make_dir_recursive_absolute(directory)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory+"/shop-confirm.png")
	page.cancel_selection(); check(commands.is_empty(),"cancel does not purchase")
	page.select_buy(offer); page.confirm_selection()
	check(commands.size()==1 and commands[0].command=="buy_collectible" and commands[0].args.revision==s.revision,"confirmation sends collectible transaction revision")
	page.free()
	for id in ["rescueBadge","sealedFishTin","foldingRule","barbedBundle","crimsonVial","sailorsKnot"]:
		check(s.Collectibles.acquire(s,id),"collection fixture "+id)
	s.state.phase="navigation"
	var collection=load("res://pages/collectibles_page.gd").new(); root.add_child(collection)
	collection.size=Vector2(1280,720); collection.theme=load("res://presentation/widgets.gd").theme()
	collection.setup(s.view(),catalog,null)
	check(collection.find_children("*","ScrollContainer",true,false).size()==2,"grid and detail each scroll")
	await process_frame; await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory+"/collection.png")
	collection.free()
	# Dense scrolling and selection track instances, including duplicate definitions.
	for i in range(16): check(s.Collectibles.acquire(s,"sailorsKnot"),"warehouse duplicate fixture")
	var rules: Dictionary=s.snapshot()
	collection=load("res://pages/collectibles_page.gd").new(); root.add_child(collection)
	collection.size=Vector2(1280,720); collection.theme=load("res://presentation/widgets.gd").theme()
	collection.setup(s.view(),catalog,null)
	await process_frame; await process_frame
	check(collection.grid.columns==5 and collection.grid.get_child_count()==22,"dense warehouse lists every instance")
	var slots=collection.grid.get_children().filter(func(node):return node is Button)
	slots[1].pressed.emit(); await process_frame
	check(collection.selected_uid==s.view().collectibles[1].uid,"selection uses instance UID")
	collection.grid_scroll.scroll_vertical=1000; await process_frame; await process_frame
	slots=collection.grid.get_children().filter(func(node):return node is Button)
	slots[20].pressed.emit(); await process_frame
	check(collection.selected_uid==s.view().collectibles[20].uid,"scroll reaches real instance after twentieth")
	check(s.snapshot()==rules,"warehouse inspection and scrolling never mutate state/RNG")
	collection.free()
	print("COLLECTIBLE UI: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
