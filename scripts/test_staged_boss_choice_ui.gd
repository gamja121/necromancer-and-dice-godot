extends SceneTree
## End-to-end UI: selecting a stage20 boss via map panel opens the
## existing battle deck, while chosen slug and choices persist.
const SessionScript=preload("res://systems/run_session.gd")
const MapScene=preload("res://map.tscn")
var passed=0
var failed=0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS boss-ui: ",label)
	else:
		failed+=1
		printerr("FAIL boss-ui: ",label)
func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SessionScript.new()
		session.name="RunSession"
		root.add_child(session)
	var prior: String=session.save_file_path
	var scratch: String="user://boss_choice_ui_%d.json" % OS.get_process_id()
	session.save_file_path=scratch
	session.start_new_world()
	session.world.contamination=20
	session.world.generate()
	session.world.position=23
	check(session.save_world(),"stage20 location state saved")
	var map=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	map.show_tile(23)
	check(is_instance_valid(map.overlay) and map.overlay.name=="StageBossChoice","map opens separate three-option boss selection")
	var candidates: Array=[]
	if is_instance_valid(map.overlay):
		for i in range(3):
			var target=map.overlay.get_node_or_null("BossCandidate_%d" % i)
			if target is Button: candidates.append(target)
	check(candidates.size()==3,"three real clickable candidate buttons exist")
	var offers: Array=session.world.boss_offers(20)
	check(offers.size()==3,"displayed offers were saved before confirmation")
	if not candidates.is_empty():
		candidates[0].pressed.emit()
		await process_frame
		check(session.world.boss_selected(20)==str(offers[0]),"UI chooses exact first displayed boss")
		check(is_instance_valid(map.overlay) and map.overlay.get_script().resource_path.ends_with("battle_deck.gd"),"selection transitions to existing battle deck")
	check(session.save_world(),"UI choice persists")
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.boss_selected(20)==str(offers[0]),"UI-selected boss remains after restart")
	session.save_file_path=prior
	if created: session.queue_free()
	for ext in ["",".tmp"]:
		if FileAccess.file_exists(scratch+ext): DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+ext))
	print("STAGED_BOSS_UI: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
