extends SceneTree
## Visual-layout contract for card brands (0..3) and independent altar upgrades (0..3).
## Run: godot --headless --path . --script res://scripts/test_card_decoration_layout.gd

const BrandFrame = preload("res://systems/brand_frame_overlay.gd")
const AltarBadge = preload("res://systems/altar_upgrade_badge.gd")
const CARD_ART = preload("res://assets/cards/unit-card-skeleton-archer.png")

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS card-decoration: ", label)
	else:
		failed += 1
		printerr("FAIL card-decoration: ", label)

func close_to(first: Vector2, second: Vector2) -> bool:
	return first.distance_to(second) < 0.02

func card_button(dimensions: Vector2) -> TextureButton:
	var card := TextureButton.new()
	card.texture_normal = CARD_ART
	card.ignore_texture_size = true
	card.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	card.size = dimensions
	root.add_child(card)
	return card

func check_layout(card: Control, case_name: String) -> void:
	var full = {"brands":[{"type":"critical"},{"type":"guard"},{"type":"freeze"}],"altar_enhancements":3}
	BrandFrame.sync(card,full)
	AltarBadge.sync(card,full)
	var iron := card.get_node_or_null("BrandFrameOverlay") as TextureRect
	var badge := card.get_node_or_null("AltarUpgradeBadge") as TextureRect
	check(iron != null and badge != null,case_name+" 3 brands and +3 coexist")
	if iron == null or badge == null: return
	check(iron.texture == BrandFrame.IRON_FRAME,case_name+" iron frame texture")
	check(badge.texture == AltarBadge.BADGE_3,case_name+" +3 plaque texture")
	var art: Rect2 = BrandFrame._card_art_rect(card)
	var wood_frame_size := Vector2(art.size.x*BrandFrame.FRAME_WIDTH_FACTOR,art.size.y*BrandFrame.FRAME_HEIGHT_FACTOR)
	var target_pos: Vector2 = art.position+(art.size-wood_frame_size)*0.5
	check(close_to(iron.size,wood_frame_size) and close_to(iron.position,target_pos),case_name+" matches 2-brand frame bounds")
	check(absf((badge.position.x+badge.size.x*0.5)-(art.position.x+art.size.x*0.5))<0.02,case_name+" plaque centered")
	check(absf(badge.position.y-(art.position.y+art.size.y*0.01))<0.02,case_name+" plaque on top line")
	check(iron.get_parent()==card and badge.get_parent()==card and iron.z_index==0 and badge.z_index==0,case_name+" both decorations follow card overlap")
	check(iron.mouse_filter==Control.MOUSE_FILTER_IGNORE and badge.mouse_filter==Control.MOUSE_FILTER_IGNORE,case_name+" card interaction remains unblocked")
	var reference_pos: Vector2 = iron.position
	var reference_size: Vector2 = iron.size
	full.brands = [{"type":"critical"},{"type":"guard"}]
	BrandFrame.sync(card,full)
	var wood := card.get_node_or_null("BrandFrameOverlay") as TextureRect
	check(wood != null and wood.texture == BrandFrame.WOOD_FRAME,case_name+" 2-brand wood frame")
	if wood != null:
		check(close_to(wood.position,reference_pos) and close_to(wood.size,reference_size),case_name+" 2/3 frames exactly aligned")
	full.brands = [{"type":"critical"}]
	BrandFrame.sync(card,full)
	AltarBadge.sync(card,full)
	check(card.get_node_or_null("BrandFrameOverlay")==null and card.get_node_or_null("AltarUpgradeBadge")!=null,case_name+" +3 allowed at 1 brand")
	full.brands = []
	BrandFrame.sync(card,full)
	AltarBadge.sync(card,full)
	check(card.get_node_or_null("BrandFrameOverlay")==null and card.get_node_or_null("AltarUpgradeBadge")!=null,case_name+" +3 allowed at 0 brands")
	full.brands = [{"type":"critical"},{"type":"guard"},{"type":"freeze"}]
	full.altar_enhancements = 0
	BrandFrame.sync(card,full)
	AltarBadge.sync(card,full)
	check(card.get_node_or_null("BrandFrameOverlay")!=null and card.get_node_or_null("AltarUpgradeBadge")==null,case_name+" 3 brands allowed without altar enhancement")
	for level in range(1,4):
		full.altar_enhancements = level
		AltarBadge.sync(card,full)
		var plaque := card.get_node_or_null("AltarUpgradeBadge") as TextureRect
		check(plaque!=null and plaque.texture==[AltarBadge.BADGE_1,AltarBadge.BADGE_2,AltarBadge.BADGE_3][level-1],case_name+" correct altar plaque +"+str(level))
	card.queue_free()

func _run() -> void:
	check_layout(card_button(Vector2(136,218)),"inventory")
	check_layout(card_button(Vector2(96,139)),"altar and inheritance")
	check_layout(card_button(Vector2(121.856,225.216)),"deck hand")
	check_layout(card_button(Vector2(78.93,115.2)),"battle")
	var preview := TextureRect.new()
	preview.texture = CARD_ART
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = Vector2(150,208)
	root.add_child(preview)
	check_layout(preview,"preview TextureRect")
	print("CARD_DECORATION_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
