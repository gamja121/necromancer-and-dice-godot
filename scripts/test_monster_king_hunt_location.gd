extends SceneTree
## P1-05K-5: source fifth located beat and atomic quest completion. Real portal outcomes,
## real revival outcomes, completion rollback, restart and final acknowledgment.
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
		print("PASS king-hunt-location: ",message)
	else:
		failed+=1
		printerr("FAIL king-hunt-location: ",message)

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
	check(Beats.count()==5,"original five source scenes")
	var located: Dictionary=Beats.beat(4)
	check(located.id=="located","original fifth beat ID")
	check(located.effect=="숲속 봉인 폐허의 위치를 파악했다. 추적은 끝났지만 왕과의 싸움은 아직 시작되지 않았다.","source narrator text")
	check(located.dialogue=="[마물의 왕이 향한 봉인 폐허의 위치를 알아냈습니다.]","source system notice")
	check(located.speaker=="시스템" and located.visual=="scene" and located.locationKnown==true,"source speaker, scene and location marker")
	check(Beats.beat(5).is_empty(),"no sixth beat")
	check(ResourceLoader.exists(Beats.SCENE_ART),"original scene artwork present")
	located.effect="fake"
	check(Beats.beat(4).effect.begins_with("숲속 봉인"),"canonical beat immutable")
	var src: String=FileAccess.get_file_as_string("res://map.gd")
	check(src.contains("if beat_index<4:"),"fourth clue continues to fifth")
	check(src.contains("MonsterKingHuntEntry.finish(session,index) if shown_beat==3"),"last Continue calls atomic finish")
	check(src.contains("MonsterKingHuntEntry.can_resume_completion(session,index)"),"reconnect can restore saved fifth")
	check(src.contains('location_button(panel,"마치기"'),"saved final scene requires explicit acknowledgment")
	check(src.contains("MonsterKingHuntEntry.acknowledge_completion(session,index)"),"final ack persisted")
	check(src.contains('location_button(panel,"세계수 기능"'),"world tree features kept")
	check(not src.contains("start_monster_king_hunt_battle("),"no phantom final boss encounter")

func branch(side: String, tile: String) -> void:
	var s=fixture("location_"+side+"_"+tile,side,tile)
	var at: int=s.world.position
	var weak: bool=side=="ally"
	check(Hunt.advance(s,at,2),"fourth destination clue saved")
	var before: Dictionary=s.world.snapshot().duplicate(true)
	check(Hunt.current_beat(s)==3 and not Hunt.completed(s),"clue is not completion")
	check(not Hunt.finish(s,at+1),"wrong-tile completion rejected")
	check(not Hunt.advance(s,at,3),"generic advance cannot complete quest")
	check(not Hunt.acknowledge_completion(s,at),"pre-completion ack rejected")
	check(s.world.snapshot()==before,"rejected operations do not change save")
	check(Hunt.finish(s,at),"explicit final Continue commits completion")
	check(Hunt.completed(s),"saved completion state consistent")
	check(Hunt.current_beat(s)==4 and Hunt.can_resume_completion(s,at),"fifth confirmation screen visible")
	check(not Hunt.can_enter(s,at),"cannot re-open completed story")
	check(s.get_story_event(Hunt.EVENT_ID).status=="complete","story status completed")
	check(s.get_story_event(Hunt.EVENT_ID).choice=="" and s.get_story_event(Hunt.EVENT_ID).battle_result=="","no fake choices or boss result")
	check(s.event_flag_is_set(Hunt.COMPLETE_FLAG) and s.event_flag_is_set(Hunt.HUNT_COMPLETE_FLAG),"hunt and event completed together")
	check(not s.event_flag_is_set(Hunt.HUNT_ACTIVE_FLAG),"prior hunt deactivated")
	check(s.event_flag_is_set(Hunt.SEALED_RUINS_FLAG) and s.event_flag_is_set(Hunt.FINAL_BATTLE_FLAG),"ruins and final quest flags unlocked together")
	check(not s.event_flag_is_set(Hunt.FINAL_SCENE_ACK_FLAG),"final screen not silently acknowledged")
	check(s.event_flag_is_set(Hunt.WEAKENED_FLAG)==weak and s.event_flag_is_set(Hunt.FULL_REVIVAL_FLAG)!=weak,"actual portal branch unaffected")
	check(Portal.completed(s),"earlier portal result preserved")
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty(),"king combat not started")
	check(s.world.pending_reward.is_empty(),"no unearned reward")
	var stable: Dictionary=s.world.snapshot().duplicate(true)
	check(not Hunt.finish(s,at),"repeat final Continue rejected")
	check(s.world.snapshot()==stable,"repeat Continue is no-op")
	s.reload_world()
	check(Hunt.completed(s) and Hunt.current_beat(s)==4,"reconnect restores fifth confirmation")
	check(Hunt.acknowledge_completion(s,at),"manual finish persists acknowledgment")
	check(not Hunt.can_resume_completion(s,at) and Hunt.current_beat(s)==-1,"ack disables recurring final overlay")
	stable=s.world.snapshot().duplicate(true)
	check(Hunt.acknowledge_completion(s,at),"repeated ack is idempotent")
	check(s.world.snapshot()==stable,"repeated ack does not write")
	s.reload_world()
	check(Hunt.completed(s) and not Hunt.can_resume_completion(s,at),"quest and ack survive reload")
	s.free()

