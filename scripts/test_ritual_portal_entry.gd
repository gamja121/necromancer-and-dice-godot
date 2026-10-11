extends SceneTree
## P1-05J-1 arrival regression retained after adding J-2 energy scene.
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

func check(ok: bool, reason: String) -> void:
	if ok:
		passed+=1
		print("PASS ritual-portal-entry: ",reason)
	else:
		failed+=1
		printerr("FAIL ritual-portal-entry: ",reason)

func cleanup(path: String) -> void:
	for ext in ["",".tmp"]:
		if FileAccess.file_exists(path+ext):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+ext))

## Use the actual preceding altar story transition rather than fabricating
## portal eligibility from a single future quest boolean.
func fixture(tag: String, tile: String="forest"):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://ritual_portal_entry_%d_%s.json" % [OS.get_process_id(),tag]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	s.world.story_events[CultistRumor.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	s.world.event_flags[CultistRumor.SEEN_FLAG]=true
	s.world.event_flags[CultistRumor.COMPLETE_FLAG]=true
	s.world.event_flags[CultistRumor.TRACKING_FLAG]=true
	s.world.position=s.world.tiles.find("altar")
	check(s.save_world(),"completed earlier cultist rumor fixture saved")
	var altar_index: int=s.world.position
	check(Altar.begin(s,altar_index),"altar first arrival persisted")
	check(Altar.advance(s,altar_index,0),"altar ritual reveal persisted")
	check(Altar.advance(s,altar_index,1),"altar choices reached")
	check(Altar.choose(s,altar_index,2,"pass"),"altar pass chosen")
	check(Altar.finish(s,altar_index),"previous altar completed by actual final confirmation")
	check(Altar.completed(s),"source altar completed predicate true")
	s.world.position=s.world.tiles.find(tile)
	check(s.world.position>=0,"eligible forest/event tile exists")
	check(s.save_world(),"new location arrival saved")
	return s

func original_contract() -> void:
	check(Beats.count()==2,"first and second canonical portal beats exist")
	check(Beats.beat(0).id=="arrival","original beat id")
	check(Beats.beat(0).effect=="제단에서 이어진 흔적을 따라가자 숲 깊은 폐허에서 거대한 전이문을 발견한다.","exact original arrival narration")
	check(Beats.beat(0).dialogue=="","no invented dialogue")
	check(Beats.beat(0).speaker=="","no invented speaker")
	check(Beats.beat(0).visual=="base","first beat uses the unchanged ruin base art")
	check(Beats.beat(1).id=="portal_reveal","second original portal beat exists, first unchanged")
	check(Beats.beat(2).is_empty(),"third ritual beat not unlocked")
	check(Beats.BASE_ART=="res://assets/map/events/ritual-portal-ruins-base.webp","original ruin art path reused")
	check(Portal.BASE_ART==Beats.BASE_ART,"UI entry uses same original art")
	check(Portal.FIRST_BEAT==Beats.beat(0),"entry and canonical scene data match")
	check(ResourceLoader.exists(Beats.BASE_ART),"existing art resource loads")
	check(Registry.definition(Portal.EVENT_ID).is_empty(),"ritual-portal battle still unregistered")
	var src: String=FileAccess.get_file_as_string("res://map.gd")
	check(src.contains('const RitualPortalEntry = preload("res://systems/ritual_portal_entry.gd")'),"story entry connected")
	check(src.contains('if type in ["forest","event"] and RitualPortalEntry.can_enter(session,index):'),"only designated forest or wildcard event tiles fire")
	check(src.contains("if RitualPortalEntry.begin(session,index):"),"story discovery saved before display")
	check(src.contains('func show_ritual_portal_intro(index: int) -> void:'),"separate portal presentation")
	check(src.contains("RitualPortalBeats.beat(beat_index)"),"presentation loads original beat from persisted index")
	check(src.contains("RitualPortalEntry.BASE_ART"),"presentation uses original base art")
	check(src.contains('InkSceneReveal.play(art)'),"existing ink reveal preserved")
	check(src.contains('사건 · 마물의 왕 부활 의식'),"original story heading")
	check(src.contains('location_button(panel,"숲 기능"'),"existing forest actions accessible")
	check(src.contains('location_button(panel,"돌아가기"'),"return to board available")
	check(src.contains('session.get_story_event(RitualPortalEntry.EVENT_ID).status=="seen"'),"restart resumes only previously discovered portal")
	check(not src.contains("start_ritual_portal_battle("),"no hidden or premature portal fight handler")
	check(not src.contains("finish_ritual_portal("),"no premature portal completion handler")

