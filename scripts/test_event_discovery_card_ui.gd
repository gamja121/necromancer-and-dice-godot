extends SceneTree
## Run: godot --headless --path . --script res://scripts/test_event_discovery_card_ui.gd
const EventCard = preload("res://systems/event_discovery_card.gd")
const Locations = preload("res://systems/location_discoveries.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, name: String) -> void:
	if ok:
		print("PASS discovery-card: ", name)
	else:
		failures += 1
		printerr("FAIL discovery-card: ", name)

func _run() -> void:
	var root := Control.new()
	root.size = Vector2(1280, 720)
	get_root().add_child(root)
	var card = EventCard.new()
	root.add_child(card)
	var hill: Dictionary = Locations.details("forest")
	card.setup("발견", str(hill.title), str(hill.description), str(hill.reward), str(hill.illustration))
	await create_timer(0.36).timeout
	check(card.name == "EventDiscoveryCard", "reusable runtime node instantiates")
	check(card.position.is_equal_approx(Vector2(268,80)) and card.size==Vector2(452,560), "discovery uses the shared ordinary event parchment dimensions")
	check(card.get_node("EventDiscoveryBase").texture.resource_path.ends_with("routine_event_card_base_v2.png"), "discovery shares the routine parchment")
	check(card.get_node_or_null("EventDiscoveryCategory") != null, "category is live Label")
	check(card.get_node_or_null("EventDiscoveryTitle") != null, "title is live Label")
	check(card.get_node_or_null("EventDiscoveryDescription") != null, "description is live Label")
	check(card.get_node_or_null("EventDiscoveryIllustration") is TextureRect, "art is live TextureRect")
	check(card.get_node_or_null("EventDiscoveryTile") is TextureRect, "actual board tile is shown")
	check(card.get_node_or_null("EventDiscoveryClose") == null, "no confirmation button anywhere on card")
	check(card.get_node_or_null("EventDiscoveryDismissHint") is Label, "single-click dismissal is communicated")
	check(card.get_node("EventDiscoveryIllustration").texture != null, "fallback art can load")
	check(card.get_node("EventDiscoveryIllustration").texture.resource_path==str(hill.illustration), "dedicated discovery illustration loads without fallback")
	check(card.get_node("EventDiscoveryIllustration").stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "the full discovery illustration and border remain visible")
	check(card.get_node("EventDiscoveryTile").texture != null, "in-game forest tile can load")
	check(card.get_node("EventDiscoveryTitle").text == "언덕 발견", "Korean text is not baked into image")
	for node_name in ["EventDiscoveryTitle","EventDiscoveryDescription"]:
		var text_box: Control=card.get_node(node_name)
		check(Rect2(Vector2.ZERO,card.size).encloses(Rect2(text_box.position,text_box.size)), node_name+" stays inside the parchment")
	for node_name in ["EventDiscoveryTile","EventDiscoveryReward"]:
		var side: Control=card.get_node(node_name)
		var box: Rect2=side.get_global_rect()
		check(box.position.x>card.get_global_rect().end.x and Rect2(Vector2.ZERO,Vector2(1280,720)).encloses(box), node_name+" occupies the visible side plaque")
	var language: Node=get_root().get_node("GameLanguage")
	language.set_language("en")
	await process_frame
	var reward: Label=card.get_node("EventDiscoveryReward")
	check(reward.get_minimum_size().x<=reward.size.x and reward.get_line_count()<=reward.get_visible_line_count(), "English reward remains fully readable on the side plaque")
	language.set_language("ko")
	var acknowledged := [false]
	card.closed.connect(func(): acknowledged[0] = true)
	var first_click := InputEventMouseButton.new()
	first_click.button_index = MOUSE_BUTTON_LEFT
	first_click.pressed = true
	card._gui_input(first_click)
	check(acknowledged[0], "left click anywhere on parchment dismisses card")
	acknowledged[0] = false
	card._gui_input(first_click)
	check(not acknowledged[0], "repeated click never closes twice")
	var touch_card = EventCard.new()
	root.add_child(touch_card)
	touch_card.setup("발견","언덕 발견","설명","언덕 타일 해금")
	var touch_closed = [false]
	touch_card.closed.connect(func(): touch_closed[0] = true)
	var tap = InputEventScreenTouch.new()
	tap.pressed = true
	touch_card._gui_input(tap)
	check(touch_closed[0], "Android touch anywhere on card dismisses it")
	touch_closed[0] = false
	touch_card._gui_input(tap)
	check(not touch_closed[0], "repeated touch never closes twice")
	print("DISCOVERY_CARD_UI: %d failure(s)" % failures)
	root.queue_free()
	quit(0 if failures == 0 else 1)
