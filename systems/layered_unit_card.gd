extends RefCounted
## In-game layered cards use the same live background / separate portrait / ribbon / brands.
## Gameplay and TextureButton inputs stay unchanged. Character pose/size can vary.
## Each layer is an independent TextureRect so portrait zoom never enlarges the UI.

class NameCaption extends Label:
	func _notification(what: int) -> void:
		if what==NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree(): call_deferred("fit_name")
	func fit_name() -> void:
		var points: int=int(get_meta("name_base_points",get_theme_font_size("font_size")))
		var shown := text if auto_translate_mode==Node.AUTO_TRANSLATE_MODE_DISABLED else tr(text)
		var font := get_theme_font("font")
		while points>8 and font.get_string_size(shown,HORIZONTAL_ALIGNMENT_LEFT,-1,points).x>size.x:
			points-=1
		add_theme_font_size_override("font_size",points)
static var canonical_names: Dictionary = {}
static func is_custom_name(slug: String, title: String) -> bool:
	if canonical_names.is_empty():
		var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json"))
		for key in data.units: canonical_names[str(key)]=str(data.units[key].name)
	return canonical_names.has(slug) and title!=str(canonical_names[slug])

const UnitInfo = preload("res://systems/unit_info.gd")
const ROOT := "res://assets/cards/layered/"
const BACKGROUND := ROOT + "base_skeleton.webp"
const NAMEPLATE := ROOT + "scroll_nameplate.webp"
const PORTRAITS := {
	"skeleton-spear": ROOT + "skeleton_spear.webp",
	"skeleton-archer": ROOT + "skeleton_archer.webp",
	"corpse-slime": ROOT + "corpse_slime.webp",
	"dracula": ROOT + "dracula.webp",
	"ice-lord": ROOT + "ice_lord.webp",
	"grave-worm": ROOT + "grave_worm.webp",
	"skeleton-cavalry": ROOT + "skeleton_cavalry.webp",
	"mummy-guardian": ROOT + "mummy_guardian.webp",
	"soul-reaper": ROOT + "soul_reaper.webp",
	"bone-hound": ROOT + "bone_hound.webp",
	"mimic": ROOT + "mimic.webp",
	"ice-princess": ROOT + "ice_princess.webp",
	"hydra": ROOT + "hydra.webp",
	"flesh-golem": ROOT + "flesh_golem.webp",
	"forest-fairy": ROOT + "forest_fairy.webp",
	"bone-golem": ROOT + "bone_golem.webp",
	"abyss-harpy": ROOT + "abyss_harpy.webp",
	"boulder-ogre": ROOT + "boulder_ogre.webp",
	"orc-warrior": ROOT + "orc_warrior.webp",
	"goblin-rider": ROOT + "goblin_rider.webp",
	"mushroom-soldier": ROOT + "mushroom_soldier.webp",
	"cerberus": ROOT + "cerberus.webp",
	"ancient-treant": ROOT + "ancient_treant.webp",
	"spider-knight": ROOT + "spider_knight.webp",
	"crystal-devourer": ROOT + "crystal_devourer.webp",
	"kraken": ROOT + "kraken.webp",
	"stone-golem": ROOT + "stone_golem.webp",
	"raging-treant": ROOT + "raging_treant.webp",
	"scorpion-knight": ROOT + "scorpion_knight.webp",
	"death-knight": ROOT + "death_knight.webp",
	"hell-mantis": ROOT + "hell_mantis.webp",
	"doom-executor": ROOT + "doom_executor.webp",
	"abyss-eye": ROOT + "abyss_eye.webp",
	"sea-wolf": ROOT + "sea_wolf.webp",
	"goblin-soldier": ROOT + "goblin_soldier.webp",
	"goblin-chief": ROOT + "goblin_chief.webp",
	"ghoul": ROOT + "ghoul.webp",
	"plague-doctor": ROOT + "plague_doctor.webp",
	"yeti": ROOT + "yeti.webp",
	"grave-priest": ROOT + "grave_priest.webp",
	"minotaur": ROOT + "minotaur.webp",
	"goblin-commoner": ROOT + "goblin_commoner.webp",
	"spiderling": ROOT + "spiderling.webp",
	"guardian-seed": ROOT + "guardian_seed.webp",
	"abyss-claw-hunter": ROOT + "abyss_claw_hunter.webp",
	"plague-frog": ROOT + "plague_frog.webp",
	"siren": ROOT + "siren.webp",
}

