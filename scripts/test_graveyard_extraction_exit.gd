extends SceneTree
## Real map -> graveyard digging -> playable map. Legacy test name retained
## because the old exit regression workflow still invokes this script.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const DIG_UI = preload("res://systems/exploration_actions.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS graveyard-exit: ",message)
	else:
		failed += 1
		printerr("FAIL graveyard-exit: ",message)

func find_button(panel: Control, title: String) -> Button:
	if not is_instance_valid(panel): return null
	for child in panel.get_children():
		if child is Button and child.text==title: return child
	return null

func wait_for(predicate: Callable, frames: int = 180) -> bool:
	for i in range(frames):
		if predicate.call(): return true
		await process_frame
	return bool(predicate.call())

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session: Node = root.get_node_or_null("RunSession")
	var created: bool = session==null
	if created:
		session = SESSION.new()
		session.name = "RunSession"
		root.add_child(session)
	var previous_path: String = session.save_file_path
	var path: String = "user://graveyard_exit_%d.json" % OS.get_process_id()
	session.save_file_path = path
	session.start_new_world()
	session.world.lap_ready = true
	session.world.leave_home()
	var grave: int = session.world.tiles.find("graveyard")
	check(grave>=0,"graveyard available after first lap")
	if grave < 0: quit(1); return
	session.world.position = grave
	session.world.graveyard_corpses = []
	check(session.save_world(),"corpse-free cemetery position saved")
	var map: Control = MAP.instantiate()
	root.add_child(map)
	await process_frame
	map.show_location(grave)
	var entry: Button = find_button(map.overlay,"시체 파헤치기")
	check(entry!=null and not entry.disabled,"cemetery location enables digging without an allied corpse")
	if entry==null: quit(1); return
	entry.pressed.emit()
	var panel: Control = map.overlay
	check(panel.get_script()==DIG_UI,"the graveyard action opens the updated digging screen")
	var close: Button = panel.get_node_or_null("GraveyardExtractClose")
	var exit_button: Button = panel.get_node_or_null("GraveyardExitToMap")
	check(is_instance_valid(close) and not close.disabled and close.visible,"close button stays usable")
	check(is_instance_valid(exit_button) and not exit_button.disabled and exit_button.visible,"map exit stays usable")
	check(close.z_index>panel.content.z_index and exit_button.z_index>panel.content.z_index,"exits stay above reward content")
	close.pressed.emit()
	check(await wait_for(func(): return find_button(map.overlay,"맵으로 나가기")!=null),"close returns to location screen")
	map.close_overlay()
	map.show_location(grave)
	entry = find_button(map.overlay,"시체 파헤치기")
	check(entry!=null and not entry.disabled,"unspent digging action remains accessible")
	entry.pressed.emit()
	panel = map.overlay
	check(panel.get_script()==DIG_UI and panel.action_button!=null and not panel.action_button.disabled,"digging confirmation available again")
	var prior: int = session.world.dice_cards.size()
	panel.action_button.pressed.emit()
	await process_frame
	check(session.world.dice_cards.size()==prior+1 and session.world.graveyard_corpses.is_empty(),"digging grants a dice-control card without spending an allied corpse")
	check(is_instance_valid(panel.graveyard_exit_button) and not panel.graveyard_exit_button.disabled,"one-click exit still works after reward")
	panel.graveyard_exit_button.pressed.emit()
	check(await wait_for(func(): return not is_instance_valid(map.overlay)),"one-click exit returns to playable map")
	check(map.dice.visible and not map.dice.disabled,"shared map die reactivated after exit")
	var snapshot: Dictionary = session.world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==snapshot,"card and receipt survive restart")
	map.show_location(grave)
	var used: Button = find_button(map.overlay,"시체 파헤치기")
	check(used!=null and used.disabled and find_button(map.overlay,"맵으로 나가기")!=null,"spent visit prevents digging but still permits departure")
	map.close_overlay()
	map.queue_free()
	await process_frame
	session.save_file_path = previous_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	if created: session.queue_free()
	print("GRAVEYARD_EXTRACTION_EXIT: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
