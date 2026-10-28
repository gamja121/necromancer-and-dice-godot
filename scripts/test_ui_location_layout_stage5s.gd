extends SceneTree
## Stage 5S updated: location scenes use the real embedded-battle footprint,
## cover-cropped illustrations and the identical battle nine-patch frame.
## Test real gameplay actions and all seven location scene types.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const SOURCE = [
	{"tile":"rest", "button":"전체 회복"},
	{"tile":"village", "button":"마물 상점"},
	{"tile":"altar", "button":"의식"},
	{"tile":"fortune-teller-camp", "button":"예언"},
	{"tile":"unknown", "button":"기도"},
	{"tile":"graveyard", "button":"시체 파헤치기"},
	{"tile":"forest", "button":"여기로 이동"}
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
	for node in panel.find_children("*","Button",true,false):
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
	if tag.begins_with("graveyard") or tag.begins_with("forest") or tag.begins_with("fortune-teller-camp"):
		check(backdrop != null and backdrop.color.a>0.7, tag + " single action screen preserves its dim backdrop")
	else:
		check(backdrop != null and is_zero_approx(backdrop.color.a), tag + " source has transparent event backdrop")
	check(backdrop != null and backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, tag + " transparent overlay still blocks map clicks")
	var art = get_art(panel)
	check(same_rect(art,map.LOCATION_EVENT_SCENE_RECT), tag + " location painting uses battle's 980x406 viewport")
	check(is_instance_valid(art) and art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, tag + " illustration fills battle aspect without distortion")
	var frame = panel.get_node_or_null("LocationBattleFrame")
	check(frame is NinePatchRect, tag + " reuses native battle frame")
	if frame is NinePatchRect:
		check(frame.texture != null and frame.texture.resource_path == "res://assets/map/ui/battle_frame.png", tag + " frame uses exact battle border asset")
		check(frame.position.distance_to(map.LOCATION_EVENT_FRAME_RECT.position)<0.2 and (frame.size*frame.scale).distance_to(map.LOCATION_EVENT_FRAME_RECT.size)<0.2, tag + " frame matches battle 1024x450 footprint")
		check(frame.draw_center == false and frame.patch_margin_left == 170 and frame.patch_margin_top == 150, tag + " border preserves native battle nine-patch")
	var fortune:bool=tag.begins_with("fortune-teller-camp")
	var action=get_button(panel,primary_label)
	var exit=get_button(panel,"다음 바퀴 출발" if tag.begins_with("home") else "맵으로 나가기")
	var art_bounds:Rect2=map.LOCATION_EVENT_SCENE_RECT
	check(same_rect(exit,map.TILE_EVENT_EXIT_RECT),tag+" common original exit uses inside-art slot")
	check(is_instance_valid(exit) and art_bounds.encloses(Rect2(exit.position,exit.size)),tag+" exit fits painting")
	if fortune:
		check(panel.get_script()==preload("res://systems/place_actions.gd") and panel.confirm_button==null and action==null,tag+" direct screen has no duplicate entry button")
		check(panel.dice==map.dice and map.dice.visible and not map.dice.disabled and map.dice.z_index>panel.z_index,tag+" current camp uses one foreground die")
		check(art_bounds.encloses(Rect2(panel.fortune_title.position,panel.fortune_title.size)) and art_bounds.encloses(Rect2(panel.fortune_hint.position,panel.fortune_hint.size)),tag+" title and hint fit painting")
	else:
		check(same_rect(action,primary_rect),tag+" action uses existing sprite at approved slot")
		check(is_instance_valid(action) and art_bounds.encloses(Rect2(action.position,action.size)),tag+" action fits painting")
		check(is_instance_valid(action) and is_instance_valid(exit) and action.position.x==exit.position.x and action.position.y+action.size.y<exit.position.y,tag+" original buttons do not overlap")
		if is_instance_valid(action):
			check(action.get_theme_stylebox("normal") is StyleBoxTexture and (action.get_theme_stylebox("normal") as StyleBoxTexture).texture.resource_path.begins_with("res://assets/map/ui/parchment_button_variant_"),tag+" original action art remains")
	check(is_instance_valid(exit) and exit.get_theme_stylebox("normal") is StyleBoxTexture and (exit.get_theme_stylebox("normal") as StyleBoxTexture).texture.resource_path.begins_with("res://assets/map/ui/parchment_button_variant_"),tag+" original exit art remains")
	check(map.map_audio.modal_blocked and not map.presentation.gauge.visible, tag + " Stage5Q/R event chrome remains hidden")
	check(map.buttons.size() == 24 and map.hero.visible, tag + " all board tiles and hero remain behind art")

