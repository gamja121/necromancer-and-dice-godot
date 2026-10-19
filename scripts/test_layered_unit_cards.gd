extends SceneTree
## Usage: godot --headless --path . --script res://scripts/test_layered_unit_cards.gd
const Layered = preload("res://systems/layered_unit_card.gd")
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
	for slug in ["skeleton-spear", "skeleton-archer"]:
		for dims in [Vector2(136,218), Vector2(121.856,225.216), Vector2(90,120), Vector2(170,302.4)]:
			var card := TextureButton.new()
			card.size = dims
			card.ignore_texture_size = true
			card.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			card.texture_normal = load("res://assets/cards/unit-card-%s.png" % slug)
			var original := card.texture_normal
			root.add_child(card)
			check(Layered.install(card, slug, "검사 이름"), "%s installed at %s" % [slug, dims])
			check(card.texture_normal == original, "original TextureButton art identity remains available")
			check(is_zero_approx(card.self_modulate.a), "only the flattened art is hidden, not the children")
			var base := card.get_node_or_null("LayeredCardBase") as TextureRect
			var actor := card.get_node_or_null("LayeredCardCharacter") as TextureRect
			var ribbon := card.get_node_or_null("LayeredCardRibbon") as TextureRect
			var title := card.get_node_or_null("LayeredCardTitle") as Label
			check(base != null and actor != null and ribbon != null and title != null, "independent textures and title")
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
			card.queue_free()
	var unrelated := TextureButton.new()
	unrelated.size = Vector2(120,220)
	unrelated.texture_normal = load("res://assets/cards/unit-card-siren.png")
	root.add_child(unrelated)
	check(not Layered.install(unrelated, "siren", "세이렌"), "other monsters keep original cards")
	unrelated.queue_free()
	print("LAYERED_CARD_REGRESSION: %d failures" % failed)
	quit(0 if failed==0 else 1)