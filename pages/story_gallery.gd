extends VBoxContainer
signal replay_requested(id: String)
const W = preload("res://presentation/widgets.gd")
var records: Array = []
var assets: RefCounted
var page_index := 0
var columns := 3
var grid: GridContainer
var nav: HBoxContainer

func setup(entries: Array, art: RefCounted) -> void:
	name = "StoryGallery"
	records = entries.duplicate(true); assets = art
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	W.text(self, "回溯潮涌", 32, W.GOLD)
	W.text(self, "剧情回廊 · 重访那些与海相遇的时刻", 18, W.MUTED)
	grid = GridContainer.new(); grid.name = "StoryGalleryGrid"
	grid.size_flags_vertical = SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	add_child(grid)
	nav = HBoxContainer.new(); nav.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(nav)
	resized.connect(_arrange)
	_arrange()
	_build_cards()

func _arrange() -> void:
	var desired := 3 if size.x >= 1000 else 2
	if desired != columns:
		columns = desired; page_index = 0
		_build_cards()

func _build_cards() -> void:
	for parent in [grid, nav]:
		for child in parent.get_children(): parent.remove_child(child); child.queue_free()
	grid.columns = columns
	var per_page := columns * 2
	var pages := maxi(1, ceili(float(records.size()) / per_page))
	page_index = clampi(page_index, 0, pages-1)
	for record in records.slice(page_index*per_page, (page_index+1)*per_page):
		var card := Button.new(); card.name = "StoryCard_" + record.id.replace(".", "_")
		card.set_meta("story_id", record.id)
		card.accessibility_name = record.title + "，" + record.subtitle
		card.custom_minimum_size = Vector2(0, 210)
		card.size_flags_horizontal = SIZE_EXPAND_FILL; card.size_flags_vertical = SIZE_EXPAND_FILL
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("18313b") if state in ["hover", "pressed"] else Color("0b1d27")
			style.border_color = W.GOLD if state in ["hover", "focus"] else Color("36505b")
			style.set_border_width_all(2); style.set_corner_radius_all(6)
			card.add_theme_stylebox_override(state, style)
		grid.add_child(card)
		var margin := MarginContainer.new(); margin.mouse_filter = MOUSE_FILTER_IGNORE
		card.add_child(margin); margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_"+edge, 12)
		var content := VBoxContainer.new(); content.mouse_filter = MOUSE_FILTER_IGNORE
		margin.add_child(content)
		var image := TextureRect.new(); image.name = "Cover"
		image.texture = cover(record, assets)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size.y = 112; image.size_flags_vertical = SIZE_EXPAND_FILL
		image.mouse_filter = MOUSE_FILTER_IGNORE; content.add_child(image)
		var title := W.text(content, record.title, 23, W.INK); title.name = "StoryTitle"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.mouse_filter = MOUSE_FILTER_IGNORE
		var subtitle := W.text(content, record.subtitle, 15, W.GOLD if record.special else W.MUTED)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; subtitle.mouse_filter = MOUSE_FILTER_IGNORE
		card.pressed.connect(func(): replay_requested.emit(record.id))
	for unused in range(per_page - mini(per_page, records.size()-page_index*per_page)):
		var space := Control.new(); space.mouse_filter = MOUSE_FILTER_IGNORE
		space.custom_minimum_size.y = 210
		space.size_flags_horizontal = SIZE_EXPAND_FILL; space.size_flags_vertical = SIZE_EXPAND_FILL
		grid.add_child(space)
	W.button(nav, "上一页", func(): page_index -= 1; _build_cards(), page_index == 0)
	W.counter(nav, "%d / %d" % [page_index+1, pages])
	W.button(nav, "下一页", func(): page_index += 1; _build_cards(), page_index == pages-1)

static func cover(record: Dictionary, art: RefCounted) -> Texture2D:
	var cover_id: String = record.art
	if art.show_label(cover_id): cover_id = "opening.image.03"
	var texture: Texture2D = art.texture(cover_id)
	if cover_id.begins_with("opening.image."):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/opening-intro/scenes.json"))
		var region: Array = data.scenes[int(cover_id.get_slice(".",2))-1].display_region
		var cropped := AtlasTexture.new(); cropped.atlas = texture
		cropped.region = Rect2(region[0],region[1],region[2],region[3])
		texture = cropped
	return texture
