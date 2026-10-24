extends SceneTree
## Usage: godot --headless --path . --script res://scripts/test_layered_unit_cards.gd
const Layered = preload("res://systems/layered_unit_card.gd")
const SoulCapture = preload("res://systems/corpse_capture.gd")
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, name: String) -> void:
	if ok:
		print("PASS layered-card: ", name)
	else:
		failed += 1
		printerr("FAIL layered-card: ", name)

func _brand_positions_ok(row: Control, base: TextureRect, expected_count: int) -> bool:
	if row == null or base == null or row.get_child_count() != expected_count:
		return false
	if absf(row.position.x + row.size.x * 0.5 - (base.position.x + base.size.x * 0.5)) > 0.5:
		return false
	if expected_count == 0:
		return true
	var first := row.get_child(0) as TextureRect
	var last := row.get_child(expected_count - 1) as TextureRect
	if first == null or last == null:
		return false
	var left_space := first.position.x
	var right_space := row.size.x - (last.position.x + last.size.x)
	if left_space < -0.5 or right_space < -0.5 or absf(left_space - right_space) > 0.5:
		return false
	var prior_icon: TextureRect = null
	var previous_gap := -1.0
	for i in range(expected_count):
		var icon := row.get_child(i) as TextureRect
		if icon == null or icon.size.x <= 0.0 or absf(icon.size.x - icon.size.y) > 0.5:
			return false
		if icon.position.x < -0.5 or icon.position.x + icon.size.x > row.size.x + 0.5:
			return false
		if icon.position.y < -0.5 or icon.position.y + icon.size.y > row.size.y + 0.5:
			return false
		if absf(icon.position.y - (row.size.y - icon.size.y) * 0.5) > 0.5:
			return false
		if prior_icon != null:
			var gap := icon.position.x - (prior_icon.position.x + prior_icon.size.x)
			if gap < -0.5 or (previous_gap >= 0.0 and absf(gap - previous_gap) > 0.5):
				return false
			previous_gap = gap
		prior_icon = icon
	return true

