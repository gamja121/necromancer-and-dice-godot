extends SceneTree
## Actual Godot scene contract for the single persistent die:
## map/battle over board; locations and inheritance OVER die; controls OVER art.
const MAP = preload("res://map.tscn")
const BATTLEFIELD = preload("res://battlefield.tscn")
const SESSION = preload("res://systems/run_session.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS location-layer-stack: ",description)
	else:
		failed += 1
		printerr("FAIL location-layer-stack: ",description)

func _initialize() -> void:
	call_deferred("_run")

func find_location_art(root: Node) -> TextureRect:
	return root.get_node_or_null("LocationSceneImage") as TextureRect

func find_location_frame(root: Node) -> NinePatchRect:
	return root.get_node_or_null("LocationBattleFrame") as NinePatchRect

func find_button(root: Node, title: String) -> Button:
	for c in root.get_children():
		if c is Button and c.text==title:
			return c
	return null

func check_location(map: Control, label: String, control_name: String, die_in_front: bool = false) -> void:
	var panel: Control = map.overlay
	check(is_instance_valid(panel) and panel.get_parent()==map.stage,label+": real location overlay is on board")
	if not is_instance_valid(panel): return
	var art: TextureRect=find_location_art(panel)
	var frame: NinePatchRect=find_location_frame(panel)
	var action: Button=find_button(panel,control_name)
	check(art!=null and frame!=null and (control_name.is_empty() or action!=null),label+": source illustration, border and any required action exist")
	if die_in_front:
		check(map.dice.is_visible_in_tree() and map.dice.z_index>panel.z_index and map.dice.mouse_filter==Control.MOUSE_FILTER_STOP,label+": live fortune die paints ABOVE its original art and receives user input")
		check(map.stage.get_child(map.stage.get_child_count()-1)==map.dice,label+": fortune die is last sibling for actual Godot click hit-testing")
	else:
		check(map.dice.is_visible_in_tree() and map.dice.z_index<panel.z_index and map.dice.mouse_filter==Control.MOUSE_FILTER_IGNORE,label+": source art paints over inactive die and blocks click-through")
		check(panel==map.stage.get_child(map.stage.get_child_count()-1),label+": modal receives pointer before board controls")
	if art!=null and frame!=null and action!=null:
		check(art.get_index()<frame.get_index() and (frame.z_index<action.z_index or (frame.z_index==action.z_index and frame.get_index()<action.get_index())),label+": actionable button draws above painted art and border")

