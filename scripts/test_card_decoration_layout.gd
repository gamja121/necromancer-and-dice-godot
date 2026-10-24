extends SceneTree
## Altar enhancement badge must follow the real layered monster card
## without restoring obsolete brand-count borders or flattened PNG textures.
## Run: godot --headless --path . --script res://scripts/test_card_decoration_layout.gd

const AltarBadge = preload("res://systems/altar_upgrade_badge.gd")
const LayeredUnitCard = preload("res://systems/layered_unit_card.gd")

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS card-decoration: ", label)
	else:
		failed += 1
		printerr("FAIL card-decoration: ", label)

func card_button(dimensions: Vector2) -> TextureButton:
	var card := TextureButton.new()
	card.ignore_texture_size = true
	card.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	card.size = dimensions
	root.add_child(card)
	check(LayeredUnitCard.install(card,"skeleton-archer","해골 궁수"),"real layered monster preview installed")
	return card

func check_layout(card: Control, case_name: String) -> void:
	var source := card.get_node_or_null("LayeredCardPreview") as TextureButton
	if source == null and card is TextureButton:
		source = card as TextureButton
	check(source != null and source.texture_normal == null and source.has_node("LayeredCardBase") and source.has_node("LayeredCardCharacter"),
		case_name+" shows new layered card art, never a flat texture")
	var visual_children := card.get_child_count()
	var brands: Array = [{"type":"critical"},{"type":"guard"},{"type":"freeze"}]
	var unit := {"brands":brands,"altar_enhancements":3}
	AltarBadge.sync(card,unit)
	var badge := card.get_node_or_null("AltarUpgradeBadge") as TextureRect
	check(badge != null,case_name+" +3 badge present")
	if badge == null: return
	check(card.get_child_count()==visual_children+1,case_name+" adds only one badge, no border")
	check(badge.texture==AltarBadge.BADGE_3,case_name+" +3 texture")
	var art: Rect2 = AltarBadge._art_rect(card)
	check(absf((badge.position.x+badge.size.x*0.5)-(art.position.x+art.size.x*0.5))<0.02,case_name+" badge centered")
	check(absf(badge.position.y-(art.position.y+art.size.y*0.01))<0.02,case_name+" badge on top line")
	check(badge.get_parent()==card and badge.z_index==0,case_name+" badge follows parent overlap")
	check(badge.mouse_filter==Control.MOUSE_FILTER_IGNORE,case_name+" badge cannot block clicks")
	for count in range(4):
		unit.brands = brands.slice(0,count)
		if source != null: LayeredUnitCard.sync_brands(source,unit.brands)
		AltarBadge.sync(card,unit)
		check(card.get_child_count()==visual_children+1 and card.get_node_or_null("AltarUpgradeBadge")==badge,
			case_name+" brand count %d does not add any border" % count)
	unit.altar_enhancements = 0
	AltarBadge.sync(card,unit)
	check(card.get_node_or_null("AltarUpgradeBadge")==null and card.get_child_count()==visual_children,case_name+" zero altar level leaves only the live card layers")
	for level in range(1,4):
		unit.altar_enhancements = level
		AltarBadge.sync(card,unit)
		var plaque := card.get_node_or_null("AltarUpgradeBadge") as TextureRect
		check(plaque!=null and plaque.texture==[AltarBadge.BADGE_1,AltarBadge.BADGE_2,AltarBadge.BADGE_3][level-1],
			case_name+" correct altar plaque +"+str(level))
	card.queue_free()

func _run() -> void:
	check_layout(card_button(Vector2(136,218)),"inventory")
	check_layout(card_button(Vector2(96,139)),"altar and inheritance")
	check_layout(card_button(Vector2(121.856,225.216)),"deck hand")
	check_layout(card_button(Vector2(78.93,115.2)),"battle")
	var preview := TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = Vector2(150,208)
	root.add_child(preview)
	check(LayeredUnitCard.sync_preview(preview,{"slug":"skeleton-archer","name":"해골 궁수","brands":[]}),"real layered TextureRect preview installed")
	check_layout(preview,"preview TextureRect")
	print("CARD_DECORATION_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
