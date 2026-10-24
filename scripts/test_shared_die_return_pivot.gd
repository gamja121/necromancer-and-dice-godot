extends SceneTree
## The one stage-space die must draw at the same physical centre as its
## persisted stopping pose across tile paintings, battle and map redraws.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const DIE_SIZE = Vector2(76,76)
var passed: int = 0
var failed: int = 0
var save_path: String = ""

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS die-return-pivot: ",description)
	else:
		failed += 1
		printerr("FAIL die-return-pivot: ",description)

func painted_center(die: Control) -> Vector2:
	# The actual centre of the rotated painted quad in stage-space, not the
	# TextureButton's unrotated top-left position.
	return die.get_transform() * (die.size * 0.5)

func preserved_pose(map: Control, pose: Vector2, angle: int, name: String) -> void:
	var die: Control = map.dice
	check(is_instance_valid(die),name+": die exists")
	if not is_instance_valid(die): return
	check(die.pivot_offset==die.size*0.5,name+": die rotates around its centre")
	check(die.position.distance_to(pose)<0.01,name+": logical position equals the saved stopping pose")
	check(roundi(die.rotation_degrees)==angle,name+": last rotation restored")
	check(painted_center(die).distance_to(pose + DIE_SIZE*0.5)<0.05,name+": drawn die centre stays exactly at the stopped position")

func wait_until(callback: Callable, max_ms: int = 6500) -> bool:
	var beginning: int=Time.get_ticks_msec()
	while Time.get_ticks_msec()-beginning < max_ms:
		if bool(callback.call()): return true
		await process_frame
	return bool(callback.call())

func cleanup() -> void:
	for ext in ["",".tmp"]:
		var path: String=save_path+str(ext)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _run() -> void:
	save_path="user://die_return_pivot_%d.json" % OS.get_process_id()
	cleanup()
	var session = root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var old_path: String=session.save_file_path
	session.save_file_path=save_path
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
	var pose:=Vector2(725,212)
	var rotation:=47
	session.world.dice_visual_position=[int(pose.x),int(pose.y)]
	session.world.dice_visual_rotation=rotation
	check(session.save_world(),"persisted rotated die pose without rolling")
	var map: Control=MAP.instantiate()
	root.add_child(map)
	await process_frame
	preserved_pose(map,pose,rotation,"initial loaded map")
	# Ordinary tile art returns through dismiss_overlay(render): the old
	# stage and die node are destroyed and a new one is created.
	var rest: int=session.world.tiles.find("rest")
	check(rest>=0,"ordinary painted rest tile exists")
	if rest>=0:
		map.show_location(rest)
		check(is_instance_valid(map.overlay),"real location art opens")
		check(painted_center(map.dice).distance_to(pose+DIE_SIZE*0.5)<0.05,"painting does not shift die behind it")
		var before_die_id: int=map.dice.get_instance_id()
		var exit_button: Button=null
		for node in map.overlay.get_children():
			if node is Button and node.text=="맵으로 나가기": exit_button=node
		check(exit_button!=null,"painted tile has real exit button")
		if exit_button!=null:
			exit_button.pressed.emit()
			var back: bool=await wait_until(func(): return not is_instance_valid(map.overlay) and is_instance_valid(map.dice) and map.dice.get_instance_id()!=before_die_id)
			check(back,"actual tile exit redraws playable board")
			if back: preserved_pose(map,pose,rotation,"after tile art exit")
	# Changing the die's visual pose during a battle must survive another
	# render with no old 0,0-pivot visual jump and no gameplay RNG change.
	var monster: int=session.world.tiles.find("monster")
	check(monster>=0,"battle tile exists")
	if monster>=0:
		session.world.position=monster
		var ids: Array=[str(session.world.roster[0].id),str(session.world.roster[1].id)]
		check(session.start_encounter(monster,ids),"isolated battle starts from real units")
		map.open_embedded_battle(false)
		await process_frame
		# Enemy selection and battlefield setup legitimately consume RNG.
		var rng_before_return: int=session.world.rng.state
		check(is_instance_valid(map.embedded_battle) and map.embedded_battle.dice==map.dice,"battle reuses original single stage die")
		var battle_pose:=Vector2(800,220)
		var battle_rotation:=123
		map.dice.position=battle_pose
		map.dice.rotation_degrees=float(battle_rotation)
		map.remember_shared_die()
		preserved_pose(map,battle_pose,battle_rotation,"battle last stopped pose")
		map.finish_embedded_battle()
		var returned: bool=await wait_until(func(): return not map.battle_returning and map.embedded_battle==null and not is_instance_valid(map.overlay))
		check(returned,"battle UI closes and map stage redraws")
		if returned: preserved_pose(map,battle_pose,battle_rotation,"after battle return")
		check(session.world.dice_visual_position==[int(battle_pose.x),int(battle_pose.y)] and session.world.dice_visual_rotation==battle_rotation,"battle return does not rewrite saved visual coordinates")
		check(session.world.rng.state==rng_before_return,"exit and redraw do not consume gameplay random values")
		check(session.save_world(),"returned pose saved for reload")
		# The returned map audio panel awaits two _ready frames. Wait for
		# that real initialisation before explicitly rebuilding a second stage.
		for frame in range(5): await process_frame
		session.reload_world()
		map.world=session.world
		map.render()
		await process_frame
		await process_frame
		preserved_pose(map,battle_pose,battle_rotation,"after full save reload")
	# The rebuilt map audio panel has a two-frame asynchronous _ready().
	# Let it finish before destroying its tree during this test teardown.
	for frame in range(8): await process_frame
	map.queue_free()
	await process_frame
	await process_frame
	session.save_file_path=old_path
	if created: session.queue_free()
	cleanup()
	print("SHARED_DIE_RETURN_PIVOT: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
