extends SceneTree
## Diagnostic visual capture only; all test monsters live only in a temporary local save.
const Scene = preload("res://systems/home_inheritance.gd")
const MapScene = preload("res://map.tscn")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var session = root.get_node_or_null("RunSession")
	if session == null:
		printerr("CAPTURE_FAILED: missing RunSession autoload")
		quit(1)
		return
	var previous_path: String = session.save_file_path
	session.save_file_path = "user://screenshot_just_for_preview_%d.json" % OS.get_process_id()
	session.start_new_world()
	# Ten approved existing species, with sample brands for legible comparisons.
	var slugs := ["goblin-commoner","goblin-soldier","goblin-rider","corpse-slime","soul-reaper","crystal-devourer","spiderling","yeti"]
	for slug in slugs:
		if not session.world.definitions.has(slug):
			printerr("CAPTURE_FAILED: missing preview species ",slug)
			quit(1)
			return
		session.world.roster.append(session.create_item("unit",{"slug":slug}))
	if session.world.roster.size()!=10:
		printerr("CAPTURE_FAILED: expected 10 mock owned monsters")
		quit(1)
		return
	session.world.roster[0].brands=[{"type":"guard","bless":[2],"curse":[]}]
	session.world.roster[1].brands=[{"type":"critical","bless":[3],"curse":[]}]
	var map = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	# Identical parent and setup call to map.show_home_inheritance().
	var panel = Scene.new()
	map.stage.add_child(panel)
	map.overlay = panel
	panel.setup(session,map)
	panel.select_unit(str(session.world.roster[0].id))
	panel.select_unit(str(session.world.roster[1].id))
	await create_timer(1.4).timeout
	if panel.sacrifice_warning == null or not panel.sacrifice_warning.text.contains("영구 소멸"):
		printerr("CAPTURE_FAILED: updated permanent loss warning missing")
		quit(1)
		return
	if panel.details == null or panel.details.get_child_count() < 3:
		printerr("CAPTURE_FAILED: readable brand sections missing")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	var frame := panel.hand.get_node_or_null("InheritanceRosterFrame") as TextureRect
	if frame == null or frame.texture == null or panel.unit_options.size() != 10:
		printerr("CAPTURE_FAILED: runtime inheritance frame or roster missing")
		quit(1)
		return
	var screenshot := root.get_texture().get_image()
	if screenshot == null or screenshot.is_empty():
		printerr("CAPTURE_FAILED: empty rendered viewport")
		quit(1)
		return
	if screenshot.get_width() < 900 or screenshot.get_height() < 500:
		printerr("CAPTURE_FAILED: unexpected viewport size ",screenshot.get_size())
		quit(1)
		return
	if screenshot.get_width()!=1280 or screenshot.get_height()!=720:
		screenshot.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	var output := "res://docs/screenshots/inheritance_readability_actual_10_cards.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/screenshots"))
	var err := screenshot.save_png(output)
	if err != OK:
		printerr("CAPTURE_FAILED: save_png returned ",err)
		quit(1)
		return
	print("CAPTURE_OK: ",output," size=",screenshot.get_size()," cards=",panel.unit_options.size())
	session.save_file_path = previous_path
	quit(0)
