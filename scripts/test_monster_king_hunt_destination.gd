extends SceneTree
## P1-05K-4: source-canonical fourth destination clue. Real portal outcomes,
## sequential saved hunter dialogue, restart, stale click and atomic rollback.
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

func check(ok: bool, message: String) -> void:
	if ok:
		passed+=1
		print("PASS king-hunt-destination: ",message)
	else:
		failed+=1
		printerr("FAIL king-hunt-destination: ",message)

func cleanup(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func fixture(tag: String, side: String, tile: String):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://king_hunt_destination_%d_%s.json" % [OS.get_process_id(),tag]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	# Legacy narrative coverage runs at unlocked contamination; gate edges have their own test.
	s.world.contamination = 100
	s.world.reveal_boss_at_threshold()
	s.world.story_events[Rumor.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	s.world.event_flags[Rumor.SEEN_FLAG]=true
	s.world.event_flags[Rumor.COMPLETE_FLAG]=true
	s.world.event_flags[Rumor.TRACKING_FLAG]=true
	s.world.position=s.world.tiles.find("altar")
	check(s.save_world(),"prior rumor receipt saved")
	var at: int=s.world.position
	check(Altar.begin(s,at),"altar arrival")
	check(Altar.advance(s,at,0),"altar opening")
	check(Altar.advance(s,at,1),"altar ritual")
	check(Altar.choose(s,at,2,"pass"),"altar passage")
	check(Altar.finish(s,at),"portal quest unlocked")
	s.world.position=s.world.tiles.find("forest")
	check(s.world.position>=0 and s.save_world(),"portal landing saved")
	at=s.world.position
	check(Portal.begin(s,at),"portal started")
	for i in [0,1,2,3]:
		check(Portal.advance(s,at,i),"portal beat %d" % i)
	check(Portal.choose_intervention(s,at,4),"intervention chosen")
	check(s.start_story_encounter(Portal.EVENT_ID,at,[s.world.roster[0].id]),"portal battle started")
	check(s.finish_encounter(BattleResult.new(side)),"real portal result stored")
	check(s.acknowledge_story_battle_result(Portal.EVENT_ID),"battle result acknowledged")
	check(Portal.finish(s,at),"revival flags and hunt unlocked")
	s.world.position=s.world.tiles.find(tile)
	check(s.world.position>=0 and s.save_world(),"hunt landing saved")
	at=s.world.position
	check(Hunt.begin(s,at),"first world-tree scene committed")
	check(Hunt.advance(s,at,0),"second corrupted trace committed")
	check(Hunt.advance(s,at,1),"third revival dialogue committed")
	return s

func source_contract() -> void:
	check(Beats.count()==5,"four source beats; location confirmation fifth locked")
	check(Beats.beat(0)==Hunt.FIRST_BEAT,"original arrival unchanged")
	check(Beats.beat(1).id=="trace","corrupted trace unchanged")
	check(Beats.beat(2,"weakened").id=="revival","existing weak revival line unchanged")
	check(Beats.beat(2,"full").id=="revival","existing full revival line unchanged")
	var fourth: Dictionary=Beats.beat(3)
	check(fourth.id=="destination","canonical fourth beat id")
	check(fourth.effect=="오염된 흔적이 숲 너머의 오래된 봉인 폐허를 향해 이어진다.","exact source narration")
	check(fourth.dialogue=="왕은 그 폐허로 향했어. 봉인이 남아 있던 곳이지.","exact hunter clue")
	check(fourth.speaker=="마물 사냥꾼" and fourth.visual=="portrait","source speaker and portrait")
	check(Beats.beat(3,"weakened")==Beats.beat(3,"full"),"same clue for both revival modes")
	check(Beats.beat(4).id=="located" and Beats.beat(5).is_empty() and Beats.beat(-1).is_empty(),"no fifth completion or invalid beat")
	check(Beats.visual_art(str(fourth.visual))==Beats.PORTRAIT_ART,"original hunter portrait reused")
	check(ResourceLoader.exists(Beats.PORTRAIT_ART),"portrait resource present")
	fourth.effect="changed"
	check(Beats.beat(3).effect.begins_with("오염된 흔적"),"source descriptor immutable")
	check(Hunt.progress_flag(3)=="event:monster_king_hunt_trace_01:beat:3","unique fourth beat receipt")
	check(Hunt.progress_flag(4).is_empty(),"location completion not checkpointed prematurely")
	var src: String=FileAccess.get_file_as_string("res://map.gd")
	check(src.contains("if beat_index<4:"),"third dialogue explicitly continues to fourth clue")
	check(src.contains("MonsterKingHuntBeats.beat(beat_index,MonsterKingHuntEntry.revival_mode(session))"),"saved beat and revival mode drive UI")
	check(src.contains("InkSceneReveal.play(scene_art)"),"original ink reveal preserved")
	check(src.contains('location_button(panel,"세계수 기능"'),"world tree function retained")
	check(src.contains('location_button(panel,"돌아가기"'),"map back button retained")
	check(not src.contains("finish_monster_king_hunt("),"future quest completion remains locked")
	check(not src.contains("start_monster_king_hunt_battle("),"king battle remains locked")

func branch(side: String, tile: String) -> void:
	var s=fixture(side+"_"+tile,side,tile)
	var at: int=s.world.position
	var mode: String="weakened" if side=="ally" else "full"
	check(Hunt.revival_mode(s)==mode,"branch from genuine portal combat")
	check(Hunt.current_beat(s)==2,"third dialogue is visible before clue")
	check(not s.event_flag_is_set(Hunt.progress_flag(3)),"destination receipt initially absent")
	check(not Hunt.advance(s,at,1),"stale second-scene click blocked")
	check(not Hunt.advance(s,at+1,2),"off-tile advance blocked")
	check(not Hunt.advance(s,at,3),"cannot skip ahead to fifth scene")
	check(Hunt.advance(s,at,2),"explicit Continue commits fourth clue")
	check(Hunt.current_beat(s)==3,"fourth clue is displayed from saved checkpoint")
	check(Beats.beat(Hunt.current_beat(s),Hunt.revival_mode(s)).dialogue==Beats.beat(3).dialogue,"correct hunter clue after real branch")
	check(s.event_flag_is_set(Hunt.progress_flag(3)),"fourth receipt saved")
	check(s.get_story_event(Hunt.EVENT_ID).status=="seen","investigation not yet completed")
	check(s.event_flag_is_set(Hunt.HUNT_ACTIVE_FLAG),"hunt remains active")
	check(not s.event_flag_is_set(Hunt.COMPLETE_FLAG),"event remains open")
	check(not s.event_flag_is_set(Hunt.HUNT_COMPLETE_FLAG),"quest completion deferred")
	check(not s.event_flag_is_set(Hunt.SEALED_RUINS_FLAG),"ruins location not yet confirmed")
	check(not s.event_flag_is_set(Hunt.FINAL_BATTLE_FLAG),"final battle remains locked")
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty(),"no new combat")
	check(s.world.pending_reward.is_empty(),"no reward granted")
	var saved: Dictionary=s.world.snapshot().duplicate(true)
	for stale in [0,1,2,3]:
		check(not Hunt.advance(s,at,stale),"repeat/future Continue blocked %d" % stale)
	check(Hunt.begin(s,at),"saved fourth scene can be reopened")
	check(s.world.snapshot()==saved,"reopen is idempotent")
	s.reload_world()
	check(Hunt.current_beat(s)==3,"reconnect resumes fourth clue")
	check(s.event_flag_is_set(Hunt.progress_flag(3)),"reconnect preserves receipt")
	check(Hunt.revival_mode(s)==mode,"revival result unchanged after reconnect")
	s.free()

func failed_save_and_guards() -> void:
	var s=fixture("guards","ally","unknown")
	var at: int=s.world.position
	var before: Dictionary=s.world.snapshot().duplicate(true)
	var good: String=s.save_file_path
	s.save_file_path="user://missing_king_destination_%d/failed.json" % OS.get_process_id()
	check(not Hunt.advance(s,at,2),"storage failure blocks fourth clue")
	check(s.world.snapshot()==before,"failed write rolls back everything")
	check(Hunt.current_beat(s)==2,"failed write retains third dialogue")
	s.save_file_path=good
	s.world.pending_move={"test":true}
	check(not Hunt.advance(s,at,2),"pending movement blocks Continue")
	s.world.restore(before)
	s.world.pending_reward={"test":true}
	check(not Hunt.advance(s,at,2),"pending reward blocks Continue")
	s.world.restore(before)
	s.world.active_encounter={"id":"test"}
	check(not Hunt.advance(s,at,2),"active combat blocks Continue")
	s.world.restore(before)
	s.world.event_flags[Hunt.FULL_REVIVAL_FLAG]=true
	check(not Hunt.advance(s,at,2),"contradictory revival modes blocked")
	s.world.restore(before)
	s.world.event_flags[Hunt.progress_flag(3)]=true
	s.world.event_flags[Hunt.progress_flag(2)]=false
	check(not Hunt.can_enter(s,at),"forged fourth checkpoint without third rejected")
	s.world.restore(before)
	s.world.event_flags[Hunt.SEALED_RUINS_FLAG]=true
	check(not Hunt.advance(s,at,2),"future location receipt cannot be set early")
	s.world.restore(before)
	check(Hunt.advance(s,at,2),"valid retry commits fourth scene")
	s.reload_world()
	check(Hunt.current_beat(s)==3,"recovered clue persists")
	s.free()

func _run() -> void:
	source_contract()
	branch("ally","unknown")
	branch("enemy","event")
	failed_save_and_guards()
	for path in paths: cleanup(path)
	print("MONSTER_KING_HUNT_DESTINATION_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
