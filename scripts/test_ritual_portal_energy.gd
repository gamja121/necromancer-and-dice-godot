extends SceneTree
## P1-05J-2: exact original portal-energy scene, atomic progression and resume.
const SessionScript=preload("res://systems/run_session.gd")
const CultistRumor=preload("res://systems/cultist_rumor_entry.gd")
const Altar=preload("res://systems/cultist_altar_entry.gd")
const Portal=preload("res://systems/ritual_portal_entry.gd")
const Beats=preload("res://systems/ritual_portal_beats.gd")
const Registry=preload("res://systems/story_battle_registry.gd")

var passed: int=0
var failed: int=0
var paths: Array[String]=[]

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	if ok:
		passed+=1
		print("PASS ritual-portal-energy: ",what)
	else:
		failed+=1
		printerr("FAIL ritual-portal-energy: ",what)

func cleanup(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func fixture(tag: String, tile: String):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://ritual_portal_energy_%d_%s.json" % [OS.get_process_id(),tag]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	s.world.story_events[CultistRumor.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	s.world.event_flags[CultistRumor.SEEN_FLAG]=true
	s.world.event_flags[CultistRumor.COMPLETE_FLAG]=true
	s.world.event_flags[CultistRumor.TRACKING_FLAG]=true
	s.world.position=s.world.tiles.find("altar")
	check(s.save_world(),"completed rumor prerequisites saved")
	var altar_index: int=s.world.position
	check(Altar.begin(s,altar_index),"actual altar arrival saved")
	check(Altar.advance(s,altar_index,0),"actual altar ritual reveal saved")
	check(Altar.advance(s,altar_index,1),"altar choice reached")
	check(Altar.choose(s,altar_index,2,"pass"),"altar pass saved")
	check(Altar.finish(s,altar_index),"altar follow-up completed and tracking unlocked")
	s.world.position=s.world.tiles.find(tile)
	check(s.world.position>=0,"forest/event tile exists")
	check(s.save_world(),"portal location persisted")
	return s

func original_contract() -> void:
	check(Beats.count()==2,"only original arrival and portal-reveal beats")
	check(Beats.beat(0)==Portal.FIRST_BEAT,"first scene unchanged")
	check(Beats.beat(1).id=="portal_reveal","original second beat ID")
	check(Beats.beat(1).effect=="제단에서 보았던 문양과 같은 빛이 석문 전체를 타고 흐르며 전이문이 거세게 요동친다.","original second narration exact")
	check(Beats.beat(1).dialogue=="","no invented dialogue")
	check(Beats.beat(1).speaker=="","no invented speaker")
	check(Beats.beat(1).visual=="energy","second scene uses energy layer")
	check(Beats.beat(2).is_empty(),"third scene inaccessible")
	check(Beats.beat(-1).is_empty(),"negative scene rejected")
	check(Beats.layer_for("base").is_empty(),"first scene shows background only")
	check(Beats.layer_for("energy")==Beats.ENERGY_ART,"second scene selects energy layer")
	check(Beats.layer_for("cultists").is_empty(),"future cultist layer inaccessible")
	check(Beats.layer_for("omen").is_empty(),"future omen layer inaccessible")
	check(Beats.ENERGY_ART=="res://assets/map/events/ritual-portal-energy-layer.webp","original Godot energy art used")
	check(ResourceLoader.exists(Beats.ENERGY_ART),"energy layer artwork resource exists")
	check(ResourceLoader.exists(Beats.BASE_ART),"first scene background remains present")
	check(Registry.definition(Portal.EVENT_ID).is_empty(),"final portal battle remains disabled")
	check(Portal.progress_flag(1)=="event:ritual_portal_trace_01:beat:1","original second scene has durable checkpoint")
	check(Portal.progress_flag(0).is_empty(),"arrival already represented by seen receipt")
	check(Portal.progress_flag(2).is_empty(),"later story beat has no writable checkpoint")
	var copied: Dictionary=Beats.beat(1)
	copied.effect="tampered"
	check(Beats.beat(1).effect.begins_with("제단에서 보았던 문양"),"beat data cannot be changed through accessor")
	var src: String=FileAccess.get_file_as_string("res://map.gd")
	check(src.contains("func show_ritual_portal_intro(index: int) -> void:"),"first scene entry wrapper preserved")
	check(src.contains("func show_ritual_portal_beat(index: int) -> void:"),"shared saved-beat renderer installed")
	check(src.contains("RitualPortalEntry.current_beat(session)"),"UI reads saved beat, not UI-only state")
	check(src.contains("RitualPortalBeats.beat(beat_index)"),"UI obtains current canonical beat")
	check(src.contains("RitualPortalBeats.layer_for(str(beat.visual))"),"visual selects only allowed energy layer")
	check(src.contains("InkSceneReveal.play(energy_art)"),"original layer reveals over ruin background")
	check(src.contains("RitualPortalEntry.advance(session,index,shown_beat)"),"Continue invokes transactional checkpoint")
	check(src.contains('location_button(panel,"계속"'),"arrival has explicit Continue")
	check(src.contains("if beat_index==0:"),"Continue appears only on original first beat")
	check(src.contains('location_button(panel,"숲 기능"'),"forest actions preserved")
	check(src.contains('location_button(panel,"돌아가기"'),"board return preserved")
	check(not src.contains("start_ritual_portal_battle("),"battle handler not created")
	check(not src.contains("complete_ritual_portal("),"revival completion handler not created")

func advance_and_reconnect(tile: String) -> void:
	var s=fixture("advance_"+tile,tile)
	var at: int=s.world.position
	check(Portal.begin(s,at),"first portal discovery saved")
	check(Portal.current_beat(s)==0,"arrival beat initially open")
	check(not s.event_flag_is_set(Portal.progress_flag(1)),"energy not revealed before Continue")
	check(not Portal.advance(s,at,1),"skipping ahead prohibited")
	check(not Portal.advance(s,at+1,0),"other tile cannot advance")
	check(Portal.advance(s,at,0),"one Continue saves portal energy reveal")
	check(s.event_flag_is_set(Portal.progress_flag(1)),"second beat progress receipt persisted")
	check(Portal.current_beat(s)==1,"second original beat becomes current")
	var saved: Dictionary=s.world.snapshot().duplicate(true)
	check(not Portal.advance(s,at,0),"stale duplicate Continue blocked")
	check(not Portal.advance(s,at,1),"third scene cannot unlock")
	check(Portal.begin(s,at),"reopening second scene remains idempotent")
	check(s.world.snapshot()==saved,"repeat actions never add progression")
	check(not s.event_flag_is_set(Portal.COMPLETE_FLAG),"portal event not completed")
	check(not s.event_flag_is_set(Portal.PORTAL_FOUND_FLAG),"future portal found marker not granted")
	check(not s.event_flag_is_set(Portal.SITE_LOCATION_FLAG),"future location clue not granted")
	check(not s.event_flag_is_set(Portal.TRACKING_COMPLETE_FLAG),"ritual tracking still in progress")
	check(s.event_flag_is_set(Portal.TRACKING_FLAG),"earlier quest remains active")
	check(not s.event_flag_is_set(Portal.INTERVENTION_FLAG),"future intervention quest still locked")
	check(not s.event_flag_is_set(Portal.REVIVED_FLAG),"monster king not revived")
	check(not s.event_flag_is_set(Portal.HUNT_FLAG),"king hunt not activated")
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty(),"no battle created")
	check(s.world.pending_reward.is_empty(),"no reward generated")
	s.reload_world()
	check(Portal.can_enter(s,at),"eligible location remains after reload")
	check(Portal.current_beat(s)==1,"energy stage resumes without replaying arrival")
	check(s.event_flag_is_set(Portal.progress_flag(1)),"checkpoint survives save roundtrip")
	check(Portal.begin(s,at),"reopen save does not reset stage")
	check(Portal.current_beat(s)==1,"reopening cannot rewind stage")
	s.free()

