extends SceneTree
## P1-05I-1: first altar arrival remains correct after adding the second beat.
const SessionScript = preload("res://systems/run_session.gd")
const CultistRumor = preload("res://systems/cultist_rumor_entry.gd")
const Altar = preload("res://systems/cultist_altar_entry.gd")

var passed: int=0
var failed: int=0
var paths: Array[String]=[]

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, what: String) -> void:
	if ok:
		passed+=1
		print("PASS cultist-altar-entry: ",what)
	else:
		failed+=1
		printerr("FAIL cultist-altar-entry: ",what)

func cleanup(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func make(suffix: String):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://cultist_altar_entry_%d_%s.json" % [OS.get_process_id(),suffix]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	s.world.position=s.world.tiles.find("altar")
	# The P1-05H regression separately verifies the actual entire chain.
	# This fixture models its persisted final state without reenacting battles.
	s.world.story_events[CultistRumor.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	s.world.event_flags[CultistRumor.SEEN_FLAG]=true
	s.world.event_flags[CultistRumor.COMPLETE_FLAG]=true
	s.world.event_flags[CultistRumor.TRACKING_FLAG]=true
	check(s.save_world(),"preceding rumor state saved")
	return s

func first_arrival(on_event_tile: bool) -> void:
	var s=make("event" if on_event_tile else "altar")
	var index: int=s.world.position
	if on_event_tile:
		index=s.world.tiles.find("event")
		s.world.position=index
		check(s.save_world(),"event tile landing saved")
	check(index>=0,"designated tile exists")
	check(Altar.can_enter(s,index),"first altar arrival unlocked after tracking")
	check(not Altar.can_enter(s,index+1),"other tile preview cannot start event")
	check(s.get_story_event(Altar.EVENT_ID).status=="unseen","altar initially unseen")
	check(Altar.begin(s,index),"first arrival persisted")
	check(s.get_story_event(Altar.EVENT_ID).status=="seen","first scene is seen")
	check(s.event_flag_is_set(Altar.SEEN_FLAG),"seen receipt set")
	check(not s.event_flag_is_set(Altar.COMPLETE_FLAG),"no completion granted by arrival")
	check(not s.event_flag_is_set(Altar.FIGHT_FLAG),"no fight choice")
	check(not s.event_flag_is_set(Altar.PASS_FLAG),"no pass choice")
	check(not s.event_flag_is_set(Altar.RITUAL_CONFIRMED_FLAG),"ritual not yet confirmed")
	check(not s.event_flag_is_set(Altar.RITUAL_TRACKING_FLAG),"later tracking not unlocked")
	var saved: Dictionary=s.world.snapshot().duplicate(true)
	check(Altar.begin(s,index),"reopen existing first scene allowed")
	check(s.world.snapshot()==saved,"reopening does not write a second event")
	s.reload_world()
	check(s.world.position==index,"restart restores original landing tile")
	check(s.get_story_event(Altar.EVENT_ID).status=="seen","restart restores seen story")
	check(Altar.can_enter(s,index),"restart can reopen only saved first scene")
	check(not s.event_flag_is_set(Altar.COMPLETE_FLAG),"restart did not complete event")
	s.free()

func guards() -> void:
	var s=make("guards")
	var index: int=s.world.position
	check(Altar.can_enter(s,index),"valid initial fixture")
	s.world.event_flags[CultistRumor.TRACKING_FLAG]=false
	check(not Altar.can_enter(s,index),"missing cultist tracking blocks arrival")
	s.world.event_flags[CultistRumor.TRACKING_FLAG]=true
	s.world.event_flags[CultistRumor.COMPLETE_FLAG]=false
	check(not Altar.can_enter(s,index),"missing rumor completion receipt blocks arrival")
	s.world.event_flags[CultistRumor.COMPLETE_FLAG]=true
	s.world.story_events[CultistRumor.EVENT_ID].status="seen"
	check(not Altar.can_enter(s,index),"uncompleted source story blocks arrival")
	s.world.story_events[CultistRumor.EVENT_ID].status="complete"
	for flag in [Altar.COMPLETE_FLAG,Altar.FIGHT_FLAG,Altar.PASS_FLAG,Altar.RITUAL_CONFIRMED_FLAG,Altar.RITUAL_TRACKING_FLAG]:
		s.world.event_flags[flag]=true
		check(not Altar.can_enter(s,index),"later state blocks first scene: "+flag)
		s.world.event_flags.erase(flag)
	s.world.event_flags[Altar.SEEN_FLAG]=true
	check(not Altar.can_enter(s,index),"stray seen flag does not force unseen event")
	s.world.event_flags.erase(Altar.SEEN_FLAG)
	s.world.story_events[Altar.EVENT_ID]={"status":"seen","choice":"","battle_result":""}
	check(not Altar.can_enter(s,index),"seen story without receipt is rejected")
	s.world.story_events.erase(Altar.EVENT_ID)
	s.world.pending_move={"testing":true}
	check(not Altar.can_enter(s,index),"pending movement blocks story")
	s.world.pending_move={}
	s.world.pending_reward={"testing":true}
	check(not Altar.can_enter(s,index),"pending reward blocks story")
	s.world.pending_reward={}
	s.encounter={"testing":true}
	check(not Altar.can_enter(s,index),"active battle blocks story")
	s.encounter={}
	s.world.active_encounter={"testing":true}
	check(not Altar.can_enter(s,index),"saved battle blocks story")
	s.world.active_encounter={}
	s.world.tiles[index]="forest"
	check(not Altar.can_enter(s,index),"wrong location blocks story")
	s.world.tiles[index]="altar"
	check(Altar.can_enter(s,index),"guard test leaves valid state recoverable")
	s.free()

func rollback() -> void:
	var s=make("rollback")
	var index: int=s.world.position
	var before: Dictionary=s.world.snapshot().duplicate(true)
	var good: String=s.save_file_path
	s.save_file_path="user://cultist_altar_missing_%d/failed.json" % OS.get_process_id()
	check(not Altar.begin(s,index),"save failure prevents first encounter")
	check(s.world.snapshot()==before,"save failure restores whole snapshot")
	check(not s.event_flag_is_set(Altar.SEEN_FLAG),"failed save cannot set receipt")
	s.save_file_path=good
	check(Altar.begin(s,index),"retry after failure works")
	s.reload_world()
	check(s.get_story_event(Altar.EVENT_ID).status=="seen","retry persists across restart")
	s.free()

func original_content() -> void:
	check(Altar.EVENT_ID=="cultist_altar_encounter_01","canonical source event ID")
	check(Altar.FIRST_BEAT.id=="arrival","exact original first beat ID")
	check(Altar.FIRST_BEAT.effect=="밤의 제단. 평소라면 비어 있어야 할 장소에 촛불과 의식 도구가 놓여 있다.","source narration unchanged")
	check(Altar.FIRST_BEAT.dialogue.is_empty(),"first stage has no speech")
	check(Altar.FIRST_BEAT.visual=="base","first arrival has only its background")
	check(ResourceLoader.exists(Altar.BASE_ART),"original cultist altar night art present")
	var source: String=FileAccess.get_file_as_string("res://map.gd")
	check(source.contains("CultistAltarEntry.can_enter(session,index)"),"map guards altar entrance")
	check(source.contains("CultistAltarEntry.begin(session,index)"),"map commits first receipt")
	check(source.contains('func show_cultist_altar_intro(index: int) -> void:'),"first altar UI exists")
	check(source.contains('str(beat.effect)'),"canonical source text rendered")
	check(source.contains("CultistAltarEntry.BASE_ART"),"original background rendered")
	check(source.contains('session.get_story_event(CultistAltarEntry.EVENT_ID).status=="seen"'),"reload only reopens saved first event")
	check(source.contains('"제단 기능"'),"altar controls kept")
	check(source.contains('"돌아가기"'),"back remains available")
	var old_index: int=source.find("CultistRumorEntry.can_enter(session,index)")
	var next_index: int=source.find("CultistAltarEntry.can_enter(session,index)")
	check(old_index>=0 and next_index>old_index,"altar comes after the cultist rumor")
	check(source.contains("CultistAltarEntry.advance(session,index,shown_beat)"),"only saved advance from arrival is wired")
	check(not source.contains("start_cultist_altar_battle("),"altar fight is not enabled")

func _run() -> void:
	original_content()
	first_arrival(false)
	first_arrival(true)
	guards()
	rollback()
	for path in paths: cleanup(path)
	print("CULTIST_ALTAR_ENTRY_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
