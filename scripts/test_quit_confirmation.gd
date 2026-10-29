extends SceneTree
const MAP=preload("res://map.tscn")
const TITLE=preload("res://title.tscn")
const LOADS=preload("res://systems/battle_resources.gd")
var passed:int=0
var failed:int=0
var manager:Node
var out:String=""
var timer_fired:bool=false

class BehindInput extends Control:
	var escapes:int=0
	func _input(event:InputEvent) -> void:
		if event is InputEventKey and event.keycode==KEY_ESCAPE and event.pressed:
			escapes+=1
			get_viewport().set_input_as_handled()

func _initialize() -> void: call_deferred("run")
func check(ok:bool,message:String) -> void:
	if ok: passed+=1;print("PASS quit-confirmation: ",message)
	else: failed+=1;printerr("FAIL quit-confirmation: ",message)
func settle() -> void:
	await process_frame
	await process_frame
func escape(pressed:bool=true,echo:bool=false) -> void:
	var key:=InputEventKey.new()
	key.keycode=KEY_ESCAPE
	key.physical_keycode=KEY_ESCAPE
	key.pressed=pressed
	key.echo=echo
	Input.parse_input_event(key)
	await settle()
func real_wait(seconds:float) -> void: await create_timer(seconds,true,false,true).timeout
func capture(tag:String) -> void:
	if out.is_empty(): return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out.path_join(tag+".png"))==OK,"actual capture "+tag)
func cleanup_scene(scene:Node) -> void:
	scene.queue_free()
	await settle()
	var deadline:int=Time.get_ticks_msec()+10000
	while not LOADS.PendingLoads.active.is_empty() and Time.get_ticks_msec()<deadline: await process_frame

