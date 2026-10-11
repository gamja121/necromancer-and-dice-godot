extends SceneTree
## Stage 5K: source-exact rare-monster cleared stone art and persistent map UI.
const MapScene = preload("res://map.tscn")
const SessionScript = preload("res://systems/run_session.gd")
const MapState = preload("res://systems/map_state.gd")
var passed: int = 0
var failed: int = 0
var test_save: String = ""

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS ui-rare-tile: ",message)
	else:
		failed += 1
		printerr("FAIL ui-rare-tile: ",message)

func cleanup() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(test_save+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save+suffix))

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	test_save = "user://ui_rare_cleared_tile_%d.json" % OS.get_process_id()
	cleanup()
	var session = root.get_node_or_null("RunSession")
	var own_session: bool = session==null
	if own_session:
		session = SessionScript.new()
		session.name = "RunSession"
		root.add_child(session)
	var original_save: String = session.save_file_path
	session.save_file_path = test_save
	session.start_new_world()
	var world = session.world
	var rare: int = world.tiles.find("rare-monster")
	var ordinary: int = world.tiles.find("monster")
	check(rare>=0 and ordinary>=0 and rare!=ordinary,"real generated board has separate rare and regular monsters")
	if rare<0 or ordinary<0:
		session.save_file_path=original_save
		if own_session: session.queue_free()
		cleanup()
		quit(1)
		return
	var prefix = "res://assets/map/tiles/"
	for name in ["monster.png","monster-cleared.png","rare-monster.png","rare-monster-cleared.png","boss-cleared.png"]:
		var art: Texture2D = load(prefix+name)
		check(art!=null and art.get_width()>0 and art.get_height()>0,"Godot decodes original tile "+name)
	var actual_rare: Texture2D = load(prefix+"rare-monster-cleared.png")
	var ordinary_done: Texture2D = load(prefix+"monster-cleared.png")
	if actual_rare==null or ordinary_done==null:
		check(false,"runtime must decode both original cleared stones before rendering map")
		session.save_file_path = original_save
		if own_session: session.queue_free()
		cleanup()
		print("UI_RARE_CLEARED_TILE_PARITY: %d passed, %d failed" % [passed,failed])
		quit(1)
		return
	check(actual_rare!=ordinary_done and actual_rare.resource_path!=ordinary_done.resource_path,"rare completion has distinct preserved artwork")
	var original_map_serial: int = world.map_serial
	var original_receipts: Array = world.reward_receipts.duplicate(true)
	world.cleared.append(rare)
	world.cleared.append(ordinary)
	check(session.save_world(),"cleared indices saved in disposable world")
	var map: Control = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	check(map.buttons.size()==24,"real game map renders all 24 interactive stones")
	check(map.tile_path(rare)==prefix+"rare-monster-cleared.png","rare cleared maps to frozen web exclusive source tile")
	check(map.tile_path(ordinary)==prefix+"monster-cleared.png","ordinary cleared keeps standard cleared tile")
	check(map.buttons[rare].texture_normal==actual_rare,"live rare map button actually displays rare cleared texture")
	check(map.buttons[ordinary].texture_normal==ordinary_done,"ordinary tile artwork unchanged")
	check(map.buttons[rare].tooltip_text.contains("희귀") and map.buttons[rare].tooltip_text.contains("처치 완료"),"rare monster identity and completion tooltip preserved")
	check(world.tiles[rare]=="rare-monster" and world.tiles[ordinary]=="monster","rendering did not rewrite saved tile kind")
	check(world.map_serial==original_map_serial and world.reward_receipts==original_receipts,"visual replacement did not regenerate map or grant rewards")
	map.queue_free()
	await process_frame
	var snapshot: Dictionary = world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==snapshot,"rare/ordinary cleared board survives JSON save reload")
	map = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	check(map.tile_path(rare)==prefix+"rare-monster-cleared.png" and map.buttons[rare].texture_normal==actual_rare,"restarted map keeps rare cleared stone")
	check(map.buttons[ordinary].texture_normal==ordinary_done,"restarted map keeps ordinary cleared stone")
	map.queue_free()
	await process_frame
	session.world.generate()
	check(session.world.cleared.is_empty(),"next map regeneration clears old rare completion markers")
	var next_rare: int = session.world.tiles.find("rare-monster")
	check(next_rare>=0,"fresh board still contains rare monster encounter")
	if next_rare>=0:
		map = MapScene.instantiate()
		root.add_child(map)
		await process_frame
		check(map.tile_path(next_rare)==prefix+"rare-monster.png","new lap renders live rare monster stone, not completed art")
		check(map.buttons[next_rare].texture_normal==load(prefix+"rare-monster.png"),"new lap button restores original rare uncompleted texture")
		map.queue_free()
		await process_frame
	session.save_file_path = original_save
	if own_session: session.queue_free()
	cleanup()
	check(not FileAccess.file_exists(test_save),"disposable test save removed, user's original save untouched")
	print("UI_RARE_CLEARED_TILE_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
