extends SceneTree
## Actual Godot scene contract for the single persistent die:
## map/battle over board; locations and inheritance OVER die; controls OVER art.
const MAP = preload("res://map.tscn")
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
	check(session.save_world(), "unlocked rest painting fixture is persisted")
	var before: Dictionary=session.world.snapshot().duplicate(true)
	var rng: int=session.world.rng.state
	var map: Control=MAP.instantiate()
	root.add_child(map)
	await process_frame
	var die: TextureButton=map.dice
	var initial_position: Vector2=die.position
	var initial_face: int=session.world.dice_visual_face
	check(die.z_index==map.DIE_FOREGROUND_Z and die.mouse_filter==Control.MOUSE_FILTER_STOP,"normal map retains top clickable die")

	map.show_home(true)
	check_location(map,"home interior","낙인 계승")
	check(find_button(map.overlay,"순찰경로")!=null and find_button(map.overlay,"나가기")!=null,"all three home actions stay above art")
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

	# The ordinary teller painting must still hide the die; only its
	# explicit prophecy action may raise the single click-to-roll die.
	map.show_location(0)
	check_location(map,"fortune-teller location painting","예언")
	map.close_overlay()
	map.show_place_actions(0)
	check_location(map,"fortune-teller function","",true)
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
	map.queue_free()
	await process_frame
	session.save_file_path=prior_path
	if created: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("LOCATION_DIE_LAYER_STACK: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