func run() -> void:
	root.size=Vector2i(1280,720)
	out=OS.get_environment("QUIT_CAPTURE_DIR")
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	manager=root.get_node("QuitConfirmation")
	var session:Node=root.get_node("RunSession")
	var original:String=session.save_file_path
	var isolated:String="user://quit_confirmation_%d.json"%OS.get_process_id()
	session.save_file_path=isolated
	session.start_new_world()
	var map:Control=MAP.instantiate()
	root.add_child(map)
	map.map_music.stop()
	map.map_music.stream=null
	AudioServer.set_bus_mute(0,true)
	await settle()
	var input:BehindInput=BehindInput.new()
	map.add_child(input)
	var before:Dictionary=session.world.snapshot().duplicate(true)
	var rng:int=session.world.rng.state
	var disk:String=FileAccess.get_file_as_string(isolated)
	var pending_timer:SceneTreeTimer=create_timer(2.0)
	pending_timer.timeout.connect(func():timer_fired=true)
	await escape()
	check(manager.opened and manager.dialog.visible,"real Escape opens confirmation")
	check(input.escapes==0,"Escape is intercepted before gameplay input")
	check(paused and is_zero_approx(Engine.time_scale),"dialog pauses scene and timed gameplay")
	check(manager.dialog.gui_get_focus_owner()==manager.dialog.get_cancel_button(),"Continue is the safe initial focus")
	check(manager.dialog.get_cancel_button().size.x>=140 and manager.dialog.get_cancel_button().size.y>=44 and manager.dialog.get_ok_button().size.x>=140,"both confirmation buttons have readable full-size targets")
	check(not root.gui_disable_input,"root input restored after the opening key")
	var held_time:float=pending_timer.time_left
	await real_wait(0.12)
	check(not timer_fired and absf(pending_timer.time_left-held_time)<0.001,"default SceneTreeTimer cannot advance behind dialog")
	await capture("01_map_quit")
	await escape(true,true)
	check(manager.opened,"key echo never toggles or duplicates dialog")
	await escape(false)
	check(manager.opened,"key release does not dismiss")
	manager.request_quit()
	check(manager.opened and root.find_children("QuitDialog","Window",true,false).size()==1,"repeated request keeps exactly one dialog")
	await escape()
	check(not manager.opened and not paused and is_equal_approx(Engine.time_scale,1.0),"second Escape cancels and resumes")
	pending_timer.time_left=0.05
	await real_wait(0.12)
	check(timer_fired,"existing timer resumes after cancellation")
	manager.request_quit()
	var enter:=InputEventKey.new()
	enter.keycode=KEY_ENTER
	enter.pressed=true
	Input.parse_input_event(enter)
	await settle()
	enter=enter.duplicate()
	enter.pressed=false
	Input.parse_input_event(enter)
	await settle()
	check(not manager.opened and not manager.quitting,"default Enter chooses Continue rather than quitting")
	if manager.opened: manager.cancel_quit()
	var drag_card:=Button.new()
	drag_card.position=Vector2(20,80)
	drag_card.size=Vector2(120,90)
	map.add_child(drag_card)
	var drag:Control=preload("res://systems/drag_card_module.gd").new()
	drag_card.add_child(drag)
	drag.begin(-1,Vector2(30,90),false)
	await escape()
	check(manager.opened and drag.pointer==-2,"Escape cancels active pointer drag before showing confirmation")
	manager.cancel_quit()
	drag_card.queue_free()
	map.show_home(true)
	await real_wait(0.25)
	map.show_home_inheritance()
	await real_wait(0.8)
	var inheritance:Control=map.overlay
	await escape()
	check(manager.opened and map.overlay==inheritance and not inheritance.closing_depth,"Escape preserves the underlying inheritance menu")
	await capture("02_menu_quit")
	manager.dialog.get_cancel_button().pressed.emit()
	await settle()
	check(not manager.opened and map.overlay==inheritance,"Continue returns to the same menu")
	check(session.world.snapshot()==before and session.world.rng.state==rng and FileAccess.get_file_as_string(isolated)==disk,"open and cancel preserve progress RNG and save bytes")
	map.close_overlay()
	Engine.time_scale=0.5
	paused=true
	manager.request_quit()
	manager.cancel_quit()
	check(paused and is_equal_approx(Engine.time_scale,0.5),"preexisting pause and time scale restored exactly")
	paused=false
	Engine.time_scale=1.0
	await cleanup_scene(map)
	var title:Control=TITLE.instantiate()
	root.add_child(title)
	title.title_music.stop()
	title.title_music.stream=null
	await settle()
	title.options_button.grab_focus()
	await escape()
	check(manager.opened,"Escape works on title screen")
	await capture("03_title_quit")
	manager.cancel_quit()
	check(title.options_button.has_focus(),"cancellation restores prior focused control")
	title.options_button.pressed.emit()
	await settle()
	check(title.options_dialog.visible,"actual exclusive settings dialog is open")
	await escape()
	check(manager.opened and title.options_dialog.visible,"Escape opens quit over settings without dismissing settings")
	check(manager.dialog.get_parent()==title.options_dialog,"focused settings window owns modal confirmation")
	await capture("04_settings_quit")
	manager.dialog.get_cancel_button().pressed.emit()
	await settle()
	check(not manager.opened and title.options_dialog.visible,"Continue returns to still-open settings")
	title.options_dialog.hide()
	root.get_node("GameLanguage").set_language("en",false)
	manager.request_quit()
	check(str(TranslationServer.translate(manager.PROMPT)).contains("Quit the game?"),"quit prompt follows English setting")
	await capture("05_english_quit")
	manager.cancel_quit()
	root.get_node("GameLanguage").set_language("ko",false)
	await cleanup_scene(title)
	var audio:Node=root.get_node_or_null("GameAudio")
	if audio!=null: audio.queue_free()
	await settle()
	await real_wait(0.15)
	session.world=null
	session.save_file_path=original
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(isolated+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(isolated+suffix))
	print("QUIT_CONFIRMATION: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
