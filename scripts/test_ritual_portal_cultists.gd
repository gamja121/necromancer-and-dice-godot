extends SceneTree
## P1-05J-3: final ritual cultists layer, sequential receipt and durable reload.
const SessionScript = preload("res://systems/run_session.gd")
const Rumor = preload("res://systems/cultist_rumor_entry.gd")
const Altar = preload("res://systems/cultist_altar_entry.gd")
const Portal = preload("res://systems/ritual_portal_entry.gd")
const Beats = preload("res://systems/ritual_portal_beats.gd")
const Registry = preload("res://systems/story_battle_registry.gd")

var passed: int = 0
var failed: int = 0
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS ritual-portal-cultists: ",message)
	else:
		failed += 1
		printerr("FAIL ritual-portal-cultists: ",message)

func cleanup(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func fixture(tag: String, tile: String):
	var s = SessionScript.new()
	root.add_child(s)
	var path: String = "user://ritual_portal_cultists_%d_%s.json" % [OS.get_process_id(),tag]
	paths.append(path)
	cleanup(path)
	s.save_file_path = path
	s.start_new_world()
	s.world.story_events[Rumor.EVENT_ID] = {"status":"complete","choice":"","battle_result":""}
	s.world.event_flags[Rumor.SEEN_FLAG] = true
	s.world.event_flags[Rumor.COMPLETE_FLAG] = true
	s.world.event_flags[Rumor.TRACKING_FLAG] = true
	s.world.position = s.world.tiles.find("altar")
	check(s.save_world(),"cultist rumor setup persisted")
	var altar_index: int = s.world.position
	check(Altar.begin(s,altar_index),"previous altar arrival persisted")
	check(Altar.advance(s,altar_index,0),"previous altar ritual reveal persisted")
	check(Altar.advance(s,altar_index,1),"previous altar choice unlocked")
	check(Altar.choose(s,altar_index,2,"pass"),"previous altar passage saved")
	check(Altar.finish(s,altar_index),"tracking quest handoff committed")
	s.world.position = s.world.tiles.find(tile)
	check(s.world.position>=0,"forest or wildcard event tile exists")
	check(s.save_world(),"actual new tile recorded")
	return s

func source_and_visual_contract() -> void:
	check(Beats.count()==4,"original first three scenes preserved with fourth omen")
	check(Beats.beat(0)==Portal.FIRST_BEAT,"original first arrival unchanged")
	check(Beats.beat(1).id=="portal_reveal","original energy beat unchanged")
	check(Beats.beat(1).effect=="제단에서 보았던 문양과 같은 빛이 석문 전체를 타고 흐르며 전이문이 거세게 요동친다.","energy narration preserved")
	check(Beats.beat(2).id=="final_ritual","original third ID")
	check(Beats.beat(2).effect=="광신도들이 의식 재료를 문 앞에 쏟아 놓고 마지막 부활 의식을 시작한다. 전이문은 이동 통로가 아니라 왕을 불러내는 문이었다.","exact original final-ritual narration")
	check(Beats.beat(2).dialogue=="","third original scene is silent")
	check(Beats.beat(2).speaker=="","no invented speaker")
	check(Beats.beat(2).visual=="cultists","third visual uses original cultist layer")
	check(Beats.beat(3).id=="omen","fourth original omen beat added")
	check(Beats.beat(4).is_empty(),"intervention is still locked")
	check(Beats.beat(-1).is_empty(),"negative beat invalid")
	check(Beats.BASE_ART=="res://assets/map/events/ritual-portal-ruins-base.webp","canonical base art retained")
	check(Beats.CULTISTS_ART=="res://assets/map/events/ritual-portal-cultists-layer.webp","original cultist artwork referenced")
	check(Beats.layer_for("cultists")==Beats.CULTISTS_ART,"cultist layer selected only by third visual")
	check(Beats.layer_for("energy")==Beats.ENERGY_ART,"energy layer kept for second visual")
	check(Beats.layer_for("omen")==Beats.OMEN_ART,"fourth omen layer is source-canonical")
	check(Beats.layer_for("base").is_empty(),"arrival background has no extra layer")
	check(ResourceLoader.exists(Beats.CULTISTS_ART),"original cultists resource exists")
	check(ResourceLoader.exists(Beats.ENERGY_ART),"energy resource still exists")
	check(Registry.definition(Portal.EVENT_ID).is_empty(),"final portal battle still unregistered")
	var cloned: Dictionary=Beats.beat(2)
	cloned.effect="altered"
	check(Beats.beat(2).effect.begins_with("광신도들이 의식 재료를"),"canonical beat copy cannot modify source")
	check(Portal.progress_flag(0).is_empty(),"first beat has seen receipt only")
	check(Portal.progress_flag(1)=="event:ritual_portal_trace_01:beat:1","second beat uses original checkpoint")
	check(Portal.progress_flag(2)=="event:ritual_portal_trace_01:beat:2","third beat has distinct saved checkpoint")
	check(Portal.progress_flag(3)=="event:ritual_portal_trace_01:beat:3","fourth scene receives its own checkpoint")
	check(Portal.progress_flag(4).is_empty(),"fifth scene cannot be saved yet")
	var src: String=FileAccess.get_file_as_string("res://map.gd")
	check(src.contains("RitualPortalEntry.current_beat(session)"),"portal modal uses saved beat index")
	check(src.contains("RitualPortalBeats.beat(beat_index)"),"portal modal reads canonical scene data")
	check(src.contains("RitualPortalBeats.layer_for(str(beat.visual))"),"modal chooses source visual")
	check(src.contains("InkSceneReveal.play(ritual_art)"),"original layer animates over ruined gate")
	check(src.contains("if beat_index<3:"),"Continue only for original first three scenes")
	check(src.contains("RitualPortalEntry.advance(session,index,shown_beat)"),"Continue commits current beat transaction")
	check(src.contains('location_button(panel,"숲 기능"'),"existing forest actions preserved")
	check(src.contains('location_button(panel,"돌아가기"'),"board return preserved")
	check(src.contains('session.get_story_event(RitualPortalEntry.EVENT_ID).status=="seen"'),"saved third scene resumes on reconnect")
	check(not src.contains("start_ritual_portal_battle("),"no future battle handler")
	check(not src.contains("complete_ritual_portal("),"no unintended event completion handler")

func third_scene(tile: String) -> void:
	var s=fixture("third_"+tile,tile)
	var at: int=s.world.position
	check(not Portal.advance(s,at,1),"can't jump to third without arrival")
	check(Portal.begin(s,at),"initial portal discovery persisted")
	check(Portal.current_beat(s)==0,"arrival is initially current")
	check(not Portal.advance(s,at,1),"can't bypass energy beat from arrival")
	check(not Portal.advance(s,at+1,0),"neighbor tile can't advance")
	check(Portal.advance(s,at,0),"Continue commits first to energy")
	check(Portal.current_beat(s)==1,"energy is shown before cultists")
	check(not s.event_flag_is_set(Portal.progress_flag(2)),"third checkpoint initially absent")
	check(not Portal.advance(s,at,0),"stale arrival click cannot create cultists")
	check(not Portal.advance(s,at+1,1),"wrong location cannot unlock cultists")
	check(Portal.advance(s,at,1),"Continue saves third canonical scene")
	check(Portal.current_beat(s)==2,"third cultist scene becomes current")
	check(s.event_flag_is_set(Portal.progress_flag(1)),"prior energy receipt remains")
	check(s.event_flag_is_set(Portal.progress_flag(2)),"new cultist checkpoint saved")
	check(s.get_story_event(Portal.EVENT_ID).status=="seen","portal is still an unresolved event")
	check(s.get_story_event(Portal.EVENT_ID).choice=="","no premature decision")
	check(s.get_story_event(Portal.EVENT_ID).battle_result=="","no invented battle result")
	var snapshot: Dictionary=s.world.snapshot().duplicate(true)
	check(not Portal.advance(s,at,0),"first scene stale click rejected")
	check(not Portal.advance(s,at,1),"second scene stale click rejected")
	check(not Portal.advance(s,at,3),"cannot skip past third scene to future intervention")
	check(Portal.begin(s,at),"resuming third beat is idempotent")
	check(s.world.snapshot()==snapshot,"reopening is read-only")
	for flag in [Portal.COMPLETE_FLAG,Portal.PORTAL_FOUND_FLAG,Portal.SITE_LOCATION_FLAG,Portal.TRACKING_COMPLETE_FLAG,Portal.INTERVENTION_FLAG,Portal.REVIVED_FLAG,Portal.HUNT_FLAG,Portal.BATTLE_WON_FLAG,Portal.BATTLE_LOST_FLAG,Portal.RESULT_PENDING_FLAG]:
		check(not s.event_flag_is_set(flag),"third scene never grants future flag "+flag)
	check(s.event_flag_is_set(Portal.TRACKING_FLAG),"original tracking quest remains in progress")
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty(),"third beat starts no battle")
	check(s.world.pending_reward.is_empty(),"third beat grants no reward")
	s.reload_world()
	check(Portal.can_enter(s,at),"third scene remains eligible on reload")
	check(Portal.current_beat(s)==2,"reconnect restores third scene directly")
	check(s.event_flag_is_set(Portal.progress_flag(2)),"saved third scene survives reload")
	check(Portal.begin(s,at),"reconnect cannot reset progress")
	check(Portal.current_beat(s)==2,"reopened page remains at third beat")
	s.free()

