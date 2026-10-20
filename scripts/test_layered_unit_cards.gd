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

func _run() -> void:
	# Runtime card art is opt-in by slug. All thirty-two share the same zoom,
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
	}
	check(expected_backgrounds.size() == 32, "all 32 real monster slugs have approved layered scenery")
	for slug in expected_backgrounds.keys():
		for dims in [Vector2(136,218), Vector2(121.856,225.216), Vector2(90,120), Vector2(170,302.4)]:
			var card := TextureButton.new()
			card.size = dims
			card.ignore_texture_size = true
			card.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			card.texture_normal = load("res://assets/cards/unit-card-%s.png" % slug)
			var original := card.texture_normal
			root.add_child(card)
			var owned_brands: Array = [{"type":"critical"}, {"type":"freeze"}, {"type":"counter"}]
			check(Layered.install(card, slug, "검사 이름", false, owned_brands), "%s installed at %s" % [slug, dims])
			check(card.texture_normal == original, "original TextureButton art identity remains available")
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
				check(first.position.x == 0.0 and first.position.y == second.position.y and first.position.y == third.position.y and first.position.x < second.position.x and second.position.x < third.position.x, "owned brand icons form one left-aligned row")
				check(brands.position.x - (card.get_node("LayeredCardBase") as TextureRect).position.x >= (card.get_node("LayeredCardBase") as TextureRect).size.x * 0.15, "owned brands stay inset from the LEFT frame")
				var bg_extent := (card.get_node("LayeredCardBase") as TextureRect).size
				var previous_side := minf(bg_extent.x * 0.19, bg_extent.y * 0.098)
				check(first.size.x >= previous_side * 1.2 and first.size.y >= previous_side * 1.2, "owned brands are at least 20 percent bigger")
				check(third.position.x + third.size.x <= brands.size.x + 0.5, "three enlarged brand icons remain within the info area")
			if dims == Vector2(136,218):
				# Regression: a defeated enemy must not revert to the
				# flattened source card on the post-victory soul harvest screen.
				var reward_choice: TextureButton = SoulCapture.make_choice_card(card, {"slug":slug,"name":"검사 이름","brands":owned_brands})
				root.add_child(reward_choice)
				check(reward_choice.texture_normal == card.texture_normal and reward_choice.texture_disabled == card.texture_normal, "%s capture retains original hit and disabled texture" % slug)
				check(reward_choice.has_node("LayeredCardBase") and reward_choice.has_node("LayeredCardCharacter") and reward_choice.has_node("LayeredCardRibbon") and reward_choice.has_node("LayeredCardBrands"), "%s soul-harvest choice uses live layered portrait" % slug)
				var reward_actor := reward_choice.get_node_or_null("LayeredCardCharacter") as TextureRect
				check(reward_actor != null and reward_actor.texture.resource_path.ends_with("%s.webp" % slug.replace("-", "_")) or slug in ["skeleton-spear","skeleton-archer"] and reward_actor != null, "%s soul-harvest choice uses approved art path" % slug)
				var reward_flight := Layered.flight_visual_copy(reward_choice)
				check(reward_flight != null and reward_flight.has_node("LayeredCardCharacter") and reward_flight.has_node("LayeredCardBrands"), "%s harvested card flies to book with live layers" % slug)
				if reward_flight != null: reward_flight.free()
				reward_choice.queue_free()
			var flight := Layered.flight_visual_copy(card)
			check(flight != null and flight.has_node("LayeredCardCharacter") and flight.has_node("LayeredCardBrands") and flight.has_node("LayeredCardBase") and flight.has_node("LayeredCardRibbon"), "book flight keeps ALL separately rendered visual layers")
			if flight != null:
				check((flight.get_node("LayeredCardBrands") as Control).get_child_count() == 3, "book flight keeps actual owned brand icons")
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
				check(actor.position.y < base.position.y, "actor extends above upper frame")
				check(ribbon.position.y > base.position.y and ribbon.position.y < base.position.y+base.size.y, "ribbon bridges image and info")
				var old_width := actor.size.x
				card.size = dims * 0.83
				Layered.relayout(card)
				check(actor.size.x < old_width, "layer responds to changed card size")
				Layered.set_selected(card, true)
				check(bool(card.get_meta("layered_selected", false)), "selection affects artwork only")
			Layered.sync_brands(card, [{"type":"healing"}])
			check((card.get_node("LayeredCardBrands") as Control).get_child_count() == 1, "updated owned brands replace the old icons")
			Layered.sync_brands(card, [])
			check((card.get_node("LayeredCardBrands") as Control).get_child_count() == 0, "no brands displays no placeholder icons")
			card.queue_free()
	var unrelated := TextureButton.new()
	unrelated.size = Vector2(120,220)
	unrelated.texture_normal = load("res://assets/cards/unit-card-siren.png")
	root.add_child(unrelated)
	check(not Layered.install(unrelated, "siren", "세이렌"), "other monsters keep original cards")
	check(Layered.flight_visual_copy(unrelated) == null, "unlayered cards use the existing flight art path")
	var legacy_choice := SoulCapture.make_choice_card(unrelated, {"slug":"siren","name":"세이렌","brands":[]})
	check(not legacy_choice.has_node("LayeredCardBase") and legacy_choice.texture_normal == unrelated.texture_normal, "unlayered capture choice retains flat fallback")
	legacy_choice.free()
	unrelated.queue_free()
	print("LAYERED_CARD_REGRESSION: %d failures" % failed)
	quit(0 if failed==0 else 1)