func check_action_frame(map: Control, panel: Control, tag: String, expected_art: String) -> void:
	var scene_art = panel.get_node_or_null("LocationSceneImage")
	var frame = panel.get_node_or_null("LocationBattleFrame")
	check(scene_art is TextureRect, tag + " retains the location illustration in the action panel")
	check(frame is NinePatchRect, tag + " retains the original battle border in the action panel")
	if scene_art is TextureRect:
		check(same_rect(scene_art,map.LOCATION_EVENT_SCENE_RECT), tag + " keeps the 980x406 battle viewport")
		check(scene_art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, tag + " keeps undistorted center crop")
		check(scene_art.texture != null and scene_art.texture.resource_path == "res://assets/map/events/%s.jpg" % expected_art, tag + " uses the approved previous artwork")
	if frame is NinePatchRect:
		check(frame.texture != null and frame.texture.resource_path == "res://assets/map/ui/battle_frame.png", tag + " keeps identical battle border asset")
		check(frame.position.distance_to(map.LOCATION_EVENT_FRAME_RECT.position) < 0.2 and (frame.size * frame.scale).distance_to(map.LOCATION_EVENT_FRAME_RECT.size) < 0.2, tag + " keeps the 1024x450 border footprint")
		check(frame.patch_margin_left == 170 and frame.patch_margin_right == 170 and frame.patch_margin_top == 150 and frame.patch_margin_bottom == 150 and not frame.draw_center, tag + " keeps the battle nine-patch settings")

# The production first lap deliberately omits altar, world tree and graveyard.
# Inject absent types into one road tile only for this isolated visual test.
# Restore the original road before inspecting the next location or save state.
func location_fixture(session,tile_name:String) -> Dictionary:
	var position:int=session.world.position
	var existing:int=session.world.tiles.find(tile_name)
	if existing>=0:
		if tile_name=="fortune-teller-camp": session.world.position=existing
		return {"index":existing,"temporary":false,"position":position}
	var spare:int=session.world.tiles.find("basic")
	if spare<0: return {"index":-1,"temporary":false,"position":position}
	session.world.tiles[spare]=tile_name
	return {"index":spare,"temporary":true,"position":position}