# Legion scenery stays clipped to the paper card; the character is independent
# and can protrude beyond the frame. The two existing skeleton cards keep their
# already-approved background and layout.
const BACKGROUNDS := {
	"corpse-slime": ROOT + "base_corpse.webp",
	"dracula": ROOT + "base_demon.webp",
	"ice-lord": ROOT + "base_ice.webp",
	"grave-worm": ROOT + "base_plague.webp",
	"skeleton-cavalry": ROOT + "base_skeleton_mist.webp",
	"mummy-guardian": ROOT + "base_corpse.webp",
	"soul-reaper": ROOT + "base_skeleton_mist.webp",
	"bone-hound": ROOT + "base_corpse.webp",
	"mimic": ROOT + "base_summon.webp",
	"ice-princess": ROOT + "base_ice.webp",
	"hydra": ROOT + "base_plague.webp",
	"flesh-golem": ROOT + "base_corpse.webp",
	"forest-fairy": ROOT + "base_plant.webp",
	"bone-golem": ROOT + "base_skeleton_mist.webp",
	"abyss-harpy": ROOT + "base_demon.webp",
	"boulder-ogre": ROOT + "base_beast.webp",
	"orc-warrior": ROOT + "base_beast.webp",
	"goblin-rider": ROOT + "base_beast.webp",
	"mushroom-soldier": ROOT + "base_plant.webp",
	"cerberus": ROOT + "base_beast.webp",
	"ancient-treant": ROOT + "base_plant.webp",
	"spider-knight": ROOT + "base_summon.webp",
	"crystal-devourer": ROOT + "base_plant.webp",
	"kraken": ROOT + "base_ice.webp",
	"stone-golem": ROOT + "base_beast.webp",
	"raging-treant": ROOT + "base_plant.webp",
	"scorpion-knight": ROOT + "base_plague.webp",
	"death-knight": ROOT + "base_demon.webp",
	"hell-mantis": ROOT + "base_plague.webp",
	"doom-executor": ROOT + "base_demon.webp",
	"abyss-eye": ROOT + "base_demon.webp",
	"sea-wolf": ROOT + "base_ice.webp",
	"goblin-soldier": ROOT + "base_beast.webp",
	"goblin-chief": ROOT + "base_beast.webp",
	"ghoul": ROOT + "base_corpse.webp",
	"plague-doctor": ROOT + "base_plague.webp",
	"yeti": ROOT + "base_ice.webp",
	"grave-priest": ROOT + "base_skeleton_mist.webp",
	"minotaur": ROOT + "base_beast.webp",
	"goblin-commoner": ROOT + "base_beast.webp",
	"spiderling": ROOT + "base_summon.webp",
	"guardian-seed": ROOT + "base_plant.webp",
	"abyss-claw-hunter": ROOT + "base_demon.webp",
	"plague-frog": ROOT + "base_plague.webp",
	"siren": ROOT + "base_ice.webp",
}

const WIDE_PORTRAITS := [
	"skeleton-archer", "corpse-slime", "grave-worm",
	"skeleton-cavalry", "bone-hound", "mimic",
	"hydra", "flesh-golem", "bone-golem", "abyss-harpy",
	"boulder-ogre", "orc-warrior",
	"goblin-rider", "cerberus", "ancient-treant", "spider-knight", "crystal-devourer", "kraken",
	"stone-golem", "raging-treant", "scorpion-knight", "death-knight", "hell-mantis",
	"doom-executor",
	"abyss-eye", "grave-priest", "sea-wolf", "goblin-chief", "yeti",
	"minotaur", "spiderling",
	"abyss-claw-hunter", "plague-frog", "siren",
]
# All visible parchment cards keep one portrait ratio, even when UI slots differ.
# The 136 x 218 approved book card is the reference; no hit target is resized.
const CARD_ASPECT := 136.0 / 218.0
const PORTRAIT_HEIGHT := 0.76
# Uniformly reduce only the visible character artwork. Scenery, card hitbox,
# ribbon, name and branded badge dimensions stay at their approved values.
const PORTRAIT_VISUAL_SCALE := 0.90
const PORTRAIT_BASELINE := 0.65
const PORTRAIT_WIDTH_NORMAL := 1.12
const PORTRAIT_WIDTH_WIDE := 1.30
static var _used_rect_cache: Dictionary = {}
const BASE_NAME := "LayeredCardBase"
const ACTOR_NAME := "LayeredCardCharacter"
const BANNER_NAME := "LayeredCardRibbon"
const TEXT_NAME := "LayeredCardTitle"
const BRAND_ROW_NAME := "LayeredCardBrands"
const BRAND_ICON_SHEET = preload("res://assets/battle/ui/brand-icons-sheet.jpg")
const BRAND_ICON_EXTRA = preload("res://assets/battle/ui/brand-icons-extra-sheet.jpg")

