extends SceneTree
## P1-05J-4: original king omen, sequential persistence and no early revival.
const SessionScript = preload("res://systems/run_session.gd")
const Rumor = preload("res://systems/cultist_rumor_entry.gd")
const Altar = preload("res://systems/cultist_altar_entry.gd")
const Portal = preload("res://systems/ritual_portal_entry.gd")
const Beats = preload("res://systems/ritual_portal_beats.gd")
const Registry = preload("res://systems/story_battle_registry.gd")

var passed: int=0
var failed: int=0
var paths: Array[String]=[]

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed+=1
		print("PASS ritual-portal-omen: ",message)
	else:
		failed+=1
		printerr("FAIL ritual-portal-omen: ",message)

func cleanup(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func fixture(tag: String, tile: String):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://ritual_portal_omen_%d_%s.json" % [OS.get_process_id(),tag]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	s.world.story_events[Rumor.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	s.world.event_flags[Rumor.SEEN_FLAG]=true
	s.world.event_flags[Rumor.COMPLETE_FLAG]=true
	s.world.event_flags[Rumor.TRACKING_FLAG]=true
	s.world.position=s.world.tiles.find("altar")
	check(s.save_world(),"prior cultist rumor persisted")
	var altar_index: int=s.world.position
	check(Altar.begin(s,altar_index),"altar arrival saved")
	check(Altar.advance(s,altar_index,0),"altar ritual saved")
	check(Altar.advance(s,altar_index,1),"altar choice scene saved")
	check(Altar.choose(s,altar_index,2,"pass"),"altar pass intent saved")
	check(Altar.finish(s,altar_index),"source altar follow-up completed and tracking unlocked")
	s.world.position=s.world.tiles.find(tile)
	check(s.world.position>=0,"forest or event wildcard location exists")
	check(s.save_world(),"actual portal location saved")
	return s

func source_and_visual_contract() -> void:
	check(Beats.count()==4,"four canonical portal beats, no intervention")
	check(Beats.beat(0)==Portal.FIRST_BEAT,"original arrival unchanged")
	check(Beats.beat(1).id=="portal_reveal","original energy reveal unchanged")
	check(Beats.beat(2).id=="final_ritual","original cultist scene unchanged")
	check(Beats.beat(3).id=="omen","exact original fourth beat id")
	check(Beats.beat(3).effect=="문 너머에서 거대한 형체가 몸을 일으킨다. 마물의 왕의 존재가 이미 현세와 맞닿기 시작했다.","exact original fourth narration")
	check(Beats.beat(3).visual=="omen","fourth source visual is omen")
	check(Beats.beat(3).dialogue=="" and Beats.beat(3).speaker=="","no fabricated fourth dialogue or speaker")
	check(Beats.beat(4).is_empty(),"intervention scene not yet unlocked")
	check(Beats.beat(-1).is_empty(),"negative scene unavailable")
	check(Beats.OMEN_ART=="res://assets/map/events/ritual-portal-omen-layer.webp","original omen overlay path")
	check(Beats.layer_for("omen")==Beats.OMEN_ART,"fourth scene selects omen layer")
	check(Beats.layer_for("cultists")==Beats.CULTISTS_ART,"third scene keeps cultist layer")
	check(Beats.layer_for("energy")==Beats.ENERGY_ART,"second scene keeps energy layer")
	check(Beats.layer_for("base").is_empty(),"first scene uses unchanged base only")
	check(Beats.layer_for("intervene").is_empty(),"fifth intervention has no visual unlock")
	check(ResourceLoader.exists(Beats.BASE_ART),"ruin background exists")
	check(ResourceLoader.exists(Beats.OMEN_ART),"original omen layer resource exists")
	check(Registry.definition(Portal.EVENT_ID).is_empty(),"portal ritual combat remains disabled")
	check(Portal.progress_flag(1)=="event:ritual_portal_trace_01:beat:1","energy receipt unchanged")
	check(Portal.progress_flag(2)=="event:ritual_portal_trace_01:beat:2","cultist receipt unchanged")
	check(Portal.progress_flag(3)=="event:ritual_portal_trace_01:beat:3","omen receives distinct save checkpoint")
	check(Portal.progress_flag(4).is_empty(),"intervention cannot be checkpointed")
	var copied: Dictionary=Beats.beat(3)
	copied.effect="tampered"
	check(Beats.beat(3).effect.begins_with("문 너머에서 거대한 형체"),"canonical scene cannot be overwritten")
	var src: String=FileAccess.get_file_as_string("res://map.gd")
	check(src.contains("RitualPortalBeats.beat(beat_index)"),"UI reads canonical saved beat")
	check(src.contains("RitualPortalBeats.layer_for(str(beat.visual))"),"UI resolves exact omen layer")
	check(src.contains("InkSceneReveal.play(ritual_art)"),"omen overlay reveals with existing ink animation")
	check(src.contains("RitualPortalEntry.current_beat(session)"),"UI uses persisted scene index")
	check(src.contains("RitualPortalEntry.advance(session,index,shown_beat)"),"Continue uses guarded persistence")
	check(src.contains("if beat_index<3:"),"Continue only for arrival, energy and cultists")
	check(src.contains('location_button(panel,"숲 기능"'),"existing forest action retained")
	check(src.contains('location_button(panel,"돌아가기"'),"board return retained")
	check(src.contains('session.get_story_event(RitualPortalEntry.EVENT_ID).status=="seen"'),"restart resumes previously discovered scenes")
	check(not src.contains("start_ritual_portal_battle("),"no premature portal combat handler")
	check(not src.contains("complete_ritual_portal("),"no premature king revival handler")

func show_fourth(tile: String) -> void:
	var s=fixture("fourth_"+tile,tile)
	var at: int=s.world.position
	check(not Portal.advance(s,at,2),"unseen event cannot skip three beats")
	check(Portal.begin(s,at),"first portal discovery saved")
	check(not Portal.advance(s,at,2),"cannot skip from arrival to omen")
	check(Portal.advance(s,at,0),"arrival advances to energy")
	check(Portal.current_beat(s)==1,"energy is second")
	check(not Portal.advance(s,at,2),"cannot jump from energy to omen")
	check(Portal.advance(s,at,1),"energy advances to cultist ritual")
	check(Portal.current_beat(s)==2,"cultists are third")
	check(not Portal.advance(s,at+1,2),"wrong location cannot advance to omen")
	check(not s.event_flag_is_set(Portal.progress_flag(3)),"omen checkpoint not yet set")
	check(Portal.advance(s,at,2),"explicit Continue saves original omen scene")
	check(Portal.current_beat(s)==3,"king omen now current")
	check(s.event_flag_is_set(Portal.progress_flag(1)),"energy checkpoint kept")
	check(s.event_flag_is_set(Portal.progress_flag(2)),"cultist checkpoint kept")
	check(s.event_flag_is_set(Portal.progress_flag(3)),"omen checkpoint saved")
	check(s.get_story_event(Portal.EVENT_ID).status=="seen","omen stays an unfinished story")
	check(s.get_story_event(Portal.EVENT_ID).choice=="","intervention choice still locked")
	check(s.get_story_event(Portal.EVENT_ID).battle_result=="","no battle outcome invented")
	var snapshot: Dictionary=s.world.snapshot().duplicate(true)
	for stale in [0,1,2,3]:
		check(not Portal.advance(s,at,stale),"duplicate or future Continue %d blocked" % stale)
	check(Portal.begin(s,at),"reopening scene remains idempotent")
	check(s.world.snapshot()==snapshot,"duplicate reads do not change saved world")
	for flag in [Portal.COMPLETE_FLAG,Portal.PORTAL_FOUND_FLAG,Portal.SITE_LOCATION_FLAG,Portal.TRACKING_COMPLETE_FLAG,Portal.INTERVENTION_FLAG,Portal.REVIVED_FLAG,Portal.HUNT_FLAG,Portal.BATTLE_WON_FLAG,Portal.BATTLE_LOST_FLAG,Portal.RESULT_PENDING_FLAG]:
		check(not s.event_flag_is_set(flag),"king omen does not grant future state "+flag)
	check(s.event_flag_is_set(Portal.TRACKING_FLAG),"ritual-site quest remains active")
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty(),"no battle started")
	check(s.world.pending_reward.is_empty(),"no reward generated")
	s.reload_world()
	check(Portal.can_enter(s,at),"reloaded omen eligible at actual tile")
	check(Portal.current_beat(s)==3,"reload resumes saved omen, not first scene")
	check(s.event_flag_is_set(Portal.progress_flag(3)),"saved omen checkpoint survives reload")
	check(Portal.begin(s,at),"reopening after reload is safe")
	check(Portal.current_beat(s)==3,"reopen never rewinds omen")
	s.free()