func fail_closed() -> void:
	var s=fixture("guards","forest")
	var at: int=s.world.position
	check(not Portal.advance(s,at,0),"cannot advance without first discovery")
	check(Portal.begin(s,at),"first discovery establishes stage")
	var stable: Dictionary=s.world.snapshot().duplicate(true)
	s.world.pending_move={"index":at}
	check(not Portal.advance(s,at,0),"movement pending blocks advancement")
	s.world.restore(stable)
	s.world.pending_reward={"kind":"test"}
	check(not Portal.advance(s,at,0),"pending reward blocks advancement")
	s.world.restore(stable)
	s.world.active_encounter={"id":"test"}
	check(not Portal.advance(s,at,0),"active encounter blocks advancement")
	s.world.restore(stable)
	s.world.position=at+1
	check(not Portal.advance(s,at,0),"wrong current position blocks advancement")
	s.world.restore(stable)
	s.world.event_flags[Altar.COMPLETE_FLAG]=false
	check(not Portal.advance(s,at,0),"corrupt prior altar completion blocks advancement")
	s.world.restore(stable)
	s.world.event_flags[Portal.COMPLETE_FLAG]=true
	check(not Portal.advance(s,at,0),"future completion flag blocks advancement")
	s.world.restore(stable)
	s.world.story_events[Portal.EVENT_ID].status="active"
	check(not Portal.advance(s,at,0),"future active status blocks advancement")
	s.world.restore(stable)
	check(Portal.current_beat(s)==0,"guard restoration preserves first scene")
	var real_path: String=s.save_file_path
	s.save_file_path="user://ritual_portal_energy_missing_%d/failed.json" % OS.get_process_id()
	check(not Portal.advance(s,at,0),"save failure blocks energy reveal")
	check(s.world.snapshot()==stable,"save failure rolls back progression and all flags")
	check(not s.event_flag_is_set(Portal.progress_flag(1)),"failed checkpoint remains clear")
	check(Portal.current_beat(s)==0,"failed save keeps original first scene")
	s.save_file_path=real_path
	check(Portal.advance(s,at,0),"retry after save recovery succeeds")
	s.reload_world()
	check(Portal.current_beat(s)==1,"recovered energy reveal resumes after reload")
	s.free()

func inconsistent_receipts() -> void:
	var s=fixture("receipts","event")
	var at: int=s.world.position
	s.world.event_flags[Portal.progress_flag(1)]=true
	check(not Portal.begin(s,at),"forged energy receipt before discovery rejected")
	check(Portal.current_beat(s)==-1,"forged receipt cannot be rendered")
	s.world.event_flags.erase(Portal.progress_flag(1))
	check(Portal.begin(s,at),"legitimate arrival still works")
	check(Portal.advance(s,at,0),"legitimate second beat saves")
	s.world.event_flags[Portal.SEEN_FLAG]=false
	check(not Portal.begin(s,at),"missing discovery receipt cannot be bypassed")
	check(Portal.current_beat(s)==-1,"inconsistent scene cannot be shown")
	s.free()

func _run() -> void:
	original_contract()
	advance_and_reconnect("forest")
	advance_and_reconnect("event")
	fail_closed()
	inconsistent_receipts()
	for path in paths: cleanup(path)
	print("RITUAL_PORTAL_ENERGY_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