static func supports(slug: String) -> bool:
	return PORTRAITS.has(slug) or slug=="dragon"

static func _art(parent: Control, name: String, texture: Texture2D) -> TextureRect:
	var item := TextureRect.new()
	item.name = name
	item.texture = texture
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_SCALE
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.focus_mode = Control.FOCUS_NONE
	# The parent's hover/death shader should shade the visible layers, not
	# only the transparent TextureButton hit area.
	item.material = parent.material
	parent.add_child(item)
	return item

static func install(card: TextureButton, slug: String, title: String, selected: bool = false, brands: Array = []) -> bool:
	if not supports(slug) or card.has_node(BASE_NAME):
		return false
	var background_path: String = str(BACKGROUNDS.get(slug, BACKGROUND))
	# Boss has no legacy flattened card: reuse its new neutral combat art.
	var portrait_path: String = "res://assets/battle/frames/dragon/attack-01.png" if slug=="dragon" else str(PORTRAITS.get(slug,""))
	if not (ResourceLoader.exists(background_path) and ResourceLoader.exists(NAMEPLATE) and ResourceLoader.exists(portrait_path)):
		return false
	var original_texture := card.texture_normal
	# Keep the original TextureButton texture identity for existing card
	# presentations/tests and hit-area sizing; render ONLY the live layers.
	# self_modulate affects this CanvasItem, not its TextureRect children.
	card.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	card.ignore_texture_size = true
	card.clip_contents = false # spear/bow/skull can extend beyond the card edge
	card.set_meta("layered_original_texture", original_texture)
	card.set_meta("layered_slug", slug)
	card.set_meta("layered_selected", selected)
	card.set_meta("layered_hover", false)
	_art(card, BASE_NAME, load(background_path))
	var actor := _art(card, ACTOR_NAME, load(portrait_path))
	# Exact source proportions are preserved by setting actor.size from texture size.
	actor.stretch_mode = TextureRect.STRETCH_SCALE
	_art(card, BANNER_NAME, load(NAMEPLATE))
	var caption := NameCaption.new()
	caption.name = TEXT_NAME
	caption.text = title
	caption.clip_text=true
	caption.set_meta("ui_font_preserve",true)
	if is_custom_name(slug,title):
		caption.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
		card.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", Color("24160e"))
	caption.add_theme_color_override("font_shadow_color", Color("dfb98b82"))
	caption.add_theme_constant_override("shadow_offset_y", 1)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(caption)
	sync_brands(card, brands)
	card.resized.connect(func(): relayout(card))
	card.mouse_entered.connect(func(): _focus(card, true))
	card.mouse_exited.connect(func(): _focus(card, false))
	card.focus_entered.connect(func(): _focus(card, true))
	card.focus_exited.connect(func(): _focus(card, false))
	relayout(card)
	_apply_scale(card, false)
	return true

## Full layered art for non-interactive material/target/detail previews.
## The parent TextureRect remains the original stable animation and badge anchor.
## No obsolete flattened unit-card PNG is loaded on this path.
static func sync_preview(preview: TextureRect, unit: Dictionary) -> bool:
	if not is_instance_valid(preview): return false
	var previous := preview.get_node_or_null("LayeredCardPreview")
	if previous != null:
		preview.remove_child(previous)
		previous.queue_free()
	preview.texture = null
	if unit.is_empty(): return true
	var actor := TextureButton.new()
	actor.name = "LayeredCardPreview"
	actor.ignore_texture_size = true
	actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor.focus_mode = Control.FOCUS_NONE
	actor.size = preview.size
	preview.add_child(actor)
	actor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not install(actor, str(unit.get("slug", "")), str(unit.get("name", "")), false, unit.get("brands", [])):
		preview.remove_child(actor)
		actor.queue_free()
		return false
	return true

