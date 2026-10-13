extends SceneTree
## Regression: die stays inside the tile ring, avoids the stone HUD, and
## remains the topmost CLICKABLE sibling while an embedded battle is open.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const ANIMATION = preload("res://systems/dice_animation.gd")
const INTERIOR = Rect2(150.0,140.0,980.0,416.0)
var passed: int = 0
var failed: int = 0
var save_path: String

func check(ok: bool, name: String) -> void:
	if ok:
		passed += 1
		print("PASS shared-die-safety: ",name)
	else:
		failed += 1
		printerr("FAIL shared-die-safety: ",name)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	save_path = "user://shared_die_safety_%d.json" % OS.get_process_id()
	var session: Node = root.get_node_or_null("RunSession")
	var created: bool = session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var original_path: String=session.save_file_path
	session.save_file_path=save_path
	session.start_new_world()
	var map: Control=MAP.instantiate()
	root.add_child(map)
	await process_frame
	var radius: float=map.dice.size.length()*0.55
	var ring_clear: bool=true
	for tile in map.buttons:
		if INTERIOR.intersects(Rect2(tile.position,tile.size)):
			ring_clear=false
	check(ring_clear and map.buttons.size()==24,"roll arena lies fully INSIDE all 24 solid tile frames")
	var animation: RefCounted=ANIMATION.new()
	var top_pose: Vector2=animation.safe_rest_position(Vector2(340,28),Vector2(76,76),INTERIOR)
	var center: Vector2=top_pose+Vector2(38,38)
	check(INTERIOR.grow(-radius).has_point(center),"legacy top-row die is clamped behind the inner wall")
	var wall: Rect2=map.presentation.gauge.dice_wall_rect()
	var center_hud: Vector2=wall.get_center()
	var hud_pose: Vector2=animation.safe_rest_position(center_hud-Vector2(38,38),Vector2(76,76),INTERIOR,wall)
	check(not wall.grow(radius).has_point(hud_pose+Vector2(38,38)),"legacy die inside HUD moves to safe upper board")
	var rng_before: int=session.world.rng.state
	var old_face: int=session.world.dice_visual_face
	session.world.dice_visual_position=[340,28]
	map.render()
	check(INTERIOR.grow(-radius).has_point(map.dice.position+map.dice.size*0.5),"live map clamps old out-of-ring saved pose on render")
	check(session.world.rng.state==rng_before and session.world.dice_visual_face==old_face,"visual position repair never rolls gameplay RNG or die face")
	var monster: int=session.world.tiles.find("monster")
	check(monster>=0,"new map has a normal monster encounter")
	if monster>=0:
		map.show_battle_deck(monster)
		check(is_instance_valid(map.overlay) and not map.dice.is_visible_in_tree(),"deck picker never displays or intercepts clicks with the disabled die")
		map.close_overlay()
		var roster: Array=session.world.roster
		var ids: Array=[str(roster[0].id),str(roster[1].id)]
		session.world.position=monster
		check(session.start_encounter(monster,ids),"real battle started with two owned monsters")
		map.open_embedded_battle(false)
		await process_frame
		check(is_instance_valid(map.embedded_battle) and map.embedded_battle.dice==map.dice,"embedded combat reuses exactly one die")
		check(map.dice.visible and not map.dice.disabled and map.dice.mouse_filter==Control.MOUSE_FILTER_STOP,"die is visible, active, and mouse-receiving in battle")
		check(map.stage.get_child(map.stage.get_child_count()-1)==map.dice,"die is last stage sibling, above GUI hit-testing for battle viewport")
	map.queue_free()
	await process_frame
	session.save_file_path=original_path
	if created: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path+suffix))
	print("SHARED_DIE_SAFETY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