func restore_location_fixture(session,fixture:Dictionary) -> void:
	if bool(fixture.get("temporary",false)): session.world.tiles[int(fixture.index)]="basic"
	session.world.position=int(fixture.position)

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
	# Geometry only: do not start the book MP3 in a headless renderer.
	AudioServer.set_bus_mute(0,true)
	await process_frame
	var before: Dictionary = session.world.snapshot().duplicate(true)
	var before_rng: int = session.world.rng.state
	var before_receipts: Array = session.world.reward_receipts.duplicate()
	check(map.overlay == null and map.map_chrome.size() == 8, "map begins with visible source HUD and no overlay")
	check(map.TILE_EVENT_SCENE_RECT == Rect2(243.2,136.8,793.6,446.4), "story panels retain original 16:9 footprint")
	check(map.LOCATION_EVENT_SCENE_RECT == Rect2(150,148,980,406) and map.LOCATION_EVENT_FRAME_RECT == Rect2(128,126,1024,450), "locations share embedded battlefield geometry")
	check(map.TILE_EVENT_ACTION_RECT == Rect2(896,415,216,58), "primary action uses the original parchment sprite inside art at right")
	check(map.TILE_EVENT_EXIT_RECT == Rect2(896,481,216,58), "exit is vertically below the action inside art")
	for target in SOURCE:
		var fixture: Dictionary = location_fixture(session, str(target.tile))
		var idx: int = int(fixture.index)
		check(idx >= 0, str(target.tile) + " can be inspected without changing the first-lap tile rules")
		if idx < 0: continue
		map.show_location(idx)
		check_frame(map,str(target.tile),str(target.button),map.TILE_EVENT_ACTION_RECT)
		var art = get_art(map.overlay)
		check(art != null and art.texture.resource_path == "res://assets/map/events/%s.jpg" % map.EVENT_IMAGES[str(target.tile)], str(target.tile) + " original event art resource is preserved")
		if str(target.tile) == "forest":
			var hill_action = get_button(map.overlay,"여기로 이동")
			check(is_instance_valid(hill_action), "hill action offers a selectable 1–6 tile movement instead of scouting")
		map.close_overlay()
		check(map.overlay == null and not map.map_audio.modal_blocked, str(target.tile) + " close removes foreground and restores audio icon")
		check(map.presentation.gauge.visible and map.map_chrome.size() == 8, str(target.tile) + " close restores source map HUD")
		restore_location_fixture(session, fixture)
	# Enter the functional panels via the real scene buttons, not merely
	# direct setup: prior builds replaced the wide framed painting with 1040x480 art.
	for target in SOURCE:
		var tile_name: String = str(target.tile)
		if tile_name == "rest": continue
		var fixture: Dictionary = location_fixture(session, tile_name)
		var idx: int = int(fixture.index)
		if idx < 0: continue
		map.show_location(idx)
		var button = get_button(map.overlay,str(target.button))
		if tile_name=="fortune-teller-camp":
			check(button==null and map.overlay.get_script()==preload("res://systems/place_actions.gd"),tile_name+" directly exposes its die function")
		else:
			check(button != null, tile_name + " retains its function button")
			if tile_name in ["graveyard","forest"]:
				check(map.overlay.get_script()==preload("res://systems/exploration_actions.gd"),tile_name+" already exposes one functional screen without using its action")
			elif button != null: button.pressed.emit()
		var scene_name: String = str(map.EVENT_IMAGES[tile_name])
		check_action_frame(map,map.overlay,tile_name + " function",scene_name)
		var function_back: Button=map.overlay.get("close_button") as Button
		if tile_name in ["graveyard","forest","fortune-teller-camp"]:
			check(function_back!=null and function_back.text=="맵으로 나가기" and same_rect(function_back,map.TILE_EVENT_EXIT_RECT),"graveyard function exits from the common tile slot")
		else:
			check(function_back!=null and function_back.text=="← 돌아가기",tile_name+" function explicitly returns to the previous location")
		map.close_overlay()
		map.show_location(idx)
		check_frame(map,tile_name + " return","전체 회복" if tile_name == "rest" else str(target.button),map.TILE_EVENT_ACTION_RECT)
		map.close_overlay()
		restore_location_fixture(session, fixture)
	# The house also has two distinct functional screens: patrol and inheritance.
	map.show_exploration_actions(map.MapState.HOME)
	check_action_frame(map,map.overlay,"house patrol","home-interior")
	map.close_overlay()
	var inheritance = map.HomeInheritance.new()
	map.stage.add_child(inheritance)
	map.overlay = inheritance
	inheritance.setup(session,map)
	check_action_frame(map,map.overlay,"house inheritance","home-interior")
	map.close_overlay()
	map.show_home(false)
	check_frame(map,"home exterior","들어가기",map.TILE_EVENT_ACTION_RECT)
	var exterior_art = get_art(map.overlay)
	check(exterior_art != null and exterior_art.texture.resource_path == "res://assets/map/events/home.jpg", "home exterior retains original image")
	map.close_overlay()
	map.show_home(true)
	check_frame(map,"home interior","낙인 계승",map.TILE_EVENT_INHERITANCE_RECT)
	var interior_art = get_art(map.overlay)
	check(interior_art != null and interior_art.texture.resource_path == "res://assets/map/events/home-interior.jpg", "home interior retains approved existing asset")
	check(same_rect(get_button(map.overlay,"순찰경로"),map.TILE_EVENT_PATROL_RECT), "home patrol retains original parchment and sits in middle stack slot")
	var home_inherit = get_button(map.overlay,"낙인 계승")
	var home_patrol = get_button(map.overlay,"순찰경로")
	var home_exit = get_button(map.overlay,"다음 바퀴 출발")
	check(home_inherit.position.x==home_patrol.position.x and home_patrol.position.x==home_exit.position.x and home_inherit.position.y+home_inherit.size.y<home_patrol.position.y and home_patrol.position.y+home_patrol.size.y<home_exit.position.y, "home has three vertically aligned, nonoverlapping original buttons")
	check(map.LOCATION_EVENT_SCENE_RECT.encloses(Rect2(home_inherit.position,home_inherit.size)) and map.LOCATION_EVENT_SCENE_RECT.encloses(Rect2(home_exit.position,home_exit.size)), "all house buttons stay inside painted scene rather than beneath it")
	check(home_exit.text=="다음 바퀴 출발", "home departure clearly announces a new lap without altering its action")
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
	var cleanup_deadline:int=Time.get_ticks_msec()+10000
	while is_instance_valid(map) and Time.get_ticks_msec()<cleanup_deadline: await process_frame
	while not preload("res://systems/battle_resources.gd").PendingLoads.active.is_empty() and Time.get_ticks_msec()<cleanup_deadline: await process_frame
	var audio:Node=root.get_node_or_null("GameAudio")
	while audio!=null and not audio.voices.is_empty() and Time.get_ticks_msec()<cleanup_deadline: await process_frame
	if audio!=null: audio.queue_free()
	while is_instance_valid(audio) and Time.get_ticks_msec()<cleanup_deadline: await process_frame
	await process_frame
	session.world=null
	session.save_file_path = original_save
	if created: session.queue_free()
	cleanup()
	check(not FileAccess.file_exists(save_path), "isolated test save removed; real saves untouched")
	print("UI_LOCATION_LAYOUT_STAGE5S: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