func rollback_and_corruption() -> void:
	var s=fixture("guards","forest")
	var at: int=s.world.position
	check(Portal.begin(s,at),"original arrival stored")
	check(Portal.advance(s,at,0),"energy stored")
	check(Portal.advance(s,at,1),"cultists stored")
	var before: Dictionary=s.world.snapshot().duplicate(true)
	var valid_path: String=s.save_file_path
	s.save_file_path="user://ritual_portal_omen_missing_%d/failed.json" % OS.get_process_id()
	check(not Portal.advance(s,at,2),"failed write never shows omen")
	check(s.world.snapshot()==before,"failed write restores checkpoint and world")
	check(Portal.current_beat(s)==2,"failed write keeps cultist scene current")
	check(not s.event_flag_is_set(Portal.progress_flag(3)),"failed write does not grant omen receipt")
	s.save_file_path=valid_path
	s.world.pending_move={"position":at}
	check(not Portal.advance(s,at,2),"pending move prevents omen")
	s.world.restore(before)
	s.world.pending_reward={"kind":"test"}
	check(not Portal.advance(s,at,2),"pending reward prevents omen")
	s.world.restore(before)
	s.world.active_encounter={"event_id":"test"}
	check(not Portal.advance(s,at,2),"active battle prevents omen")
	s.world.restore(before)
	s.world.position=at+1
	check(not Portal.advance(s,at,2),"off-tile click prevents omen")
	s.world.restore(before)
	s.world.event_flags[Altar.COMPLETE_FLAG]=false
	check(not Portal.advance(s,at,2),"inconsistent prior event prevents omen")
	s.world.restore(before)
	s.world.event_flags[Portal.REVIVED_FLAG]=true
	check(not Portal.advance(s,at,2),"revival flag blocks unfinished portal")
	s.world.restore(before)
	s.world.story_events[Portal.EVENT_ID].choice="intervene"
	check(not Portal.advance(s,at,2),"premature intervention choice prevents omen")
	s.world.restore(before)
	check(Portal.advance(s,at,2),"recovered legitimate progression works")
	s.reload_world()
	check(Portal.current_beat(s)==3,"successful retry survives reload")
	s.free()

