extends SceneTree
## P4-03A: restart the real Godot Map after every saved child/portal
## narrative click, and directly after the pre-battle rescue/intervention
## choice. No battle may launch, no story may finish on reload alone.
## Uses only isolated PID-named user:// files.
const MAP=preload("res://map.tscn")
const SESSION=preload("res://systems/run_session.gd")
const CHILD=preload("res://systems/story_event_entry.gd")
const CHILD_BEATS=preload("res://systems/graveyard_story_beats.gd")
const RUMOR=preload("res://systems/cultist_rumor_entry.gd")
const ALTAR=preload("res://systems/cultist_altar_entry.gd")
const PORTAL=preload("res://systems/ritual_portal_entry.gd")
const PORTAL_BEATS=preload("res://systems/ritual_portal_beats.gd")

var passed: int=0
var failed: int=0
var paths: Array[String]=[]

func _initialize() -> void: call_deferred("_run")

func check(ok: bool,label: String) -> void:
	if ok:
		passed+=1
		print("PASS p4-story-resume: ",label)
	else:
		failed+=1
		printerr("FAIL p4-story-resume: ",label)

func wipe(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func fresh(session: Node, tag: String) -> void:
	var path: String="user://p4_story_ui_resume_%d_%s.json" % [OS.get_process_id(),tag]
	paths.append(path)
	wipe(path)
	session.save_file_path=path
	session.start_new_world()
	# Story interruptions are tested on the first board that can contain a
	# cemetery. This is a test-only completed-lap fixture, not a player skip.
	session.world.lap_ready=true
	session.world.leave_home()
	check(session.world.laps==1 and session.world.tiles.count("graveyard")==1,
		tag+": isolated post-first-lap fixture has one unlocked graveyard")

func until_ready(predicate: Callable,limit_ms:int=12000)->bool:
	var begin: int=Time.get_ticks_msec()
	while Time.get_ticks_msec()-begin<limit_ms:
		if predicate.call(): return true
		await process_frame
	return bool(predicate.call())

func button_in(map: Control,caption: String)->Button:
	if not is_instance_valid(map.overlay): return null
	for child in map.overlay.get_children():
		if child is Button and child.visible and child.text==caption: return child
	return null

func is_deck(map: Control)->bool:
	return is_instance_valid(map.overlay) and map.overlay.get_script()!=null and map.overlay.get_script().resource_path.ends_with("battle_deck.gd")

func scene_text_visible(map: Control,exact_text: String)->bool:
	if not is_instance_valid(map.overlay): return false
	for child in map.overlay.get_children():
		if child is Label and child.visible and child.text==exact_text: return true
	return false

func map_load(session: Node) -> Control:
	var scene: Control=MAP.instantiate()
	root.add_child(scene)
	for i in range(3): await process_frame
	return scene

func map_restart(session: Node,map: Control,label: String) -> Control:
	for i in range(3): await process_frame
	map.queue_free()
	await process_frame
	var saved: Dictionary=session.world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==saved,label+": original world snapshot identical after reload")
	var restored: Control=await map_load(session)
	check(session.world.snapshot()==saved,label+": loading Map never changes event, dice, monster or reward data")
	return restored

func graveyard(session: Node) -> void:
	fresh(session,"graveyard")
	var world=session.world
	var index: int=world.tiles.find("graveyard")
	world.position=index
	check(index>=0 and session.save_world(),"child: original graveyard position saved in isolated fixture")
	var map: Control=await map_load(session)
	check(not is_instance_valid(map.overlay) and session.get_story_event(CHILD.EVENT_ID).status=="unseen","child: reload at unseen graveyard cannot auto-discover story")
	for i in range(3): await process_frame
	map.queue_free()
	await process_frame
	check(CHILD.begin(session,index),"child: canonical production entry saves first discovery")
	map=await map_load(session)
	check(button_in(map,"계속")!=null and CHILD.current_beat(session)==0,"child: seen first scene automatically restored on restart")
	for beat in range(3):
		var button: Button=button_in(map,"계속")
		check(button!=null,"child: original Continue available at beat %d" % beat)
		if button==null: return
		check(scene_text_visible(map,str(CHILD_BEATS.beat(beat).effect)),"child: exact source narration at beat %d before click" % beat)
		button.pressed.emit()
		await process_frame
		check(CHILD.current_beat(session)==beat+1 and session.event_flag_is_set(CHILD.progress_flag(beat+1)),"child: user Continue persists source beat %d exactly once" % (beat+1))
		check(not session.event_flag_is_set(CHILD.COMPLETE_FLAG),"child: reading scenes cannot complete or grant rescue")
		map=await map_restart(session,map,"child-beat-%d" % (beat+1))
		var expected: String="아이를 구한다" if beat==2 else "계속"
		check(button_in(map,expected)!=null and CHILD.current_beat(session)==beat+1,"child: original UI resumes scene %d, not scene zero" % (beat+1))
		check(scene_text_visible(map,str(CHILD_BEATS.beat(beat+1).effect)),"child: scene-specific source narrative restored from JSON at beat %d" % (beat+1))
	check(button_in(map,"지나친다")!=null and button_in(map,"아이를 구한다")!=null,"child: final scene retains both original choices")
	button_in(map,"아이를 구한다").pressed.emit()
	check(is_deck(map) and session.get_story_event(CHILD.EVENT_ID).choice=="protect_child","child: real choice opens normal deck without starting fight")
	check(session.encounter.is_empty() and not session.event_flag_is_set(CHILD.COMPLETE_FLAG),"child: closing before deck confirmation records no victory or completion")
	map=await map_restart(session,map,"child-rescue-choice")
	check(button_in(map,"출전 마물 선택")!=null and not is_deck(map),"child: restart after choice shows saved rescue scene, not an automatic fight")
	check(session.encounter.is_empty() and session.world.active_encounter.is_empty(),"child: reload alone never creates/duplicates ghoul encounter")
	check(not session.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"child: source rescue reward remains gated by real battle victory")
	for i in range(3): await process_frame
	map.queue_free()
	await process_frame