static func make_preview(parent: Control, unit: Dictionary, pos: Vector2, dimensions: Vector2) -> TextureRect:
	var preview := TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.position = pos
	preview.size = dimensions
	parent.add_child(preview)
	sync_preview(preview, unit)
	return preview

## Visible pixels, not source canvas margins, determine the silhouette scale.
## Image.get_used_rect is executed once per approved texture; layout itself is cheap.
static func _portrait_used_rect(texture: Texture2D) -> Rect2:
	var key := texture.resource_path
	if _used_rect_cache.has(key):
		return _used_rect_cache[key]
	var used := Rect2(Vector2.ZERO, texture.get_size())
	var image := texture.get_image()
	if image != null and not image.is_empty():
		var alpha_rect := image.get_used_rect()
		if alpha_rect.size.x > 0 and alpha_rect.size.y > 0:
			used = Rect2(Vector2(alpha_rect.position), Vector2(alpha_rect.size))
	_used_rect_cache[key] = used
	return used

static func visible_card_rect(slot_size: Vector2) -> Rect2:
	if slot_size.x <= 0.0 or slot_size.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var height := minf(slot_size.y, slot_size.x / CARD_ASPECT)
	var extent := Vector2(height * CARD_ASPECT, height)
	return Rect2((slot_size - extent) * 0.5, extent)

static func relayout(card: TextureButton) -> void:
	if not is_instance_valid(card):
		return
	var base := card.get_node_or_null(BASE_NAME) as TextureRect
	var actor := card.get_node_or_null(ACTOR_NAME) as TextureRect
	var ribbon := card.get_node_or_null(BANNER_NAME) as TextureRect
	var caption := card.get_node_or_null(TEXT_NAME) as Label
	if base == null or actor == null or ribbon == null or caption == null:
		return
	var rect := visible_card_rect(card.size)
	var extent := rect.size
	if extent.x <= 0.0 or extent.y <= 0.0:
		return
	# The base is paper artwork, not a gameplay sprite. Fit the same visible
	# parchment rectangle at all slots without changing button hit boxes.
	base.stretch_mode = TextureRect.STRETCH_SCALE
	base.position = rect.position
	base.size = extent
	var slug := str(card.get_meta("layered_slug", ""))
	var used := _portrait_used_rect(actor.texture)
	var source := actor.texture.get_size()
	# Fit the *nontransparent* body to a shared height and ground line while
	# retaining wide beasts' silhouettes. Never crop or stretch the portrait.
	var allowed_width := extent.x * (PORTRAIT_WIDTH_WIDE if slug in WIDE_PORTRAITS else PORTRAIT_WIDTH_NORMAL)
	var fit_scale := minf(extent.y * PORTRAIT_HEIGHT / maxf(used.size.y, 1.0), allowed_width / maxf(used.size.x, 1.0))
	# Reuse the original horizontal center and foot line. Only the opaque
	# character silhouette shrinks 10%, regardless of source canvas margins.
	var art_scale := fit_scale * PORTRAIT_VISUAL_SCALE
	var visible_size := used.size * art_scale
	var visible_left := rect.position.x + (extent.x - visible_size.x) * 0.5
	var visible_top := rect.position.y + extent.y * PORTRAIT_BASELINE - visible_size.y
	actor.size = source * art_scale
	actor.position = Vector2(visible_left, visible_top) - used.position * art_scale
	actor.pivot_offset = actor.size * 0.5
	ribbon.position = rect.position + Vector2(-extent.x * 0.055, extent.y * 0.592)
	ribbon.size = Vector2(extent.x * 1.11, extent.y * 0.175)
	caption.position = ribbon.position + Vector2(ribbon.size.x * 0.10, ribbon.size.y * 0.17)
	caption.size = Vector2(ribbon.size.x * 0.80, ribbon.size.y * 0.63)
	caption.set_meta("name_base_points",maxi(8,int(extent.y*0.077)))
	caption.fit_name()
	# Center the whole brand group inside the card's bottom information panel.
	# Cap icon size to keep three engraved brands equally spaced and fully in bounds.
	var brand_row := card.get_node_or_null(BRAND_ROW_NAME) as Control
	if brand_row != null:
		brand_row.position = rect.position + Vector2(extent.x * 0.14, extent.y * 0.79)
		brand_row.size = Vector2(extent.x * 0.72, extent.y * 0.13)
		var icon_count := brand_row.get_child_count()
		if icon_count > 0:
			var gap := extent.x * 0.024
			var inset := extent.x * 0.018
			var available := maxf(0.0, brand_row.size.x - inset * 2.0 - gap * float(icon_count - 1))
			var side := minf(minf(extent.x * 0.235, extent.y * 0.125), available / float(icon_count))
			var total_width := side * float(icon_count) + gap * float(icon_count - 1)
			var start_x := (brand_row.size.x - total_width) * 0.5
			var start_y := (brand_row.size.y - side) * 0.5
			for i in range(icon_count):
				var icon := brand_row.get_child(i) as TextureRect
				if icon != null:
					icon.position = Vector2(start_x + float(i) * (side + gap), start_y)
					icon.size = Vector2(side, side)


