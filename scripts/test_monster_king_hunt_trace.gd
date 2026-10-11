extends SceneTree
## P1-05K-2: source-canonical corrupted carcass and hunter, guarded
## Continue, both real portal revival modes, save/load and rollback.
const SessionScript=preload("res://systems/run_session.gd")
const Rumor=preload("res://systems/cultist_rumor_entry.gd")
const Altar=preload("res://systems/cultist_altar_entry.gd")
const Portal=preload("res://systems/ritual_portal_entry.gd")
const Hunt=preload("res://systems/monster_king_hunt_entry.gd")
const Beats=preload("res://systems/monster_king_hunt_beats.gd")
const Registry=preload("res://systems/story_battle_registry.gd")

class BattleResult:
	extends RefCounted
	var outcome: String
	var units: Array=[]
	func _init(who: String) -> void: outcome=who
	func winner() -> String: return outcome
	func find_id(_id: String) -> Dictionary: return {}

var passed: int=0
var failed: int=0
var paths: Array[String]=[]

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	if ok:
		passed+=1
		print("PASS monster-king-hunt-trace: ",what)
	else:
		failed+=1
		printerr("FAIL monster-king-hunt-trace: ",what)

func cleanup(path: String) -> void:
	for ext in ["",".tmp"]:
		if FileAccess.file_exists(path+ext):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+ext))

## Use real portal choices and win/loss outcomes, not invented hunt flags.
func fixture(tag: String, side: String, destination: String):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://monster_king_hunt_trace_%d_%s.json" % [OS.get_process_id(),tag]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	s.world.story_events[Rumor.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	s.world.event_flags[Rumor.SEEN_FLAG]=true
	s.world.event_flags[Rumor.COMPLETE_FLAG]=true
	s.world.event_flags[Rumor.TRACKING_FLAG]=true
	s.world.position=s.world.tiles.find("altar")
	check(s.save_world(),"prior rumor saved")
	var at: int=s.world.position
	check(Altar.begin(s,at),"altar first arrival")
	check(Altar.advance(s,at,0),"altar ritual")
	check(Altar.advance(s,at,1),"altar choice")
	check(Altar.choose(s,at,2,"pass"),"altar passage")
	check(Altar.finish(s,at),"ritual tracking unlocked")
	s.world.position=s.world.tiles.find("forest")
	check(s.world.position>=0 and s.save_world(),"actual ritual portal location saved")
	at=s.world.position
	check(Portal.begin(s,at),"portal discovery")
	for beat_index in [0,1,2,3]:
		check(Portal.advance(s,at,beat_index),"portal beat %d saved" % beat_index)
	check(Portal.choose_intervention(s,at,4),"intervention intent saved")
	check(s.start_story_encounter(Portal.EVENT_ID,at,[s.world.roster[0].id]),"real portal fight started")
	check(s.finish_encounter(BattleResult.new(side)),"real portal fight finished")
	check(s.acknowledge_story_battle_result(Portal.EVENT_ID),"battle result acknowledged")
	check(Portal.finish(s,at),"real portal result and king hunt committed")
	check(Portal.completed(s),"completed portal receipts valid")
	s.world.position=s.world.tiles.find(destination)
	check(s.world.position>=0 and s.save_world(),"actual hunt location saved")
	at=s.world.position
	check(Hunt.begin(s,at),"first hunt arrival saved")
	return s