func failed_write_and_guards() -> void:
	var s=fixture("guards","forest")
	var at: int=s.world.position
	check(Portal.begin(s,at),"save first portal scene")
	check(Portal.advance(s,at,0),"save energy stage")
	var before: Dictionary=s.world.snapshot().duplicate(true)
	var valid_path: String=s.save_file_path
	s.save_file_path="user://ritual_portal_cultists_uncreated_%d/failed.json" % OS.get_process_id()
	check(not Portal.advance(s,at,1),"save error rejects third scene")
	check(s.world.snapshot()==before,"save error atomically restores all world state")
	check(Portal.current_beat(s)==1,"failure leaves energy beat current")
	check(not s.event_flag_is_set(Portal.progress_flag(2)),"save failure grants no third checkpoint")
	s.save_file_path=valid_path
	s.world.pending_move={"position":at}
	check(not Portal.advance(s,at,1),"pending move blocks progression")
	s.world.restore(before)
	s.world.pending_reward={"kind":"test"}
	check(not Portal.advance(s,at,1),"pending reward blocks progression")
	s.world.restore(before)
	s.world.active_encounter={"event_id":"test"}
	check(not Portal.advance(s,at,1),"active battle blocks progression")
	s.world.restore(before)
	s.world.position=at+1
	check(not Portal.advance(s,at,1),"different tile blocks progression")
	s.world.restore(before)
	s.world.event_flags[Altar.COMPLETE_FLAG]=false
	check(not Portal.advance(s,at,1),"missing completed altar gate rejects progression")
	s.world.restore(before)
	s.world.event_flags[Portal.COMPLETE_FLAG]=true
	check(not Portal.advance(s,at,1),"completed portal cannot advance again")
	s.world.restore(before)
	check(Portal.advance(s,at,1),"valid retry commits third stage")
	s.reload_world()
	check(Portal.current_beat(s)==2,"retry is durable")
	s.free()

