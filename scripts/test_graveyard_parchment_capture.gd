extends SceneTree
## Actual production UI and original assets, using an isolated real save.
const MAP=preload("res://map.tscn")
var passed:int=0
var failed:int=0
var out:String
var session:Node
var map:Control
var panel:Control
var old_path:String
var isolated:String
var committed:Dictionary
var saved:PackedByteArray
var rng_after:int

func _initialize() -> void: call_deferred("run")
func check(ok:bool,message:String) -> void:
	if ok: passed+=1; print("PASS grave-parchment: ",message)
	else: failed+=1; printerr("FAIL grave-parchment: ",message)
func wait_for(predicate:Callable,limit:int=5000) -> bool:
	var deadline:int=Time.get_ticks_msec()+limit
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())
func capture(name:String) -> void:
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	var img:Image=root.get_texture().get_image()
	check(not img.is_empty() and img.get_size()==Vector2i(1280,720),"native 1280x720 viewport "+name)
	check(img.save_webp(out.path_join("graveyard_parchment_%s.webp"%name),false,0.87)==OK,"native screenshot "+name)
func frame(i:int) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out.path_join("frames/frame_%04d.png"%i))==OK,"native frame saved")
func start() -> void:
	root.size=Vector2i(1280,720)
	AudioServer.set_bus_mute(0,true)
	out=OS.get_environment("GRAVEYARD_CAPTURE_DIR")
	if out.is_empty(): out=ProjectSettings.globalize_path("res://")
	DirAccess.make_dir_recursive_absolute(out)
	session=root.get_node("RunSession")
	old_path=session.save_file_path
	isolated="user://graveyard_native_%d.json"%OS.get_process_id()
	session.save_file_path=isolated
	session.start_new_world()
	session.world.lap_ready=true
	session.world.leave_home()
	var index:int=session.world.tiles.find("graveyard")
	check(index>=0,"real cemetery fixture exists")
	if index<0: quit(1); return
	session.world.position=index
	session.world.graveyard_corpses=[]
	session.world.rng.seed=521
	check(session.save_world(),"isolated real cemetery saved")
	map=MAP.instantiate()
	root.add_child(map)
	await process_frame
	map.show_location(index)
	panel=map.overlay
	check(panel.get_script()==preload("res://systems/exploration_actions.gd"),"real location opens the single digging screen")
	var strip:TextureRect=panel.content.get_node("GraveyardNoticeStrip")
	check(strip.texture.resource_path=="res://assets/map/ui/fortune_parchment_strip.webp" and Rect2(strip.position,strip.size)==Rect2(340,423,600,150),"original prophet parchment size and placement retained")
	check(Rect2(panel.action_button.position,panel.action_button.size)==map.TILE_EVENT_ACTION_RECT and Rect2(panel.graveyard_exit_button.position,panel.graveyard_exit_button.size)==map.TILE_EVENT_EXIT_RECT,"both original ordinary-tile button slots retained")
func dig() -> void:
	var before:int=session.world.dice_cards.size()
	panel.action_button.pressed.emit()
	check(panel.busy and panel.graveyard_phase=="revealing" and panel.action_button.disabled and panel.graveyard_exit_button.disabled,"real dig starts locked reveal")
	check(session.world.dice_cards.size()==before+1 and session.place_visit_id("grave-extract",panel.index) in session.world.reward_receipts,"actual card and one-visit receipt committed before presentation")
	committed=session.world.snapshot().duplicate(true)
	saved=FileAccess.get_file_as_bytes(isolated)
	rng_after=session.world.rng.state
	panel.action_button.pressed.emit()
	check(session.world.snapshot()==committed,"duplicate click cannot roll or grant again")
func ready() -> void:
	check(panel.graveyard_phase=="ready" and not panel.busy,"soil reveal completes and waits for input")
	check(panel.action_button.text=="챙기고 나가기" and not panel.action_button.disabled and not panel.graveyard_exit_button.visible and Rect2(panel.action_button.position,panel.action_button.size)==map.TILE_EVENT_EXIT_RECT,"collect-and-exit uses common lower exit slot")
	check(panel.graveyard_motion.front.texture.resource_path==preload("res://systems/reward_catalog.gd").image("dice",panel.graveyard_result),"revealed card uses the actual original green front")
	check(not panel.graveyard_motion.dirt.visible,"soil clears without flipping the card")
func finish() -> void:
	check(not is_instance_valid(map.overlay) and map.dice.visible and not map.dice.disabled,"collection returns to the playable map")
	check(session.world.snapshot()==committed and FileAccess.get_file_as_bytes(isolated)==saved and session.world.rng.state==rng_after,"presentation never rewrites save, grants again or consumes RNG")
	session.reload_world()
	check(session.world.snapshot()==committed,"actual acquired card and receipt survive reload")
	map.queue_free()
	await process_frame
	await wait_for(func(): return preload("res://systems/battle_resources.gd").PendingLoads.active.is_empty())
	var audio:Node=root.get_node_or_null("GameAudio")
	await wait_for(func(): return audio==null or audio.voices.is_empty())
	if audio!=null: audio.queue_free()
	await create_timer(0.10).timeout
	session.save_file_path=old_path
	session.world=null
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(isolated+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(isolated+suffix))
	check(not FileAccess.file_exists(isolated),"isolated capture save cleaned")
	print("GRAVEYARD_PARCHMENT_UI: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)

func run() -> void:
	await start()
	await create_timer(0.25).timeout
	await capture("01_before")
	dig()
	await create_timer(0.65).timeout
	await capture("03_fully_covered")
	check(panel.graveyard_motion.dirt.visible and float(panel.graveyard_motion.dirt_material.get_shader_parameter("shed"))==0.0,"initial front remains fully soil covered")
	await create_timer(0.45).timeout
	await capture("04_soil_falling")
	check(await wait_for(func(): return panel.graveyard_phase=="ready"),"real reveal reaches ready")
	ready()
	await capture("02_found")
	panel.action_button.pressed.emit()
	await create_timer(0.30).timeout
	await capture("05_delivery")
	check(await wait_for(func(): return not is_instance_valid(map.overlay)),"real deck flight finishes")
	await capture("06_collected")
	await finish()