func first_discovery(tile: String) -> void:
	var s=fixture("first_"+tile,tile)
	var at: int=s.world.position
	check(Portal.can_enter(s,at),"actual forest/event landing permits first scene")
	check(not Portal.can_enter(s,at+1),"adjacent tile preview cannot trigger event")
	check(s.get_story_event(Portal.EVENT_ID).status=="unseen","first portal scene starts unseen")
	check(Portal.current_beat(s)==-1,"unseen scene cannot be resumed before click")
	check(not s.event_flag_is_set(Portal.SEEN_FLAG),"no premature discovery flag")
	check(Portal.begin(s,at),"first portal arrival saved")
	check(s.get_story_event(Portal.EVENT_ID).status=="seen","portal story now seen")
	check(s.event_flag_is_set(Portal.SEEN_FLAG),"discovery event receipt true")
	check(Portal.current_beat(s)==0,"original first beat is current")
	check(not s.event_flag_is_set(Portal.COMPLETE_FLAG),"discovery not marked complete")
	check(not s.event_flag_is_set(Portal.PORTAL_FOUND_FLAG),"portal quest success still locked")
	check(not s.event_flag_is_set(Portal.SITE_LOCATION_FLAG),"ritual site location not finalized")
	check(not s.event_flag_is_set(Portal.TRACKING_COMPLETE_FLAG),"tracking completion not granted")
	check(not s.event_flag_is_set(Portal.INTERVENTION_FLAG),"final intervention remains inactive")
	check(not s.event_flag_is_set(Portal.REVIVED_FLAG),"king not revived by discovery")
	check(not s.event_flag_is_set(Portal.HUNT_FLAG),"king hunt not activated")
	check(s.event_flag_is_set(Portal.TRACKING_FLAG),"prior tracking quest stays active")
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty(),"no combat launched")
	check(s.world.pending_reward.is_empty(),"no reward granted")
	var stored: Dictionary=s.world.snapshot().duplicate(true)
	check(Portal.begin(s,at),"reopening the same arrival is idempotent")
	check(s.world.snapshot()==stored,"reopening does not mutate the run")
	check(not Portal.begin(s,at+1),"adjacent re-entry rejected")
	s.reload_world()
	check(Portal.can_enter(s,at),"saved portal scene eligible after restart")
	check(Portal.current_beat(s)==0,"portal first scene resumes after restart")
	check(s.get_story_event(Portal.EVENT_ID).status=="seen","discovery status preserved")
	check(s.event_flag_is_set(Portal.SEEN_FLAG),"seen flag persisted")
	check(not s.event_flag_is_set(Portal.COMPLETE_FLAG),"still no event completion")
	check(not s.event_flag_is_set(Portal.REVIVED_FLAG),"reload did not awaken king")
	check(Portal.begin(s,at),"resume remains idempotent after reload")
	s.free()