func _run() -> void:
	var path: String="user://location_die_layer_%d.json" % OS.get_process_id()
	var session: Node=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var prior_path: String=session.save_file_path
	session.save_file_path=path
	session.start_new_world()
	# Old fixture expected a rest on the first board, although real gameplay
	# unlocks it after homecoming. Earn and select one normally, then mark its
	# notifications read: this regression checks the die, not unread UI flags.
	session.world.laps = 1
	session.world.position = 15
	check(bool(session.unlock_rest_tile().get("ok",false)), "rest is legitimately unlocked for location-art fixture")
	session.world.patrol_plan["selection"]["rest"] = 1
	session.world.generate()
	session.world.event_flags["ui:unlock:rest:tile_pending"] = false
	session.world.event_flags["ui:unlock:rest:action_pending"] = false
	session.world.position=session.world.tiles.find("fortune-teller-camp")
	check(session.save_world(), "rest and current fortune fixture persisted")
	var before: Dictionary=session.world.snapshot().duplicate(true)
	var rng: int=session.world.rng.state
	var map: Control=MAP.instantiate()
	root.add_child(map)
	await process_frame
	var die: TextureButton=map.dice
	var initial_position: Vector2=die.position
	var initial_face: int=session.world.dice_visual_face
	check(die.z_index==map.DIE_FOREGROUND_Z and die.mouse_filter==Control.MOUSE_FILTER_STOP,"normal map retains top clickable die")
	var hint: TextureRect = map.stage.get_node("DicePressHint")
	hint.set_process(false)
	hint._process(2.9)
	check(not hint.visible,"board die hint waits before three seconds")
	hint._process(0.2)
	check(hint.visible and hint.z_index>die.z_index and hint.mouse_filter==Control.MOUSE_FILTER_IGNORE,
		"waiting board die shows a non-interactive hint above its layer")
	var original_rotation := die.rotation
	die.rotation = PI*0.25
	hint._process(0.3)
	var die_bounds: Rect2 = die.get_transform()*Rect2(Vector2.ZERO,die.size)
	check(is_equal_approx(hint.position.x+hint.size.x*0.5,die_bounds.get_center().x)
		and hint.position.y+hint.size.y<die_bounds.position.y,"hint stays centered over the rotated die without touching it")
	die.rotation = original_rotation
	paused = true
	hint._process(0.0)
	check(not hint.visible,"global pause hides the hint")
	paused = false
	hint._process(2.9)
	check(not hint.visible,"ending a global pause restarts the wait")

	map.show_home(true)
	check_location(map,"home interior","낙인 계승")
	hint._process(3.1)
	check(not hint.visible,"the home interior never hints at an inactive die")
	check(find_button(map.overlay,"순찰경로")!=null and find_button(map.overlay,"다음 바퀴 출발")!=null,"all three home actions stay above art")
	map.close_overlay()

	var inheritance: Control=map.HomeInheritance.new()
	map.stage.add_child(inheritance)
	map.overlay=inheritance
	inheritance.setup(session,map)
	check(not die.visible and not die.is_visible_in_tree(),"inheritance modal completely hides the die instead of showing it inside panels")
	check(inheritance.z_index>die.z_index and find_location_art(inheritance)!=null,"inheritance painting and three-column UI remain over map")
	check(inheritance.get_node_or_null("DeckStartButton")==null,"inheritance has no phantom combat selector")
	map.close_overlay()

	var rest_index: int=session.world.tiles.find("rest")
	check(rest_index>=0,"first lap includes a rest tile")
	if rest_index>=0:
		map.show_location(rest_index)
		check_location(map,"rest","전체 회복")
		map.close_overlay()

	# The direct camp immediately exposes the single shared prophecy die.
	hint._process(3.1)
	check(hint.visible,"returning to the board restores its delayed die hint")
	map.show_location(0)
	check_location(map,"fortune-teller direct function","맵으로 나가기",true)
	hint._process(0.1)
	check(not hint.visible,"switching from board to prophecy restarts the delay even while the die stays enabled")
	hint._process(3.0)
	check(hint.visible,"unused prophecy prompts above its shared die after the delay")
	check(map.overlay.get_script()==preload("res://systems/place_actions.gd") and find_button(map.overlay,"예언")==null,"direct camp has no redundant entry action")
	map.close_overlay()
	map.show_place_actions(0)
	check_location(map,"fortune-teller function","맵으로 나가기",true)
	var fortune_panel: Control=map.overlay
	check(fortune_panel.get("dice")==die and fortune_panel.confirm_button==null and find_button(fortune_panel,"예언 듣기")==null,"prophecy has no separate button and reuses the original die above its art")
	check(not die.disabled,"unused fortune die is immediately clickable before the one-time prophecy")
	map.close_overlay()
	check(die.z_index==map.DIE_FOREGROUND_Z and die.mouse_filter==Control.MOUSE_FILTER_STOP,"closing fortune returns original map die to normal clickable layer")
	check(session.world.snapshot()==before and session.world.rng.state==rng,"map and location layer transitions do not modify game state")

	var monster: int=session.world.tiles.find("monster")
	check(monster>=0,"first lap includes a monster tile")
	if monster>=0:
		map.show_battle_deck(monster)
		check(not die.visible and not die.is_visible_in_tree(),"prebattle selection does not overlay unit cards with die")
		map.close_overlay()
		session.world.position=monster
		var ids: Array=[str(session.world.roster[0].id),str(session.world.roster[1].id)]
		check(session.start_encounter(monster,ids),"real battle fixture starts")
		map.open_embedded_battle(false)
		await process_frame
		check(map.embedded_battle!=null and map.embedded_battle.dice==die,"embedded battle keeps exact same die instance")
		check(die.visible and die.z_index>map.overlay.z_index and die.mouse_filter==Control.MOUSE_FILTER_STOP,"only actual battlefield lifts die above battle art and makes it clickable")
		check(map.stage.get_child(map.stage.get_child_count()-1)==die,"battle die is last sibling for real GUI hit testing")
		check(die.position==initial_position and session.world.dice_visual_face==initial_face,"layer transitions preserve shared die pose and face")
		hint._process(3.1)
		check(hint.visible and map.embedded_battle.layer.get_node_or_null("DicePressHint")==null,
			"embedded battle shows only the shared die hint")
		map.embedded_battle.show_brand_reference()
		hint._process(3.1)
		check(not hint.visible,"the brand reference suppresses the battle die hint")
		map.embedded_battle.close_brand_reference()
		var settings: Control = map.embedded_battle.audio_settings
		settings.options_button.pressed.emit()
		settings.advanced_button.pressed.emit()
		await process_frame
		await process_frame
		var panel_rect: Rect2 = settings.panel.get_rect()
		var arena_rect := Rect2(Vector2.ZERO, map.embedded_battle.surface_size)
		check(arena_rect.encloses(panel_rect) and panel_rect.get_center().distance_to(arena_rect.get_center()) <= 1.0,"expanded settings stay centered inside the embedded battle area: %s within %s" % [panel_rect, arena_rect])
		check(not die.visible and not map.deck_button.visible,"shared battle controls cannot cover settings actions")
		hint._process(3.1)
		check(not hint.visible,"battle settings suppress the die hint")
		settings.resume_button.pressed.emit()
		check(die.visible and map.deck_button.visible and map.stage.get_child(map.stage.get_child_count()-1)==die,"resuming restores the same battle die and deck")
	map.queue_free()
	await process_frame
	var practice := BATTLEFIELD.instantiate()
	root.add_child(practice)
	await process_frame
	var practice_hint: TextureRect = practice.layer.get_node("DicePressHint")
	practice_hint.set_process(false)
	practice_hint._process(3.1)
	check(practice_hint.visible,"standalone battle has a hint above its own die")
	practice.show_selection()
	practice_hint._process(3.1)
	check(not practice_hint.visible,"formation editor suppresses the standalone hint")
	practice.queue_free()
	await process_frame
	session.save_file_path=prior_path
	if created: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("LOCATION_DIE_LAYER_STACK: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
