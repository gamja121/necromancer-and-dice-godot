extends SceneTree
## Use the actual scene controls and routed input in an isolated expedition.

const MapScene = preload("res://map.tscn")
const BattleScene = preload("res://battlefield.tscn")
const MapState = preload("res://systems/map_state.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const KEYS = [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]
const DIRECTIONS = [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]
var navigation: Node
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> bool:
	print("PASS forecast: " if condition else "FAIL forecast: ", description)
	if not condition:
		failures += 1
	return condition


func until(predicate: Callable,limit:int=16000) -> bool:
	var deadline:=Time.get_ticks_msec()+limit
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	return bool(predicate.call())
func key(code: int,echo: bool=false) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.pressed=true
	event.echo=echo
	root.push_input(event)
	await process_frame
	event=InputEventKey.new()
	event.keycode=code
	root.push_input(event)
	await process_frame
func escape() -> void:
	var event:=InputEventKey.new()
	event.keycode=KEY_ESCAPE
	event.pressed=true
	root.window_input.emit(event)
	for i in range(3): await process_frame
	event=InputEventKey.new()
	event.keycode=KEY_ESCAPE
	root.window_input.emit(event)
	for i in range(3): await process_frame
func point_canvas(position: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=root.get_final_transform()*position
	event.relative=Vector2(15,9)
	root.push_input(event)
	await process_frame
func point(control: Control,click:bool=false,button: MouseButton=MOUSE_BUTTON_LEFT) -> void:
	var position:=control.get_global_transform_with_canvas()*(control.size*0.5)
	await point_canvas(position)
	if click:
		for down in [true,false]:
			var press:=InputEventMouseButton.new()
			press.position=root.get_final_transform()*position
			press.button_index=button
			press.pressed=down
			root.push_input(press)
			await process_frame
func go(destination: Control) -> bool:
	if not is_instance_valid(destination): return check(false,"requested focus target exists")
	# Find a route through the actual scene's direction graph, then send those keys.
	for attempt in range(32):
		navigation.refresh()
		if navigation.target==destination: return true
		if not destination in navigation.controls: return check(false,"desired action belongs to the active focus scope: "+str(destination.name))
		var start: Control=navigation.target
		if not is_instance_valid(start): return check(false,"active scene supplies an initial focus target")
		var queue:Array=[start]
		var paths:Dictionary={start.get_instance_id():[]}
		while not queue.is_empty() and not paths.has(destination.get_instance_id()):
			var from: Control=queue.pop_front()
			for i in range(4):
				var next: Control=navigation.neighbor(from,DIRECTIONS[i])
				if next==null or paths.has(next.get_instance_id()): continue
				var path: Array=paths[from.get_instance_id()].duplicate()
				path.append(KEYS[i])
				paths[next.get_instance_id()]=path
				queue.append(next)
		if not paths.has(destination.get_instance_id()):
			return check(false,"four directions reach "+str(destination.name))
		var route: Array=paths[destination.get_instance_id()]
		if route.is_empty(): return true
		await key(int(route[0]))
	return check(false,"direction navigation settles on "+str(destination.name))


func display_bounds(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO, control.size)


func mark_order(mark: Control) -> String:
	var order := mark.get_node_or_null("Order")
	return "" if order == null else order.get_child(0).text


func combatant(rules: Rules, slug: String, side: String, traits: Array) -> Dictionary:
	var unit := rules.individual(slug, side+"-"+slug)
	unit.brands = traits
	unit.passive = "grudge" if slug == "death-knight" else ""
	unit.current_hp = unit.max_hp
	return unit


func brand(kind: String, bless: Array, curse: Array = []) -> Dictionary:
	return {"type":kind,"bless":bless,"curse":curse}


func run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280,720))
	var session = root.get_node("RunSession")
	navigation = root.get_node("KeyboardNavigation")
	var language = root.get_node("GameLanguage")
	language.set_language("ko",false)
	var original_path: String = session.save_file_path
	var scratch := "user://battle-forecast-test-%d.json" % OS.get_process_id()
	session.save_file_path = scratch
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	var rules := Rules.new(definitions,735)
	var allies := [
		combatant(rules, "orc-warrior", "ally", [brand("lightspeed",[4,5],[2]),brand("critical",[4]),brand("guard",[4])]),
		combatant(rules, "death-knight", "ally", [brand("critical",[5],[2])]),
		combatant(rules, "skeleton-cavalry", "ally", [brand("guard",[4],[2])]),
		combatant(rules, "dracula", "ally", [brand("vampire",[4],[2])]),
	]
	var enemies := [
		combatant(rules, "ice-princess", "enemy", [brand("freeze",[1],[4])]),
		combatant(rules, "skeleton-archer", "enemy", [brand("combo",[5],[2])]),
		combatant(rules, "minotaur", "enemy", [brand("lightspeed",[1,5],[4])]),
		combatant(rules, "cerberus", "enemy", [brand("counter",[4],[2])]),
	]
	session.world = MapState.new(definitions,313)
	var tile: int = session.world.tiles.find("monster")
	session.world.position = tile
	session.world.roster = allies.duplicate(true)
	rules.start(allies,enemies)
	session.encounter = {
		"id":"battle-forecast-test", "index":tile, "type":"monster", "allies":allies, "enemies":enemies,
		"checkpoint":rules.snapshot(), "phase":"ready", "prophecy":{}, "previous_roll":0, "previous_card":"",
		"background_variant":"dark-forest",
	}
	session.world.active_encounter = session.encounter.duplicate(true)
	var board := MapScene.instantiate()
	root.add_child(board)
	current_scene = board
	await create_timer(0.55).timeout
	var battle: Control = board.embedded_battle
	var forecast: Control = battle.battle_forecast
	var button4: Control = forecast.face_buttons[3]
	var orc: String = allies[0].id
	var knight: String = allies[1].id
	var queen: String = enemies[0].id
	var bull: String = enemies[2].id
	var original_fate: Control = battle.bars[orc].get_node("FateIcon")
	original_fate.set_mode("bless",false)
	var saved_before := FileAccess.get_file_as_string(scratch)
	check(not saved_before.is_empty(), "isolated map actually saved the encounter")
	var state := JSON.stringify([battle.rules.snapshot(),session.world.snapshot(),session.encounter])
	var die_pose := [board.dice.position,board.dice.rotation,board.dice.texture_normal]

	await point(button4)
	check(forecast.visible and forecast.markers.is_empty(),"face targets display without activating on pointer hover")
	await point(button4,true)
	if check(forecast.selected_face == 4 and forecast.markers.size() == 8,"real mouse click selects a face and displays eight applicable markers"):
		var expected := {"Brand_lightspeed":true,"Brand_critical":true,"Brand_guard":true}
		for key_name in expected:
			check(forecast.markers[orc].has_node(key_name), "stacked blessing appears "+key_name)
		var mark: Control = forecast.markers[orc]
		check(mark_order(mark) == "1" and mark.get_node("Order").get_child(0).get_theme_font_size("font_size") == 31, "large first action number")
		check(mark_order(forecast.markers[allies[3].id]) == "3" and mark_order(forecast.markers[enemies[3].id]) == "3" and mark_order(forecast.markers[knight]) == "5","shared third then fifth")
		check(mark_order(forecast.markers[queen]).is_empty() and forecast.markers[queen].has_node("Brand_freeze") and forecast.markers[bull].has_node("Brand_lightspeed"),"freeze has a curse badge and no number, slow curse retains its order")
		var frozen_chip: Control = forecast.markers[queen].get_node("Brand_freeze")
		check(frozen_chip.get_child(0).material is ShaderMaterial and frozen_chip.get_child(1).text == "저주","curse chip renders a monochrome icon and label")
		check(not original_fate.visible,"preview keeps the old fate mark from overlapping")
		var passive: Control = battle.bars[knight].get_node("PassiveLabel")
		check(passive.visible and not display_bounds(passive).intersects(display_bounds(forecast.markers[knight].get_node("Order"))),"ready marker clears a real passive label")
	var screenshots := OS.get_cmdline_user_args()
	if failures == 0 and not screenshots.is_empty() and DisplayServer.get_name() != "headless":
		await point_canvas(Vector2(640,408))
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(screenshots[0].path_join("forecast-live-battle.png")) == OK,"saved actual game screenshot")
	check(await go(forecast.face_buttons[1]),"direction keys move from the pointer-selected face to face 2")
	await key(KEY_ENTER)
	check(forecast.selected_face == 2 and forecast.markers[orc].has_node("Brand_lightspeed") and not forecast.markers[orc].has_node("Brand_guard"),"Enter switches to the single native curse")
	await key(KEY_ENTER)
	check(forecast.selected_face == 0 and forecast.markers.is_empty() and original_fate.visible,"Enter toggles preview off and restores the previous fate mark")
	await point(button4,true)
	await escape()
	check(forecast.selected_face == 0 and not battle.audio_settings.is_open(),"Escape dismisses the preview")
	check(state == JSON.stringify([battle.rules.snapshot(),session.world.snapshot(),session.encounter]) and saved_before == FileAccess.get_file_as_string(scratch),"selecting faces keeps the live round, RNG, world state and saved file byte-for-byte")
	check(die_pose == [board.dice.position,board.dice.rotation,board.dice.texture_normal],"preview preserves the shared die pose and face")

	var rail_home: Vector2 = forecast.rail.position
	var blocked: Vector2 = board.stage.get_global_transform_with_canvas().affine_inverse()*(button4.get_global_transform_with_canvas()*(button4.size*0.5))
	board.dice.position = blocked-board.dice.size*0.5
	board.dice.rotation_degrees = 31
	var blocked_pose: Vector2 = board.dice.position
	for frame in range(3):
		await process_frame
	check(forecast.rail.position != rail_home and not display_bounds(board.dice).intersects(display_bounds(forecast.rail)),"number strip avoids the rendered bounds of a rotated shared die")
	await point(button4,true)
	check(forecast.selected_face == 4 and board.dice.position == blocked_pose and not battle.busy,"clicking the moved rail cannot roll or move the real die")
	board.dice.position = die_pose[0]
	board.dice.rotation = die_pose[1]
	await point(battle.audio_settings.options_button,true)
	check(battle.audio_settings.is_open() and not forecast.visible and forecast.selected_face == 0 and not button4 in battle.keyboard_focus_controls(),"settings covers the battlefield without letting preview buttons intercept")
	await escape()
	check(forecast.visible and not battle.audio_settings.is_open(),"closing settings restores the empty face strip")

	var rng_copy := RandomNumberGenerator.new()
	rng_copy.seed = battle.rules.rng.seed
	rng_copy.state = battle.rules.rng.state
	var actual_face := rng_copy.randi_range(1,6)
	var other_face := 4 if actual_face != 4 else 2
	await point(forecast.face_buttons[other_face-1],true)
	battle.speed_index = 2
	await key(KEY_SPACE)
	check(not forecast.visible and forecast.selected_face == 0 and battle.busy,"Space starts a real round and immediately clears the prediction")
	check(session.encounter.get("previous_roll",0) == actual_face and actual_face != other_face,"the natural die result differs from the preview and follows the original RNG")
	check(await until(func(): return not battle.busy, 20000),"actual battle round finishes")
	check(battle.rules.round_number == 1 and battle.rules.face == actual_face and forecast.visible and forecast.selected_face == 0,"the following battle turn restores the face strip with fresh state")
	battle.stop_audio()
	board.queue_free()
	await process_frame

	session.encounter = {}
	session.world.active_encounter = {}
	var practice := BattleScene.instantiate()
	root.add_child(practice)
	current_scene = practice
	await process_frame
	check(practice.battle_forecast.visible,"standalone practice mode exposes the face strip")
	language.set_language("en",false)
	await process_frame
	check(tr("예상") == "Preview" and tr("저주") == "Curse","English preview and curse labels are available")
	practice.stop_audio()
	practice.queue_free()
	await process_frame
	session.save_file_path = original_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	print("FORECAST_E2E failures=",failures)
	quit(0 if failures == 0 else 1)