func original_contract() -> void:
	check(Beats.count()==4,"first two hunt scenes preserved alongside hunter dialogue and destination clue")
	check(Beats.beat(0)==Hunt.FIRST_BEAT,"first scene remains identical")
	check(Beats.beat(1).id=="trace","original second beat id")
	check(Beats.beat(1).effect=="검게 변한 뿌리 곁에 오염된 마물의 사체가 있다. 흔적을 따라가던 마물 사냥꾼이 그 앞에 서 있다.","exact source second narration")
	check(Beats.beat(1).dialogue=="" and Beats.beat(1).speaker=="","no invented dialogue or narrator")
	check(Beats.beat(1).visual=="scene","source-corrupted scene is visual")
	check(Beats.beat(2).is_empty(),"missing revival mode cannot show third dialogue")
	check(Beats.beat(2,"weakened").id=="revival","third beat available after saved trace")
	check(Beats.beat(3).id=="destination","fourth destination clue data is available")
	check(Beats.beat(-1).is_empty(),"invalid negative beat rejected")
	check(Beats.BASE_ART=="res://assets/map/events/monster-hunter-worldtree-base.webp","previous world-tree art retained")
	check(Beats.SCENE_ART=="res://assets/map/events/monster-hunter-corrupted-beast-scene.webp","existing corrupted beast layer reused")
	check(Beats.visual_art("scene")==Beats.SCENE_ART,"source scene visual maps to corrupted carcass artwork")
	check(Beats.visual_art("portrait")==Beats.PORTRAIT_ART,"third original hunter portrait available")
	check(Beats.visual_art("base").is_empty(),"arrival remains base-only")
	check(ResourceLoader.exists(Beats.BASE_ART),"original tree base resource loads")
	check(ResourceLoader.exists(Beats.SCENE_ART),"original beast layer resource loads")
	check(Registry.definition(Hunt.EVENT_ID).is_empty(),"king hunt investigation is not a battle")
	check(Hunt.progress_flag(0).is_empty(),"arrival uses seen receipt")
	check(Hunt.progress_flag(1)=="event:monster_king_hunt_trace_01:beat:1","trace has a durable checkpoint")
	check(Hunt.progress_flag(2)=="event:monster_king_hunt_trace_01:beat:2","third scene has a separate checkpoint")
	check(Hunt.progress_flag(3)=="event:monster_king_hunt_trace_01:beat:3","fourth destination can be checkpointed only after dialogue")
	var copied: Dictionary=Beats.beat(1)
	copied.effect="changed"
	check(Beats.beat(1).effect.begins_with("검게 변한 뿌리"),"source beat cannot be mutated through accessor")
	var src: String=FileAccess.get_file_as_string("res://map.gd")
	check(src.contains("func show_monster_king_hunt_intro(index: int) -> void:"),"first scene wrapper preserved")
	check(src.contains("func show_monster_king_hunt_beat(index: int) -> void:"),"saved scene renderer added")
	check(src.contains("MonsterKingHuntEntry.current_beat(session)"),"UI uses persisted checkpoint")
	check(src.contains("MonsterKingHuntBeats.beat(beat_index,MonsterKingHuntEntry.revival_mode(session))"),"renderer uses saved source beat and real revival mode")
	check(src.contains("MonsterKingHuntBeats.visual_art(str(beat.visual))"),"artwork keyed to canonical visual")
	check(src.contains("InkSceneReveal.play(scene_art)"),"corrupted beast layer reveals over source base")
	check(src.contains("MonsterKingHuntEntry.advance(session,index,shown_beat)"),"Continue saves the trace")
	check(src.contains('location_button(panel,"계속"'),"first scene has deliberate Continue")
	check(src.contains("if beat_index<3:"),"Continue appears before destination clue, not after fourth scene")
	check(src.contains('location_button(panel,"세계수 기능"'),"world-tree action preserved")
	check(src.contains('location_button(panel,"돌아가기"'),"map return preserved")
	check(src.contains('session.get_story_event(MonsterKingHuntEntry.EVENT_ID).status=="seen"'),"restart only restores already-seen hunt")
	check(not src.contains("start_monster_king_hunt_battle("),"no premature king final fight")
	check(not src.contains("finish_monster_king_hunt("),"no premature quest completion")

