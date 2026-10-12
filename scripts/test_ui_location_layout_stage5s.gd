extends SceneTree
## Stage 5S: original CSS tile-event overlay is transparent, its image is
## 62% wide and 16:9 centered, and action/exit buttons occupy a right rail.
## Test the real Godot map and all seven source location scene types.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const SOURCE = [
	{"tile":"rest", "button":"전체 회복"},
	{"tile":"village", "button":"마물 상점"},
	{"tile":"altar", "button":"의식"},
	{"tile":"fortune-teller-camp", "button":"예언"},
	{"tile":"unknown", "button":"기도"},
	{"tile":"graveyard", "button":"시체 파헤치기"},
	{"tile":"forest", "button":"이동 위치 선택"}
]
var passed: int = 0
var failed: int = 0
var save_path: String = ""

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS ui-location-layout: ", description)
	else:
		failed += 1
		printerr("FAIL ui-location-layout: ", description)

func get_backdrop(panel: Control) -> ColorRect:
	for node in panel.get_children():
		if node is ColorRect and node.get_meta("ui_backdrop",false):
			return node
	return null

func get_art(panel: Control) -> TextureRect:
	for node in panel.get_children():
		if node is TextureRect and node.texture != null:
			return node
	return null

func get_button(panel: Control, text_value: String) -> Button:
	for node in panel.get_children():
		if node is Button and node.text == text_value:
			return node
	return null

func same_rect(node: Control, rect: Rect2) -> bool:
	return is_instance_valid(node) and node.position.distance_to(rect.position) < 0.2 and node.size.distance_to(rect.size) < 0.2

func check_frame(map: Control, tag: String, primary_label: String, primary_rect: Rect2) -> void:
	check(is_instance_valid(map.overlay), tag + " foreground overlay exists")
	if not is_instance_valid(map.overlay): return
	var panel: Control = map.overlay
	var backdrop = get_backdrop(panel)
	check(backdrop != null and is_zero_approx(backdrop.color.a), tag + " source has transparent event backdrop")
	check(backdrop != null and backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, tag + " transparent overlay still blocks map clicks")
	var art = get_art(panel)
	check(same_rect(art,map.TILE_EVENT_SCENE_RECT), tag + " original image fits centered 62%-wide 16:9 frame")
	var action = get_button(panel,primary_label)
	check(same_rect(action,primary_rect), tag + " action is outside image at original CSS right rail")
	var exit = get_button(panel,"나가기")
	check(same_rect(exit,map.TILE_EVENT_EXIT_RECT), tag + " exit matches CSS right 1% bottom 7%")
	check(is_instance_valid(action) and action.position.x >= map.TILE_EVENT_SCENE_RECT.end.x - 0.2, tag + " action never covers illustration")
	check(is_instance_valid(exit) and exit.position.x >= map.TILE_EVENT_SCENE_RECT.end.x - 0.2, tag + " exit never covers illustration")
	check(map.map_audio.modal_blocked and not map.presentation.gauge.visible, tag + " Stage5Q/R event chrome remains hidden")
	check(map.buttons.size() == 24 and map.hero.visible, tag + " all board tiles and hero remain behind art")

func cleanup() -> void:
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	save_path = "user://ui_location_layout_stage5s_%d.json" % OS.get_process_id()
	cleanup()
	var session = root.get_node_or_null("RunSession")
	var created = session == null
	if created:
		session = SESSION.new()
		session.name = "RunSession"
		root.add_child(session)
	var original_save: String = session.save_file_path
	session.save_file_path = save_path
	session.start_new_world()
	var map = MAP.instantiate()
	root.add_child(map)
	await process_frame
	var before: Dictionary = session.world.snapshot().duplicate(true)
	var before_rng: int = session.world.rng.state
	var before_receipts: Array = session.world.reward_receipts.duplicate()
	check(map.overlay == null and map.map_chrome.size() == 8, "map begins with visible source HUD and no overlay")
	check(map.TILE_EVENT_SCENE_RECT == Rect2(243.2,136.8,793.6,446.4), "source scene width equals 62% of 1280 and aspect 16:9")
	check(map.TILE_EVENT_ACTION_RECT == Rect2(1036.8,434.4,230.4,76.8), "source buttons use right 1%, 18% width, bottom 29%")
	check(map.TILE_EVENT_EXIT_RECT == Rect2(1036.8,592.8,230.4,76.8), "source exit uses right 1%, 18% width, bottom 7%")
	for target in SOURCE:
		var idx: int = session.world.tiles.find(str(target.tile))
		check(idx >= 0, str(target.tile) + " exists on actual board")
		if idx < 0: continue
		map.show_location(idx)
		check_frame(map,str(target.tile),str(target.button),map.TILE_EVENT_ACTION_RECT)
		var art = get_art(map.overlay)
		check(art != null and art.texture.resource_path == "res://assets/map/events/%s.jpg" % map.EVENT_IMAGES[str(target.tile)], str(target.tile) + " original event art resource is preserved")
		if str(target.tile) == "forest":
			var hill_action = get_button(map.overlay,"이동 위치 선택")
			check(is_instance_valid(hill_action), "hill action offers a selectable 1–6 tile movement instead of scouting")
		map.close_overlay()
		check(map.overlay == null and not map.map_audio.modal_blocked, str(target.tile) + " close removes foreground and restores audio icon")
		check(map.presentation.gauge.visible and map.map_chrome.size() == 8, str(target.tile) + " close restores source map HUD")
	map.show_home(false)
	check_frame(map,"home exterior","들어가기",map.TILE_EVENT_ACTION_RECT)
	var exterior_art = get_art(map.overlay)
	check(exterior_art != null and exterior_art.texture.resource_path == "res://assets/map/events/home.jpg", "home exterior retains original image")
	map.close_overlay()
	map.show_home(true)
	check_frame(map,"home interior","낙인 계승",map.TILE_EVENT_INHERITANCE_RECT)
	var interior_art = get_art(map.overlay)
	check(interior_art != null and interior_art.texture.resource_path == "res://assets/map/events/home-interior.jpg", "home interior retains approved existing asset")
	check(same_rect(get_button(map.overlay,"순찰경로"),map.TILE_EVENT_PATROL_RECT), "home patrol uses CSS right 1% bottom 21%")
	var home_inherit = get_button(map.overlay,"낙인 계승")
	var home_patrol = get_button(map.overlay,"순찰경로")
	var home_exit = get_button(map.overlay,"나가기")
	check(home_inherit.position.y + home_inherit.size.y < home_patrol.position.y and home_patrol.position.y + home_patrol.size.y < home_exit.position.y, "home action rail has three nonoverlapping controls")
	check(home_exit.position.y + home_exit.size.y < 720.0, "home action exit stays within source viewport")
	map.close_overlay()
	map.modal()
	var dark = get_backdrop(map.overlay)
	check(dark != null and dark.color.a > 0.7, "story/default modal still keeps its intended dark backdrop")
	map.close_overlay()
	map.show_inventory("unit")
	check(is_instance_valid(map.overlay) and map.map_audio.modal_blocked, "non-location inventory keeps its prior foreground blocking")
	map.close_overlay()
	check(session.world.snapshot() == before, "pure location presentation never modifies saved game state")
	check(session.world.rng.state == before_rng and session.world.reward_receipts == before_receipts, "location art and button positioning never roll or award anything")
	map.queue_free()
	await process_frame
	session.save_file_path = original_save
	if created: session.queue_free()
	cleanup()
	check(not FileAccess.file_exists(save_path), "isolated test save removed; real saves untouched")
	print("UI_LOCATION_LAYOUT_STAGE5S: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
