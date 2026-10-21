extends SceneTree
## Actual map -> graveyard -> extraction -> map exits, including post-receipt
## and corpse-free states. Uses an isolated save, never the player's run.
const MAP = preload("res://map.tscn")
const STATE = preload("res://systems/map_state.gd")
const SESSION = preload("res://systems/run_session.gd")
const EXTRACTION = preload("res://systems/exploration_actions.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS graveyard-exit: ",message)
	else:
		failed += 1
		printerr("FAIL graveyard-exit: ",message)

func find_button(panel: Control, text_value: String) -> Button:
	if not is_instance_valid(panel): return null
	for child in panel.get_children():
		if child is Button and child.text==text_value: return child
	return null

func wait_for(predicate: Callable, max_frames: int = 180) -> bool:
	for i in range(max_frames):
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
	check(grave>=0,"real graveyard available after first lap")
	if grave<0:
		session.save_file_path = previous_path
		quit(1)
		return
	session.world.position = grave
	var corpse: Dictionary = session.world.roster[0].duplicate(true)
	corpse.brands = [{"type":"critical","bless":[2],"curse":[]}]
	session.world.graveyard_corpses = [corpse]
	check(session.save_world(),"isolated graveyard state persisted")
	var map: Control = MAP.instantiate()
	root.add_child(map)
	await process_frame
	map.show_location(grave)
	var entry: Button = find_button(map.overlay,"시체 파헤치기")
	check(entry!=null and not entry.disabled,"original location exposes working extraction entry")
	if entry==null:
		quit(1)
		return
	entry.pressed.emit()
	var panel: Control = map.overlay
	check(panel.get_script() == EXTRACTION,"actual extraction panel opens through original location action")
	if panel.get_script() != EXTRACTION:
		quit(1)
		return
	var close: Button = panel.get_node_or_null("GraveyardExtractClose")
	var exit_button: Button = panel.get_node_or_null("GraveyardExitToMap")
	check(is_instance_valid(close) and close.visible and not close.disabled,"original close control visible and enabled")
	check(is_instance_valid(exit_button) and exit_button.visible and not exit_button.disabled,"permanent map exit visible and enabled")
	if is_instance_valid(close) and is_instance_valid(exit_button):
		check(close.get_index() > panel.content.get_index() and close.z_index > panel.content.z_index,"close is stacked over graveyard card and frame content")
		check(exit_button.get_index() > panel.content.get_index() and exit_button.z_index > panel.content.z_index,"map exit is stacked over card and frame content")
		check(exit_button.get_global_rect().position.y>=620 and exit_button.get_global_rect().end.y<=720,"map exit is fully inside lower screen action area")
	# Keep the traditional 'close to location' navigation as well.
	if is_instance_valid(close):
		close.pressed.emit()
		check(await wait_for(func(): return find_button(map.overlay,"맵으로 나가기")!=null),"close returns to original location screen")
		map.close_overlay()
	map.show_location(grave)
	entry = find_button(map.overlay,"시체 파헤치기")
	if entry!=null: entry.pressed.emit()
	panel = map.overlay
	check(panel.get_script() == EXTRACTION,"graveyard can be reopened after ordinary close")
	if panel.get_script() == EXTRACTION:
		var id: String = str(corpse.id)
		check(panel.corpse_options.has(id),"the deceased card is still selectable")
		if panel.corpse_options.has(id):
			panel.corpse_options[id].pressed.emit()
			await process_frame
			check(panel.brand_options.size()==1,"eligible brand appears for extraction")
			if not panel.brand_options.is_empty():
				var cards_before: int = session.world.brand_cards.size()
				panel.brand_options[0].pressed.emit()
				await process_frame
				check(session.world.graveyard_corpses.is_empty() and session.world.brand_cards.size()==cards_before+1,"extraction persists corpse consumption and one new brand")
				check(session.place_visit_id("grave-extract",grave) in session.world.reward_receipts,"extraction receipt is committed")
				check(is_instance_valid(panel.graveyard_exit_button) and not panel.graveyard_exit_button.disabled,"exit survives re-render after extraction")
				panel.graveyard_exit_button.pressed.emit()
				check(await wait_for(func(): return not is_instance_valid(map.overlay)),"one-click exit returns directly to the playable map")
				check(map.dice.visible and not map.dice.disabled,"map dice reactivated after leaving extraction")
				var saved: Dictionary = session.world.snapshot().duplicate(true)
				session.reload_world()
				check(session.world.snapshot()==saved,"exit and reload preserve one-time reward, no duplicate extraction")
				# A stale, corpse-free extraction panel must also have a way out.
				map.show_exploration_actions(grave)
				check(is_instance_valid(map.overlay) and is_instance_valid(map.overlay.graveyard_exit_button),"corpse-free return path retains map exit")
				if is_instance_valid(map.overlay):
					map.overlay.graveyard_exit_button.pressed.emit()
					check(await wait_for(func(): return not is_instance_valid(map.overlay)),"corpse-free extraction cannot trap the player")
				# On a legitimately reopened location the action is spent, but
				# the standard exit remains available.
				map.show_location(grave)
				var spent: Button = find_button(map.overlay,"시체 파헤치기")
				check(spent!=null and spent.disabled and find_button(map.overlay,"맵으로 나가기")!=null,"used extraction is disabled but regular exit remains available")
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