func portal(session: Node) -> void:
	fresh(session,"portal")
	var world=session.world
	# Deliberately seed only the earlier completed rumor, as in P4-02C;
	# the previous altar must be processed through its real state machine.
	world.story_events[RUMOR.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	world.event_flags[RUMOR.SEEN_FLAG]=true
	world.event_flags[RUMOR.COMPLETE_FLAG]=true
	world.event_flags[RUMOR.TRACKING_FLAG]=true
	# Altar stones are excluded from the new map. Existing altar story
	# gameplay instead starts from an eligible event tile after the rumor.
	world.position=world.tiles.find("altar")
	if world.position<0: world.position=world.tiles.find("event")
	var altar_index: int=world.position
	check(session.save_world() and ALTAR.begin(session,altar_index),"portal: canonical altar fixture starts with a true arrival")
	check(ALTAR.advance(session,altar_index,0) and ALTAR.advance(session,altar_index,1),"portal: altar continues all original scenes")
	check(ALTAR.choose(session,altar_index,2,"pass") and ALTAR.finish(session,altar_index) and ALTAR.completed(session),"portal: original altar Finish unlocks source quest, not a forged portal state")
	var forest_index: int=world.tiles.find("forest")
	world.position=forest_index
	check(forest_index>=0 and session.save_world(),"portal: original forest tile saved with genuinely unseen portal")
	var map: Control=await map_load(session)
	check(not is_instance_valid(map.overlay) and session.get_story_event(PORTAL.EVENT_ID).status=="unseen","portal: reload at unseen forest never invents portal discovery")
	for i in range(3): await process_frame
	map.queue_free()
	await process_frame
	check(PORTAL.begin(session,forest_index),"portal: production portal discovery saved at real forest")
	map=await map_load(session)
	check(button_in(map,"계속")!=null and PORTAL.current_beat(session)==0,"portal: reopened first known forest scene restores original UI")
	for beat in range(4):
		var button: Button=button_in(map,"계속")
		check(button!=null,"portal: Continue visible on source scene %d" % beat)
		if button==null: return
		check(scene_text_visible(map,str(PORTAL_BEATS.beat(beat).effect)),"portal: source narration correct before beat %d" % beat)
		button.pressed.emit()
		await process_frame
		check(PORTAL.current_beat(session)==beat+1 and session.event_flag_is_set(PORTAL.progress_flag(beat+1)),"portal: original UI Continue commits story beat %d" % (beat+1))
		check(not session.event_flag_is_set(PORTAL.REVIVED_FLAG),"portal: scrolling events cannot revive king")
		map=await map_restart(session,map,"portal-beat-%d" % (beat+1))
		var expected: String="저지한다" if beat==3 else "계속"
		check(button_in(map,expected)!=null,"portal: forest reload restores scene %d with original action" % (beat+1))
		check(scene_text_visible(map,str(PORTAL_BEATS.beat(beat+1).effect)),"portal: original source narrative resumes beat %d" % (beat+1))
	check(button_in(map,"저지한다")!=null,"portal: final scene offers deliberate intervention")
	button_in(map,"저지한다").pressed.emit()
	check(session.get_story_event(PORTAL.EVENT_ID).choice=="intervene","portal: original intervention choice saved without battle")
	# Simulate an exit before the 0.76s presentation timer can automatically
	# reveal a deck; the persisted choice must still reopen safely.
	map=await map_restart(session,map,"portal-before-deck")
	check(button_in(map,"출전 마물 선택")!=null and not is_deck(map),"portal: forest reload resumes declared intervention before deck selection")
	check(session.encounter.is_empty() and session.world.active_encounter.is_empty(),"portal: restart creates no phantom fight/checkpoint")
	check(not session.event_flag_is_set(PORTAL.REVIVED_FLAG) and not session.event_flag_is_set(PORTAL.HUNT_FLAG),"portal: no premature king revival or hunt quest")
	check(PORTAL.current_beat(session)==4 and ALTAR.completed(session),"portal: saved fifth scene and previous altar completion remain valid")
	for i in range(3): await process_frame
	map.queue_free()
	await process_frame

func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var original_path: String=session.save_file_path
	await graveyard(session)
	await portal(session)
	session.save_file_path=original_path
	if created: session.queue_free()
	for p in paths: wipe(p)
	check(paths.all(func(p): return not FileAccess.file_exists(p)),"isolated story UI checkpoints removed; player save untouched")
	print("P4_STORY_UI_INTERRUPTION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