func guards() -> void:
	var s=fixture("location_guards","ally","unknown")
	var at: int=s.world.position
	check(Hunt.advance(s,at,2),"destination clue before guards")
	var before: Dictionary=s.world.snapshot().duplicate(true)
	var good: String=s.save_file_path
	s.save_file_path="user://missing_king_complete_%d/fail.json" % OS.get_process_id()
	check(not Hunt.finish(s,at),"storage failure blocks completion")
	check(s.world.snapshot()==before,"failed completion rolls back all flags and story")
	check(not s.event_flag_is_set(Hunt.FINAL_BATTLE_FLAG),"no partial final quest")
	s.save_file_path=good
	s.world.pending_move={"test":true}
	check(not Hunt.finish(s,at),"pending movement blocks")
	s.world.restore(before)
	s.world.pending_reward={"test":true}
	check(not Hunt.finish(s,at),"pending reward blocks")
	s.world.restore(before)
	s.world.active_encounter={"id":"test"}
	check(not Hunt.finish(s,at),"active battle blocks")
	s.world.restore(before)
	s.world.event_flags[Hunt.FULL_REVIVAL_FLAG]=true
	check(not Hunt.finish(s,at),"contradictory revival flags block")
	s.world.restore(before)
	s.world.event_flags[Hunt.progress_flag(3)]=false
	check(not Hunt.finish(s,at),"missing fourth clue prevents finish")
	s.world.restore(before)
	s.world.story_events[Hunt.EVENT_ID].choice="fake"
	check(not Hunt.finish(s,at),"forged story choice rejected")
	s.world.restore(before)
	check(Hunt.finish(s,at),"valid retry completes hunt")
	var done: Dictionary=s.world.snapshot().duplicate(true)
	s.save_file_path="user://missing_king_ack_%d/fail.json" % OS.get_process_id()
	check(not Hunt.acknowledge_completion(s,at),"acknowledgment storage failure blocked")
	check(s.world.snapshot()==done and Hunt.can_resume_completion(s,at),"failed ack preserves fifth scene")
	s.save_file_path=good
	s.world.event_flags[Hunt.FINAL_BATTLE_FLAG]=false
	check(not Hunt.completed(s) and not Hunt.acknowledge_completion(s,at),"inconsistent completed flags rejected")
	s.world.restore(done)
	check(Hunt.acknowledge_completion(s,at),"final acknowledgment successful")
	s.free()

func _run() -> void:
	source_contract()
	branch("ally","unknown")
	branch("enemy","event")
	guards()
	for path in paths: cleanup(path)
	print("MONSTER_KING_HUNT_LOCATION_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