## Same icon atlas coordinates as the original unit information window.
## All this state is transient visual data; do not modify the roster.
static func sync_brands(card: TextureButton, brands: Array) -> void:
	if not card.has_node(BASE_NAME): return
	var row := card.get_node_or_null(BRAND_ROW_NAME) as Control
	if row == null:
		row = Control.new()
		row.name = BRAND_ROW_NAME
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.clip_contents = false
		card.add_child(row)
	var keys: Array[String] = []
	for brand in brands:
		if keys.size() >= 3: break
		if not (brand is Dictionary): continue
		var kind := str(brand.get("type", ""))
		if UnitInfo.ICONS.has(kind): keys.append(kind)
	var signature := ",".join(keys)
	if card.get_meta("layered_brand_signature", "#new") == signature: return
	card.set_meta("layered_brand_signature", signature)
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for kind in keys:
		var atlas := AtlasTexture.new()
		atlas.atlas = BRAND_ICON_EXTRA if kind in ["combo", "freeze", "lightspeed", "counter"] else BRAND_ICON_SHEET
		atlas.region = UnitInfo.ICONS[kind]
		var icon := TextureRect.new()
		icon.name = "BrandIcon_%d" % row.get_child_count()
		icon.texture = atlas
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.material = card.material
		row.add_child(icon)
	relayout(card)

## Copy the current composited card for animations, not the obsolete
## flattened unit-card image kept for compatibility with existing tests.
static func flight_visual_copy(card: TextureButton) -> Control:
	if not card.has_node(BASE_NAME): return null
	var flyer := Control.new()
	flyer.name = "LayeredCardFlight"
	flyer.size = card.size
	flyer.clip_contents = false
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.modulate = card.modulate
	for child in card.get_children():
		if child.name in [BASE_NAME, ACTOR_NAME, BANNER_NAME, TEXT_NAME, BRAND_ROW_NAME, "AltarUpgradeBadge"]:
			var copied := child.duplicate(0) as Control
			if copied != null:
				copied.mouse_filter = Control.MOUSE_FILTER_IGNORE
				flyer.add_child(copied)
	return flyer

static func _apply_scale(card: TextureButton, animate: bool) -> void:
	var actor := card.get_node_or_null(ACTOR_NAME) as TextureRect
	if actor == null: return
	var raised := bool(card.get_meta("layered_selected", false)) or bool(card.get_meta("layered_hover", false))
	var target := Vector2.ONE * (1.10 if raised else 1.0)
	if animate and actor.is_inside_tree():
		var active: Tween = card.get_meta("layered_actor_tween") if card.has_meta("layered_actor_tween") else null
		if active != null and active.is_valid(): active.kill()
		var motion := actor.create_tween()
		card.set_meta("layered_actor_tween", motion)
		motion.tween_property(actor, "scale", target, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		actor.scale = target

static func _focus(card: TextureButton, focused: bool) -> void:
	if not is_instance_valid(card) or bool(card.get_meta("card_in_transfer", false)):
		return
	card.set_meta("layered_hover", focused)
	_apply_scale(card, true)

static func set_selected(card: TextureButton, selected: bool) -> void:
	if not is_instance_valid(card) or not card.has_node(ACTOR_NAME): return
	card.set_meta("layered_selected", selected)
	_apply_scale(card, true)