func sequential_flags() -> void:
	var s=fixture("forge","event")
	var at: int=s.world.position
	s.world.event_flags[Portal.progress_flag(3)]=true
	check(not Portal.begin(s,at),"forged omen before discovery blocked")
	check(Portal.current_beat(s)==-1,"forged omen not rendered")
	s.world.event_flags.erase(Portal.progress_flag(3))
	check(Portal.begin(s,at),"legitimate first discovery succeeds")
	s.world.event_flags[Portal.progress_flag(3)]=true
	check(not Portal.can_enter(s,at),"omen without cultists cannot pass gate")
	s.world.event_flags.erase(Portal.progress_flag(3))
	check(Portal.advance(s,at,0),"legitimate energy saved")
	s.world.event_flags[Portal.progress_flag(3)]=true
	check(not Portal.can_enter(s,at),"omen without third checkpoint blocked")
	s.world.event_flags.erase(Portal.progress_flag(3))
	check(Portal.advance(s,at,1),"legitimate cultists saved")
	s.world.event_flags[Portal.progress_flag(3)]=true
	check(Portal.current_beat(s)==3,"consistent omen receipt can resume")
	s.world.event_flags[Portal.SEEN_FLAG]=false
	check(not Portal.begin(s,at),"omen without discovery receipt blocked")
	s.free()

func _run() -> void:
	source_and_visual_contract()
	show_fourth("forest")
	show_fourth("event")
	rollback_and_corruption()
	sequential_flags()
	for path in paths: cleanup(path)
	print("RITUAL_PORTAL_OMEN_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