func guard_prerequisites() -> void:
	var s=fixture("guards")
	var at: int=s.world.position
	var stable: Dictionary=s.world.snapshot().duplicate(true)
	s.world.event_flags[Portal.TRACKING_FLAG]=false
	check(not Portal.can_enter(s,at),"missing active tracking blocks portal")
	check(not Portal.begin(s,at),"cannot forge portal without tracking")
	s.world.restore(stable)
	s.world.event_flags[Altar.COMPLETE_FLAG]=false
	check(not Portal.can_enter(s,at),"missing actual altar completion blocks entry")
	s.world.restore(stable)
	s.world.story_events[Altar.EVENT_ID].status="seen"
	check(not Portal.can_enter(s,at),"unfinished altar does not unlock portal")
	s.world.restore(stable)
	s.world.tiles[at]="graveyard"
	check(not Portal.begin(s,at),"wrong tile cannot trigger portal")
	s.world.restore(stable)
	s.world.pending_move={"index":at}
	check(not Portal.begin(s,at),"pending movement blocks portal discovery")
	s.world.restore(stable)
	s.world.pending_reward={"kind":"test"}
	check(not Portal.begin(s,at),"pending rewards block portal discovery")
	s.world.restore(stable)
	s.world.active_encounter={"id":"test"}
	check(not Portal.begin(s,at),"active battle blocks portal")
	s.world.restore(stable)
	for flag in [Portal.COMPLETE_FLAG,Portal.TRACKING_COMPLETE_FLAG,Portal.PORTAL_FOUND_FLAG,Portal.SITE_LOCATION_FLAG,Portal.INTERVENTION_FLAG,Portal.REVIVED_FLAG,Portal.HUNT_FLAG,Portal.BATTLE_WON_FLAG,Portal.BATTLE_LOST_FLAG,Portal.RESULT_PENDING_FLAG]:
		s.world.event_flags[flag]=true
		check(not Portal.begin(s,at),"future outcome %s blocks first scene" % flag)
		s.world.restore(stable)
	s.world.story_events[Portal.EVENT_ID]={"status":"active","choice":"","battle_result":""}
	check(not Portal.begin(s,at),"active portal state not allowed until later stages")
	s.world.restore(stable)
	s.world.story_events[Portal.EVENT_ID]={"status":"seen","choice":"","battle_result":""}
	check(not Portal.begin(s,at),"seen without seen-flag rejected")
	s.world.restore(stable)
	s.world.event_flags[Portal.SEEN_FLAG]=true
	check(not Portal.begin(s,at),"unseen with fabricated seen-flag rejected")
	s.world.restore(stable)
	s.world.story_events[Portal.EVENT_ID]={"status":"unseen","choice":"intervene","battle_result":""}
	check(not Portal.begin(s,at),"premature intervention choice rejected")
	s.world.restore(stable)
	s.world.story_events[Portal.EVENT_ID]={"status":"unseen","choice":"","battle_result":"won"}
	check(not Portal.begin(s,at),"premature battle result rejected")
	s.world.restore(stable)
	check(Portal.can_enter(s,at),"guards restore eligible baseline")
	s.free()

func save_rollback() -> void:
	var s=fixture("save_fail","forest")
	var at: int=s.world.position
	var before: Dictionary=s.world.snapshot().duplicate(true)
	var valid_path: String=s.save_file_path
	s.save_file_path="user://ritual_portal_missing_%d/failed.json" % OS.get_process_id()
	check(not Portal.begin(s,at),"invalid save path rejects first scene")
	check(s.world.snapshot()==before,"failed save restores story status and seen flag")
	check(s.get_story_event(Portal.EVENT_ID).status=="unseen","failed discovery stays unseen")
	check(not s.event_flag_is_set(Portal.SEEN_FLAG),"failed seen receipt rolled back")
	check(not s.event_flag_is_set(Portal.COMPLETE_FLAG),"failed save cannot complete event")
	s.save_file_path=valid_path
	check(Portal.begin(s,at),"valid save path allows retry")
	s.reload_world()
	check(Portal.current_beat(s)==0,"recovered scene resumes correctly")
	s.free()

func _run() -> void:
	original_contract()
	first_discovery("forest")
	first_discovery("event")
	guard_prerequisites()
	save_rollback()
	for path in paths: cleanup(path)
	print("RITUAL_PORTAL_ENTRY_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
