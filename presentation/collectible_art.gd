extends TextureRect
## One shared transparent low-poly relic image until individual art is supplied.
const ASSET_ID:="texture.collectible.placeholder"
static var _fallback_assets=preload("res://presentation/asset_catalog.gd").new()
func configure(_id: String, visual_assets: RefCounted = null) -> void:
	name="CollectiblePlaceholder"
	var cache: RefCounted=visual_assets if visual_assets!=null else _fallback_assets
	texture=cache.texture(ASSET_ID)
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2.ZERO
