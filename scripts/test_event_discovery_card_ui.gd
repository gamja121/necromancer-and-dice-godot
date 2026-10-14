extends SceneTree
## Run: godot --headless --path . --script res://scripts/test_event_discovery_card_ui.gd
const EventCard = preload("res://systems/event_discovery_card.gd")
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
	card.setup("발견", "언덕 발견", "낡은 길 너머 작은 언덕을 발견했다.", "언덕 타일 발견")
	check(card.name == "EventDiscoveryCard", "reusable runtime node instantiates")
	check(card.get_node_or_null("EventDiscoveryCategory") != null, "category is live Label")
	check(card.get_node_or_null("EventDiscoveryTitle") != null, "title is live Label")
	check(card.get_node_or_null("EventDiscoveryDescription") != null, "description is live Label")
	check(card.get_node_or_null("EventDiscoveryIllustration") is TextureRect, "art is live TextureRect")
	check(card.get_node_or_null("EventDiscoveryTile") is TextureRect, "actual board tile is shown")
	check(card.get_node_or_null("EventDiscoveryClose") is Button, "close action exists")
	check(card.get_node("EventDiscoveryIllustration").texture != null, "fallback art can load")
	check(card.get_node("EventDiscoveryTile").texture != null, "in-game forest tile can load")
	check(card.get_node("EventDiscoveryTitle").text == "언덕 발견", "Korean text is not baked into image")
	var acknowledged := [false]
	card.closed.connect(func(): acknowledged[0] = true)
	card.get_node("EventDiscoveryClose").pressed.emit()
	check(acknowledged[0], "confirm action emits close")
	print("DISCOVERY_CARD_UI: %d failure(s)" % failures)
	root.queue_free()
	quit(0 if failures == 0 else 1)
