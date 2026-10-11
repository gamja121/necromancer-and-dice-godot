extends SceneTree
## P1-05I-2: two source-canonical altar beats with durable ritual reveal.
const SessionScript = preload("res://systems/run_session.gd")
const Rumor = preload("res://systems/cultist_rumor_entry.gd")
const Altar = preload("res://systems/cultist_altar_entry.gd")
const Beats = preload("res://systems/cultist_altar_beats.gd")
const Registry = preload("res://systems/story_battle_registry.gd")

var passed: int=0
var failed: int=0
var paths: Array[String]=[]

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, what: String) -> void:
	if ok:
		passed+=1
		print("PASS cultist-altar-reveal: ",what)
	else:
		failed+=1
		printerr("FAIL cultist-altar-reveal: ",what)

func cleanup(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func fixture(suffix: String, on_event_tile: bool = false):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://cultist_altar_reveal_%d_%s.json" % [OS.get_process_id(),suffix]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	s.world.story_events[Rumor.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	s.world.event_flags[Rumor.SEEN_FLAG]=true
	s.world.event_flags[Rumor.COMPLETE_FLAG]=true
	s.world.event_flags[Rumor.TRACKING_FLAG]=true
	s.world.position=s.world.tiles.find("event" if on_event_tile else "altar")
	check(s.save_world(),"completed rumor setup persisted")
	check(Altar.begin(s,s.world.position),"altar arrival saved")
	return s

func source_and_visual_contract() -> void:
	check(Beats.count()==2,"only original arrival and ritual revelation present")
	check(Beats.beat(0)==Altar.FIRST_BEAT,"P1-05I-1 arrival unchanged")
	check(Beats.beat(1).id=="ritual_reveal","original second scene id")
	check(Beats.beat(1).effect=="광신도들이 제단을 둘러싸고 마물의 왕을 위한 의식을 준비하고 있다.","original second narration exactly")
	check(Beats.beat(1).visual=="ritual","ritual art is selected")
	check(Beats.beat(1).dialogue.is_empty(),"second scene is silent")
	check(Beats.beat(1).speaker.is_empty(),"no speaker before choice")
	check(Beats.beat(-1).is_empty(),"negative scene does not exist")
	check(Beats.beat(2).is_empty(),"fight/pass choice is not added")
	check(Beats.layer_for("base").is_empty(),"arrival is background-only")
	check(Beats.layer_for("ritual")==Beats.RITUAL,"second stage uses original ritual layer")
	check(Beats.layer_for("summon").is_empty(),"summoning layer stays disabled")
	check(ResourceLoader.exists(Beats.BASE),"original night altar background exists")
	check(ResourceLoader.exists(Beats.RITUAL),"original ritual artwork exists")
	check(Registry.definition(Altar.EVENT_ID).is_empty(),"no altar combat contract enabled")
	var copied: Dictionary=Beats.beat(1)
	copied.effect="tampered"
	check(Beats.beat(1).effect.begins_with("광신도들이"),"canonical scene data cannot be overwritten")
	check(Altar.progress_flag(-1).is_empty(),"negative progress marker rejected")
	check(Altar.progress_flag(0).is_empty(),"first scene remains implicit")
	check(Altar.progress_flag(1)=="event:cultist_altar_encounter_01:beat:1","original save schema reused")
	check(Altar.progress_flag(2).is_empty(),"third choice stage is not writable yet")
	var source: String=FileAccess.get_file_as_string("res://map.gd")
	check(source.contains('func show_cultist_altar_intro(index: int) -> void:'),"old first-scene API retained")
	check(source.contains('func show_cultist_altar_beat(index: int) -> void:'),"new scene renderer present")
	check(source.contains("CultistAltarEntry.current_beat(session)"),"renderer reads saved scene")
	check(source.contains("CultistAltarBeats.beat(beat_index)"),"renderer reads original two-beat table")
	check(source.contains("CultistAltarBeats.layer_for(str(beat.visual))"),"correct ritual layer selected")
	check(source.contains("InkSceneReveal.play(ritual_art)"),"ritual layer reveals over static base")
	check(source.contains("str(beat.effect)"),"source narration displayed")
	check(source.contains("CultistAltarEntry.advance(session,index,shown_beat)"),"continue button saves exact beat")
	check(source.contains('if beat_index==0:'),"only first scene offers Continue")
	check(source.contains('"제단 기능"'),"existing altar actions remain")
	check(source.contains('"돌아가기"'),"back action remains")
	check(not source.contains("start_cultist_altar_battle("),"altar battle not connected")
	check(not source.contains('"지나간다"'),"pass choice not connected")
	check(not source.contains('"싸운다"'),"fight choice not connected")

func play_two_scenes(on_event_tile: bool) -> void:
	var s=fixture("event" if on_event_tile else "altar",on_event_tile)
	var index: int=s.world.position
	check(Altar.can_enter(s,index),"entered original eligible tile")
	check(Altar.current_beat(s)==0,"first scene restored before advancing")
	check(not s.event_flag_is_set(Altar.progress_flag(1)),"second scene not yet consumed")
	check(not Altar.advance(s,index,1),"cannot jump to second scene")
	check(not Altar.advance(s,index+1,0),"cannot advance on a different tile")
	check(Altar.advance(s,index,0),"one Continue saves ritual reveal")
	check(Altar.current_beat(s)==1,"second scene now selected")
	check(s.event_flag_is_set(Altar.progress_flag(1)),"second beat flag saved")
	check(not s.event_flag_is_set(Altar.COMPLETE_FLAG),"reveal does not complete story")
	check(not s.event_flag_is_set(Altar.FIGHT_FLAG),"reveal does not pick fight")
	check(not s.event_flag_is_set(Altar.PASS_FLAG),"reveal does not pick pass")
	check(not s.event_flag_is_set(Altar.RITUAL_CONFIRMED_FLAG),"reveal does not confirm plot")
	check(not s.event_flag_is_set(Altar.RITUAL_TRACKING_FLAG),"reveal does not award quest")
	check(s.event_flag_is_set(Rumor.TRACKING_FLAG),"old cultist tracking remains active")
	check(s.get_story_event(Altar.EVENT_ID).status=="seen","story remains in progress")
	var saved: Dictionary=s.world.snapshot().duplicate(true)
	check(not Altar.advance(s,index,0),"stale previous button is blocked")
	check(not Altar.advance(s,index,1),"second scene cannot advance to future choice")
	check(s.world.snapshot()==saved,"invalid or duplicate clicks do not mutate state")
	s.reload_world()
	check(s.world.position==index,"reload restores story location")
	check(Altar.current_beat(s)==1,"reload restores the ritual overlay scene")
	check(Altar.begin(s,index),"reopening does not erase revealed stage")
	check(Altar.current_beat(s)==1,"reopen preserves second beat")
	check(s.world.snapshot()==saved,"reopen made no unapproved mutations")
	s.free()

func save_failure() -> void:
	var s=fixture("rollback")
	var index: int=s.world.position
	var good_path: String=s.save_file_path
	var snapshot: Dictionary=s.world.snapshot().duplicate(true)
	s.save_file_path="user://cultist_altar_reveal_missing_%d/failed.json" % OS.get_process_id()
	check(not Altar.advance(s,index,0),"write failure prevents ritual reveal")
	check(s.world.snapshot()==snapshot,"write failure atomically restores state")
	check(Altar.current_beat(s)==0,"failed progress remains on arrival")
	check(not s.event_flag_is_set(Altar.progress_flag(1)),"failed save does not grant beat flag")
	s.save_file_path=good_path
	check(Altar.advance(s,index,0),"retry after storage recovery succeeds")
	s.reload_world()
	check(Altar.current_beat(s)==1,"successful retry is durable")
	s.free()

func fail_closed() -> void:
	var s=fixture("corrupted")
	var index: int=s.world.position
	s.world.event_flags[Altar.progress_flag(1)]=true
	check(Altar.current_beat(s)==1,"valid saved second marker recognized")
	s.world.event_flags[Altar.SEEN_FLAG]=false
	check(Altar.current_beat(s)==-1,"missing discovery receipt rejects save")
	check(not Altar.advance(s,index,0),"invalid discovery cannot advance")
	s.world.event_flags[Altar.SEEN_FLAG]=true
	s.world.event_flags[Altar.RITUAL_TRACKING_FLAG]=true
	check(Altar.current_beat(s)==-1,"future quest forbids re-opening early scene")
	s.world.event_flags.erase(Altar.RITUAL_TRACKING_FLAG)
	s.world.pending_reward={"test":true}
	check(not Altar.advance(s,index,0),"reward state blocks advancement")
	s.world.pending_reward={}
	s.world.event_flags.erase(Altar.progress_flag(1))
	s.world.story_events.erase(Altar.EVENT_ID)
	check(not Altar.can_enter(s,index) or Altar.current_beat(s)==-1,"unseen cannot report a visible beat")
	s.world.event_flags[Altar.progress_flag(1)]=true
	check(not Altar.can_enter(s,index),"unseen event with premature beat marker rejected")
	check(not Altar.begin(s,index),"unseen event cannot silently repair premature marker")
	s.free()

func _run() -> void:
	source_and_visual_contract()
	play_two_scenes(false)
	play_two_scenes(true)
	save_failure()
	fail_closed()
	for path in paths: cleanup(path)
	print("CULTIST_ALTAR_REVEAL_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
