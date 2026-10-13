extends SceneTree
## P1-05K-3: exact hunter response to weakened/full revival,
## saved sequential third beat, real portal branch, no hunt resolution.
const SessionScript=preload("res://systems/run_session.gd")
const Rumor=preload("res://systems/cultist_rumor_entry.gd")
const Altar=preload("res://systems/cultist_altar_entry.gd")
const Portal=preload("res://systems/ritual_portal_entry.gd")
const Hunt=preload("res://systems/monster_king_hunt_entry.gd")
const Beats=preload("res://systems/monster_king_hunt_beats.gd")

class BattleResult:
	extends RefCounted
	var outcome: String
	var units: Array=[]
	func _init(side: String) -> void: outcome=side
	func winner() -> String: return outcome
	func find_id(_id: String) -> Dictionary: return {}

var passed: int=0
var failed: int=0
var paths: Array[String]=[]

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	if ok:
		passed+=1
		print("PASS monster-king-hunt-revival-dialogue: ",detail)
	else:
		failed+=1
		printerr("FAIL monster-king-hunt-revival-dialogue: ",detail)

func cleanup(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func fixture(tag: String, side: String, tile: String):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://monster_king_hunt_revival_%d_%s.json" % [OS.get_process_id(),tag]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	# Legacy narrative coverage runs at unlocked contamination; gate edges have their own test.
	s.world.contamination = 100
	s.world.story_events[Rumor.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	s.world.event_flags[Rumor.SEEN_FLAG]=true
	s.world.event_flags[Rumor.COMPLETE_FLAG]=true
	s.world.event_flags[Rumor.TRACKING_FLAG]=true
	s.world.position=s.world.tiles.find("altar")
	check(s.save_world(),"prerequisite rumor saved")
	var at: int=s.world.position
	check(Altar.begin(s,at),"previous altar discovered")
	check(Altar.advance(s,at,0),"altar ritual viewed")
	check(Altar.advance(s,at,1),"altar choice viewed")
	check(Altar.choose(s,at,2,"pass"),"altar passage saved")
	check(Altar.finish(s,at),"ritual tracking quest activated")
	s.world.position=s.world.tiles.find("forest")
	check(s.world.position>=0 and s.save_world(),"portal location saved")
	at=s.world.position
	check(Portal.begin(s,at),"portal arrived")
	for beat in [0,1,2,3]:
		check(Portal.advance(s,at,beat),"portal stage %d saved" % beat)
	check(Portal.choose_intervention(s,at,4),"intervention choice saved")
	check(s.start_story_encounter(Portal.EVENT_ID,at,[s.world.roster[0].id]),"real portal combat started")
	check(s.finish_encounter(BattleResult.new(side)),"real win/loss saved")
	check(s.acknowledge_story_battle_result(Portal.EVENT_ID),"battle result acknowledged")
	check(Portal.finish(s,at),"revival mode and king hunt atomically finalized")
	s.world.position=s.world.tiles.find(tile)
	check(s.world.position>=0 and s.save_world(),"actual tree or wildcard landing recorded")
	at=s.world.position
	check(Hunt.begin(s,at),"first king hunt arrival persisted")
	check(Hunt.advance(s,at,0),"second corrupted-beast beat persisted")
	return s

func source_contract() -> void:
	check(Beats.count()==5,"fourth destination clue added after canonical first three scenes")
	check(Beats.beat(0)==Hunt.FIRST_BEAT,"original arrival identical")
	check(Beats.beat(1).id=="trace","second beast scene preserved")
	var weak: Dictionary=Beats.beat(2,"weakened")
	var full: Dictionary=Beats.beat(2,"full")
	check(weak.id=="revival" and full.id=="revival","third source ID both branches")
	check(weak.effect=="마물 사냥꾼이 끊겼다 이어진 흔적을 가리킨다.","exact weakened revival narration")
	check(weak.dialogue=="몸이 아직 온전하지 않아. 하지만 멀리 가진 못했어.","exact weakened hunter dialogue")
	check(full.effect=="세계수의 뿌리까지 죽어 가고 있다. 사냥꾼은 주변의 오염을 살핀다.","exact full revival narration")
	check(full.dialogue=="뿌리 깊은 곳까지 죽었군. 저 힘으로 놈을 상대해야 한다니.","exact full hunter dialogue")
	check(weak.speaker=="마물 사냥꾼" and full.speaker=="마물 사냥꾼","correct original speaker")
	check(weak.visual=="portrait" and full.visual=="portrait","both third scenes use the original hunter portrait")
	check(Beats.beat(2).is_empty(),"missing revival mode never defaults to a branch")
	check(Beats.beat(2,"invalid").is_empty(),"invalid revival mode cannot present a story")
	check(Beats.beat(3,"weakened").id=="destination","next destination data available but gated by progress")
	check(Beats.visual_art("portrait")==Beats.PORTRAIT_ART,"source portrait asset mapping")
	check(Beats.PORTRAIT_ART=="res://assets/map/events/monster-hunter-pen-clean.webp","reuses unmodified original hunter portrait")
	check(Beats.visual_art("scene")==Beats.SCENE_ART,"original corrupted scene artwork unchanged")
	check(Beats.visual_art("destination").is_empty(),"next destination scene has no visual unlock")
	check(ResourceLoader.exists(Beats.PORTRAIT_ART),"hunter portrait resource loads")
	var changed: Dictionary=Beats.beat(2,"full")
	changed.effect="wrong"
	check(Beats.beat(2,"full").effect.begins_with("세계수의 뿌리"),"getter returns immutable source copy")
	check(Hunt.progress_flag(2)=="event:monster_king_hunt_trace_01:beat:2","third scene durable receipt")
	check(Hunt.progress_flag(3)=="event:monster_king_hunt_trace_01:beat:3","next destination checkpoint is sequential")
	var src: String=FileAccess.get_file_as_string("res://map.gd")
	check(src.contains("MonsterKingHuntBeats.beat(beat_index,MonsterKingHuntEntry.revival_mode(session))"),"mode derived from saved portal outcome, never guessed")
	check(src.contains("var visual: String=str(beat.visual)") and src.contains("MonsterKingHuntBeats.visual_art(visual)"),"original portrait layer chosen by scene visual")
	check(src.contains("if beat_index==0: InkSceneReveal.play(art)") and src.contains('MonsterHunterLayerMotion.play(hunt_layer,is_portrait,beat.id==("revival" if is_portrait else "trace"))'),"portrait uses hunter layer motion over ink-revealed base")
	check(src.contains('"%s: %s" % [str(beat.speaker),str(beat.dialogue)]'),"narrator and dialogue shown in UI")
	check(src.contains("if beat_index<4:"),"Continue also offered after hunter dialogue")
	check(src.contains('location_button(panel,"세계수 기능"'),"world-tree feature remains accessible")
	check(src.contains('location_button(panel,"돌아가기"'),"map return stays accessible")
	check(not src.contains("finish_monster_king_hunt("),"hunt quest completion is not implemented")
	check(not src.contains("start_monster_king_hunt_battle("),"king final battle stays locked")

func branch(side: String, tile: String) -> void:
	var s=fixture(side+"_"+tile,side,tile)
	var at: int=s.world.position
	var weak: bool=side=="ally"
	var mode: String="weakened" if weak else "full"
	check(Hunt.revival_mode(s)==mode,"revival mode derived from actual battle")
	check(Hunt.current_beat(s)==1,"source corrupted-beast scene precedes hunter dialogue")
	check(not s.event_flag_is_set(Hunt.progress_flag(2)),"third dialogue not shown before Continue")
	check(not Hunt.advance(s,at,0),"stale first-scene click cannot skip trace")
	check(not Hunt.advance(s,at+1,1),"wrong tile cannot show revival dialogue")
	check(not Hunt.advance(s,at,2),"future beat index cannot advance")
	check(Hunt.advance(s,at,1),"explicit Continue saves branch-specific third scene")
	check(Hunt.current_beat(s)==2,"third source scene current")
	check(Beats.beat(Hunt.current_beat(s),Hunt.revival_mode(s)).dialogue==Beats.beat(2,mode).dialogue,"saved mode drives exact hunter line")
	check(s.event_flag_is_set(Hunt.progress_flag(1)) and s.event_flag_is_set(Hunt.progress_flag(2)),"both sequential scene receipts present")
	check(s.get_story_event(Hunt.EVENT_ID).status=="seen","hunt event remains unfinished")
	var stable: Dictionary=s.world.snapshot().duplicate(true)
	# The fourth clue is now intentionally reachable from saved beat 2.
	# Previous or future indices must still be rejected without a write.
	for stale in [0,1,3]:
		check(not Hunt.advance(s,at,stale),"stale/future Continue %d refused" % stale)
	check(Hunt.begin(s,at),"reopen saved third scene is idempotent")
	check(s.world.snapshot()==stable,"reopening does not modify original state")
	check(not s.event_flag_is_set(Hunt.COMPLETE_FLAG),"hunter dialogue does not complete hunt event")
	check(s.event_flag_is_set(Hunt.HUNT_ACTIVE_FLAG),"hunt active after third scene")
	check(not s.event_flag_is_set(Hunt.HUNT_COMPLETE_FLAG),"hunt completion locked")
	check(not s.event_flag_is_set(Hunt.SEALED_RUINS_FLAG),"sealed ruins location not known yet")
	check(not s.event_flag_is_set(Hunt.FINAL_BATTLE_FLAG),"final battle still locked")
	check(s.event_flag_is_set(Hunt.WEAKENED_FLAG)==weak,"weakened revival flag unchanged")
	check(s.event_flag_is_set(Hunt.FULL_REVIVAL_FLAG)!=weak,"full revival flag unchanged")
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty(),"dialogue has no battle")
	s.reload_world()
	check(Hunt.current_beat(s)==2,"third scene resumes after reconnect")
	check(Hunt.revival_mode(s)==mode,"revival branch persists after reconnect")
	check(Beats.beat(2,Hunt.revival_mode(s)).dialogue==Beats.beat(2,mode).dialogue,"correct dialogue resumes after reconnect")
	check(s.event_flag_is_set(Hunt.progress_flag(2)),"third scene checkpoint survived reboot")
	s.free()

func rollback_and_guards() -> void:
	var s=fixture("guard","ally","unknown")
	var at: int=s.world.position
	var before: Dictionary=s.world.snapshot().duplicate(true)
	var good: String=s.save_file_path
	s.save_file_path="user://missing_king_hunt_branch_%d/failed.json" % OS.get_process_id()
	check(not Hunt.advance(s,at,1),"storage error rejects third dialogue checkpoint")
	check(s.world.snapshot()==before,"failed write atomically restores world and flags")
	check(Hunt.current_beat(s)==1,"failed save keeps source second scene")
	check(not s.event_flag_is_set(Hunt.progress_flag(2)),"failed save grants no third scene")
	s.save_file_path=good
	s.world.pending_move={"test":true}
	check(not Hunt.advance(s,at,1),"movement blocks third scene")
	s.world.restore(before)
	s.world.pending_reward={"test":true}
	check(not Hunt.advance(s,at,1),"pending reward blocks third scene")
	s.world.restore(before)
	s.world.active_encounter={"id":"test"}
	check(not Hunt.advance(s,at,1),"active combat blocks third scene")
	s.world.restore(before)
	s.world.event_flags[Hunt.FULL_REVIVAL_FLAG]=true
	check(not Hunt.advance(s,at,1),"contradictory revival flags block third scene")
	s.world.restore(before)
	s.world.event_flags[Hunt.WEAKENED_FLAG]=false
	check(not Hunt.advance(s,at,1),"missing revival mode blocks third scene")
	s.world.restore(before)
	s.world.event_flags[Hunt.HUNT_ACTIVE_FLAG]=false
	check(not Hunt.advance(s,at,1),"inactive hunt quest blocks third scene")
	s.world.restore(before)
	s.world.event_flags[Hunt.progress_flag(2)]=true
	s.world.event_flags[Hunt.progress_flag(1)]=false
	check(not Hunt.can_enter(s,at),"forged third scene without second checkpoint blocked")
	s.world.restore(before)
	check(Hunt.advance(s,at,1),"valid retry after recovery commits third scene")
	s.reload_world()
	check(Hunt.current_beat(s)==2,"recovered third scene persists")
	s.free()

func _run() -> void:
	source_contract()
	branch("ally","unknown")
	branch("enemy","event")
	rollback_and_guards()
	for path in paths: cleanup(path)
	print("MONSTER_KING_HUNT_REVIVAL_DIALOGUE_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