func _run() -> void:
	# Runtime card art is opt-in by slug. All forty-seven share the same zoom,
	# real owned brands, return-to-book visual layers and legacy hit texture.
	var expected_backgrounds := {
		"skeleton-spear": "base_skeleton.webp",
		"skeleton-archer": "base_skeleton.webp",
		"corpse-slime": "base_corpse.webp",
		"dracula": "base_demon.webp",
		"ice-lord": "base_ice.webp",
		"grave-worm": "base_plague.webp",
		"skeleton-cavalry": "base_skeleton_mist.webp",
		"mummy-guardian": "base_corpse.webp",
		"soul-reaper": "base_skeleton_mist.webp",
		"bone-hound": "base_corpse.webp",
		"mimic": "base_summon.webp",
		"ice-princess": "base_ice.webp",
		"hydra": "base_plague.webp",
		"flesh-golem": "base_corpse.webp",
		"forest-fairy": "base_plant.webp",
		"bone-golem": "base_skeleton_mist.webp",
		"abyss-harpy": "base_demon.webp",
		"boulder-ogre": "base_beast.webp",
		"orc-warrior": "base_beast.webp",
	"goblin-rider": "base_beast.webp",
	"mushroom-soldier": "base_plant.webp",
	"cerberus": "base_beast.webp",
	"ancient-treant": "base_plant.webp",
	"spider-knight": "base_summon.webp",
	"crystal-devourer": "base_plant.webp",
	"kraken": "base_ice.webp",
	"stone-golem": "base_beast.webp",
	"raging-treant": "base_plant.webp",
	"scorpion-knight": "base_plague.webp",
	"death-knight": "base_demon.webp",
	"hell-mantis": "base_plague.webp",
	"doom-executor": "base_demon.webp",
	"abyss-eye": "base_demon.webp",
	"sea-wolf": "base_ice.webp",
	"goblin-soldier": "base_beast.webp",
	"goblin-chief": "base_beast.webp",
	"ghoul": "base_corpse.webp",
	"plague-doctor": "base_plague.webp",
	"yeti": "base_ice.webp",
	"grave-priest": "base_skeleton_mist.webp",
	"minotaur": "base_beast.webp",
	"goblin-commoner": "base_beast.webp",
	"spiderling": "base_summon.webp",
	"guardian-seed": "base_plant.webp",
	"abyss-claw-hunter": "base_demon.webp",
	"plague-frog": "base_plague.webp",
	"siren": "base_ice.webp",
	}
	check(expected_backgrounds.size() == 47, "all 47 real monster slugs have approved layered scenery")
	for slug in expected_backgrounds.keys():
		for dims in [Vector2(136,218), Vector2(121.856,225.216), Vector2(90,120), Vector2(170,302.4)]:
			var card := TextureButton.new()
			card.size = dims
			card.ignore_texture_size = true
			card.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			# The legacy PNG is not required even as a hidden hit texture.
			var original: Texture2D = null
			root.add_child(card)
			var owned_brands: Array = [{"type":"critical"}, {"type":"freeze"}, {"type":"counter"}]
			check(Layered.install(card, slug, "검사 이름", false, owned_brands), "%s installed at %s" % [slug, dims])
			check(card.texture_normal == original, "layered art needs no flattened hit texture")
			check(is_zero_approx(card.self_modulate.a), "only the flattened art is hidden, not the children")
			var base := card.get_node_or_null("LayeredCardBase") as TextureRect
			var actor := card.get_node_or_null("LayeredCardCharacter") as TextureRect
			var ribbon := card.get_node_or_null("LayeredCardRibbon") as TextureRect
			var title := card.get_node_or_null("LayeredCardTitle") as Label
			var brands := card.get_node_or_null("LayeredCardBrands") as Control
			check(brands != null and brands.get_child_count() == 3, "three owned brands displayed with atlas art")
			if brands != null and brands.get_child_count() == 3:
				var first := brands.get_child(0) as TextureRect
				var second := brands.get_child(1) as TextureRect
				var third := brands.get_child(2) as TextureRect
				check(first.texture is AtlasTexture and second.texture is AtlasTexture and third.texture is AtlasTexture, "brand icons use existing atlases")
				check(_brand_positions_ok(brands, base, 3), "%s three brands centered with equal gaps and no overflow at %s" % [slug, dims])
				var bg_extent := base.size
				var previous_side := minf(bg_extent.x * 0.19, bg_extent.y * 0.098)
				check(first.size.x >= previous_side * 1.10 and first.size.y >= previous_side * 1.10, "three centered brand icons remain readable on small cards")
			# Compare actual displayed geometry, not just resized TextureRects.
			var rect := Layered.visible_card_rect(dims)
			check(absf(base.size.x / base.size.y - Layered.CARD_ASPECT) < 0.0001, "%s parchment ratio is canonical at %s" % [slug, dims])
			check(base.position.distance_to(rect.position) < 0.03 and base.size.distance_to(rect.size) < 0.03, "%s parchment centered in slot at %s" % [slug, dims])
			var alpha := actor.texture.get_image().get_used_rect()
			if alpha.size.x > 0 and alpha.size.y > 0:
				var px_scale := actor.size.x / actor.texture.get_size().x
				var painted := Rect2(actor.position + Vector2(alpha.position) * px_scale, Vector2(alpha.size) * px_scale)
				check(absf(painted.position.x + painted.size.x * 0.5 - (rect.position.x + rect.size.x * 0.5)) < 0.55, "%s real opaque body is horizontally centered at %s" % [slug, dims])
				check(absf(painted.end.y - (rect.position.y + rect.size.y * Layered.PORTRAIT_BASELINE)) < 0.55, "%s body shares the same foot line at %s" % [slug, dims])
				check(painted.size.y <= rect.size.y * Layered.PORTRAIT_HEIGHT + 0.55, "%s visible portrait fits card height at %s" % [slug, dims])
				check(painted.size.x <= rect.size.x * Layered.PORTRAIT_WIDTH_WIDE + 0.55, "%s wide details keep their width budget at %s" % [slug, dims])
				# Calculate the previous approved fit independently: new pixel
				# art must be exactly 90% at every slot, wide or tall species.
				var original_width_budget := rect.size.x * (Layered.PORTRAIT_WIDTH_WIDE if slug in Layered.WIDE_PORTRAITS else Layered.PORTRAIT_WIDTH_NORMAL)
				var original_fit_scale := minf(rect.size.y * Layered.PORTRAIT_HEIGHT / maxf(float(alpha.size.y),1.0),original_width_budget / maxf(float(alpha.size.x),1.0))
				var expected_art_size := Vector2(alpha.size) * original_fit_scale * 0.90
				check(painted.size.distance_to(expected_art_size) < 0.12,"%s artwork alone renders at 90 percent of previously approved size at %s" % [slug,dims])
				check(absf(actor.scale.x-1.0)<0.01 and absf(actor.scale.y-1.0)<0.01,"%s 90 percent is baked into art layout without shrinking card or interaction hit area" % slug)
			check(ribbon.position.y > base.position.y and ribbon.position.y < base.position.y + base.size.y, "%s title ribbon stays within parchment at %s" % [slug, dims])
			if dims == Vector2(136,218):
				# Regression: a defeated enemy must not revert to the
				# flattened source card on the post-victory soul harvest screen.
				var reward_choice: TextureButton = SoulCapture.make_choice_card(card, {"slug":slug,"name":"검사 이름","brands":owned_brands})
				root.add_child(reward_choice)
				check(reward_choice.texture_normal == null and reward_choice.texture_disabled == null, "%s capture uses no flattened texture" % slug)
				check(reward_choice.has_node("LayeredCardBase") and reward_choice.has_node("LayeredCardCharacter") and reward_choice.has_node("LayeredCardRibbon") and reward_choice.has_node("LayeredCardBrands"), "%s soul-harvest choice uses live layered portrait" % slug)
				var reward_actor := reward_choice.get_node_or_null("LayeredCardCharacter") as TextureRect
				check(reward_actor != null and reward_actor.texture.resource_path.ends_with("%s.webp" % slug.replace("-", "_")) or slug in ["skeleton-spear","skeleton-archer"] and reward_actor != null, "%s soul-harvest choice uses approved art path" % slug)
				var reward_flight := Layered.flight_visual_copy(reward_choice)
				check(reward_flight != null and reward_flight.has_node("LayeredCardCharacter") and reward_flight.has_node("LayeredCardBrands"), "%s harvested card flies to book with live layers" % slug)
				check(_brand_positions_ok(reward_choice.get_node_or_null("LayeredCardBrands") as Control, reward_choice.get_node_or_null("LayeredCardBase") as TextureRect, 3), "%s soul-harvest option keeps centered brands" % slug)
				if reward_flight != null: reward_flight.free()
				reward_choice.queue_free()
			var flight := Layered.flight_visual_copy(card)
			check(flight != null and flight.has_node("LayeredCardCharacter") and flight.has_node("LayeredCardBrands") and flight.has_node("LayeredCardBase") and flight.has_node("LayeredCardRibbon"), "book flight keeps ALL separately rendered visual layers")
			if flight != null:
				check((flight.get_node("LayeredCardBrands") as Control).get_child_count() == 3, "book flight keeps actual owned brand icons")
				check(_brand_positions_ok(flight.get_node("LayeredCardBrands") as Control, flight.get_node("LayeredCardBase") as TextureRect, 3), "book-flight brands remain centered")
				check(flight.get_node("LayeredCardCharacter") != card.get_node("LayeredCardCharacter"), "book flight uses independent reusable visual node copies")
				flight.free()
			check(base != null and actor != null and ribbon != null and title != null, "independent textures and title")
			if base != null and actor != null:
				check(base.texture.resource_path.ends_with(str(expected_backgrounds[slug])), "%s uses the approved legion scenery" % slug)
				if slug != "skeleton-spear" and slug != "skeleton-archer" and dims == Vector2(136,218):
					var bg_image := base.texture.get_image()
					check(bg_image.get_pixel(0, 0).a < 0.03 and bg_image.get_pixel(bg_image.get_width()-1, 0).a < 0.03 and bg_image.get_pixel(0, bg_image.get_height()-1).a < 0.03 and bg_image.get_pixel(bg_image.get_width()-1, bg_image.get_height()-1).a < 0.03, "%s approved legion background has no black opaque exterior corners" % slug)
				check(actor.texture.resource_path.ends_with("%s.webp" % slug.replace("-", "_")) or slug in ["skeleton-spear", "skeleton-archer"], "%s uses its own cutout art asset" % slug)
				if dims == Vector2(136, 218):
					var source_image := actor.texture.get_image()
					check(source_image.get_pixel(0, 0).a < 0.05 and source_image.get_pixel(source_image.get_width()-1, source_image.get_height()-1).a < 0.05, "%s portrait has transparent exterior pixels" % slug)
			if base != null and actor != null and ribbon != null and title != null:
				check(title.text == "검사 이름", "title is runtime text")
				check(actor.mouse_filter == Control.MOUSE_FILTER_IGNORE and not card.clip_contents, "character protrusion and click passthrough")
				check(not card.clip_contents, "portrait can extend beyond upper frame without clipping")
				check(ribbon.position.y > base.position.y and ribbon.position.y < base.position.y+base.size.y, "ribbon bridges image and info")
				var old_width := actor.size.x
				card.size = dims * 0.83
				Layered.relayout(card)
				check(actor.size.x < old_width, "layer responds to changed card size")
				check(_brand_positions_ok(brands, base, 3), "three brands stay centered after card resize")
				Layered.set_selected(card, true)
				check(bool(card.get_meta("layered_selected", false)), "selection affects artwork only")
			Layered.sync_brands(card, [{"type":"healing"}, {"type":"freeze"}])
			check(_brand_positions_ok(brands, base, 2), "two owned brands stay centered after a change")
			Layered.sync_brands(card, [{"type":"healing"}])
			check(_brand_positions_ok(brands, base, 1), "one owned brand stays centered after a change")
			Layered.sync_brands(card, [])
			check(_brand_positions_ok(brands, base, 0), "no brands leaves an empty centered row")
			card.queue_free()
	var unrelated := TextureButton.new()
	unrelated.size = Vector2(120,220)
	root.add_child(unrelated)
	check(not Layered.install(unrelated, "unregistered-fallback", "미등록"), "other monsters keep original cards")
	check(Layered.flight_visual_copy(unrelated) == null, "unlayered cards use the existing flight art path")
	var legacy_choice := SoulCapture.make_choice_card(unrelated, {"slug":"unregistered-fallback","name":"미등록","brands":[]})
	check(not legacy_choice.has_node("LayeredCardBase") and legacy_choice.texture_normal == null, "unregistered fallback does not surface old art")
	legacy_choice.free()
	unrelated.queue_free()
	print("LAYERED_CARD_REGRESSION: %d failures" % failed)
	quit(0 if failed==0 else 1)