func trace_branch(side: String, destination: String) -> void:
	var s=fixture(side+"_"+destination,side,destination)
	var at: int=s.world.position
	var weak: bool=side=="ally"
	check(Hunt.can_enter(s,at),"eligible saved hunt first scene")
	check(Hunt.current_beat(s)==0,"first scene opens before Continue")
	check(not s.event_flag_is_set(Hunt.progress_flag(1)),"trace checkpoint absent before Continue")
	check(not Hunt.advance(s,at,1),"cannot skip directly to next beat")
	check(not Hunt.advance(s,at+1,0),"adjacent preview never advances")
	check(Hunt.advance(s,at,0),"Continue saves exactly second scene")
	check(Hunt.current_beat(s)==1,"second source trace now displayed")
	check(s.event_flag_is_set(Hunt.progress_flag(1)),"second beat receipt persisted")
	check(s.event_flag_is_set(Hunt.SEEN_FLAG),"original seen flag kept")
	check(s.get_story_event(Hunt.EVENT_ID).status=="seen","event stays unfinished")
	check(s.get_story_event(Hunt.EVENT_ID).choice=="","no invented choice")
	check(s.get_story_event(Hunt.EVENT_ID).battle_result=="","no invented battle")
	var saved: Dictionary=s.world.snapshot().duplicate(true)
	check(not Hunt.advance(s,at,0),"stale Continue cannot repeat")
	check(not Hunt.advance(s,at,2),"cannot skip ahead past saved corrupted-trace scene")
	check(Hunt.begin(s,at),"reopen does not rewind")
	check(s.world.snapshot()==saved,"reopening changes no world state")
	check(not s.event_flag_is_set(Hunt.COMPLETE_FLAG),"hunt story not completed")
	check(s.event_flag_is_set(Hunt.HUNT_ACTIVE_FLAG),"hunt quest remains active")
	check(not s.event_flag_is_set(Hunt.HUNT_COMPLETE_FLAG),"hunt quest remains uncompleted")
	check(not s.event_flag_is_set(Hunt.SEALED_RUINS_FLAG),"sealed ruins not located early")
	check(not s.event_flag_is_set(Hunt.FINAL_BATTLE_FLAG),"final battle stays locked")
	check(s.event_flag_is_set(Hunt.WEAKENED_FLAG)==weak,"real revival result preserved")
	check(s.event_flag_is_set(Hunt.FULL_REVIVAL_FLAG)!=weak,"opposite revival flag remains false")
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty(),"new scene did not open combat")
	check(s.world.pending_reward.is_empty(),"new scene grants no reward")
	s.reload_world()
	check(Hunt.can_enter(s,at),"reconnect restores eligibility")
	check(Hunt.current_beat(s)==1,"reconnect opens the saved second scene")
	check(s.event_flag_is_set(Hunt.progress_flag(1)),"progress checkpoint persists")
	check(Hunt.begin(s,at),"repeated arrival remains idempotent after reload")
	check(Hunt.current_beat(s)==1,"reload does not rewind to arrival")
	s.free()

func fail_save_and_guards() -> void:
	var s=fixture("guards","ally","unknown")
	var at: int=s.world.position
	var baseline: Dictionary=s.world.snapshot().duplicate(true)
	check(not Hunt.advance(s,at,2),"invalid source beat cannot advance")
	var good: String=s.save_file_path
	s.save_file_path="user://missing_hunt_trace_%d/failed.json" % OS.get_process_id()
	check(not Hunt.advance(s,at,0),"failed write prevents trace")
	check(s.world.snapshot()==baseline,"failed write restores all state")
	check(not s.event_flag_is_set(Hunt.progress_flag(1)),"failed save leaves progress flag absent")
	check(Hunt.current_beat(s)==0,"failed write returns to first scene")
	s.save_file_path=good
	s.world.pending_move={"test":true}
	check(not Hunt.advance(s,at,0),"pending movement blocks Continue")
	s.world.restore(baseline)
	s.world.pending_reward={"test":true}
	check(not Hunt.advance(s,at,0),"unclaimed reward blocks Continue")
	s.world.restore(baseline)
	s.world.active_encounter={"id":"test"}
	check(not Hunt.advance(s,at,0),"active battle blocks Continue")
	s.world.restore(baseline)
	s.world.position=at+1
	check(not Hunt.advance(s,at,0),"off-tile Continue blocked")
	s.world.restore(baseline)
	s.world.event_flags[Portal.COMPLETE_FLAG]=false
	check(not Hunt.advance(s,at,0),"unfinished portal blocks Continue")
	s.world.restore(baseline)
	s.world.event_flags[Hunt.SEALED_RUINS_FLAG]=true
	check(not Hunt.advance(s,at,0),"future location receipt blocks Continue")
	s.world.restore(baseline)
	s.world.story_events[Hunt.EVENT_ID].choice="fight"
	check(not Hunt.advance(s,at,0),"fabricated choice blocks Continue")
	s.world.restore(baseline)
	check(Hunt.advance(s,at,0),"valid Continue works after restoring storage")
	s.reload_world()
	check(Hunt.current_beat(s)==1,"successful retry persists after reload")
	s.free()

func receipts() -> void:
	var s=fixture("receipt","enemy","event")
	var at: int=s.world.position
	s.world.event_flags[Hunt.progress_flag(1)]=true
	s.world.event_flags[Hunt.SEEN_FLAG]=false
	check(not Hunt.can_enter(s,at),"second checkpoint without discovery receipt rejected")
	s.world.event_flags[Hunt.SEEN_FLAG]=true
	s.world.story_events[Hunt.EVENT_ID].status="unseen"
	check(not Hunt.can_enter(s,at),"second checkpoint without saved first scene rejected")
	s.free()

func _run() -> void:
	original_contract()
	trace_branch("ally","unknown")
	trace_branch("enemy","event")
	fail_save_and_guards()
	receipts()
	for path in paths: cleanup(path)
	print("MONSTER_KING_HUNT_TRACE_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