func sequential_receipts() -> void:
	var s=fixture("sequential","event")
	var at: int=s.world.position
	s.world.event_flags[Portal.progress_flag(2)]=true
	check(not Portal.begin(s,at),"forged third stage before arrival blocked")
	check(Portal.current_beat(s)==-1,"no forged stage rendered")
	s.world.event_flags.erase(Portal.progress_flag(2))
	check(Portal.begin(s,at),"genuine first scene accepted")
	s.world.event_flags[Portal.progress_flag(2)]=true
	check(not Portal.can_enter(s,at),"cannot have third stage without energy receipt")
	check(not Portal.advance(s,at,0),"forged third-stage receipt blocks Continue")
	s.world.event_flags.erase(Portal.progress_flag(2))
	check(Portal.advance(s,at,0),"genuine energy stage saved")
	s.world.event_flags[Portal.progress_flag(2)]=true
	check(Portal.current_beat(s)==2,"valid sequential receipt restores third beat")
	s.world.event_flags[Portal.SEEN_FLAG]=false
	check(not Portal.begin(s,at),"missing discovery receipt rejects third beat")
	s.free()

func _run() -> void:
	source_and_visual_contract()
	third_scene("forest")
	third_scene("event")
	failed_write_and_guards()
	sequential_receipts()
	for path in paths: cleanup(path)
	print("RITUAL_PORTAL_CULTISTS_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
