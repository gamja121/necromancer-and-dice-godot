extends SceneTree
## P1-05J-6: canonical weakened/full revival, battle-return confirmation,
## exact quest receipts, interrupted saves and no premature future story.
const SessionScript=preload("res://systems/run_session.gd")
const Rumor=preload("res://systems/cultist_rumor_entry.gd")
const Altar=preload("res://systems/cultist_altar_entry.gd")
const Portal=preload("res://systems/ritual_portal_entry.gd")
const Beats=preload("res://systems/ritual_portal_beats.gd")

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

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	if ok:
		passed+=1
		print("PASS ritual-portal-revival: ",detail)
	else:
		failed+=1
		printerr("FAIL ritual-portal-revival: ",detail)

func cleanup(path: String) -> void:
	for ext in ["",".tmp"]:
		if FileAccess.file_exists(path+ext):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+ext))

func fixture(tag: String,tile: String="forest"):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://ritual_portal_revival_%d_%s.json" % [OS.get_process_id(),tag]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	s.world.story_events[Rumor.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	s.world.event_flags[Rumor.SEEN_FLAG]=true
	s.world.event_flags[Rumor.COMPLETE_FLAG]=true
	s.world.event_flags[Rumor.TRACKING_FLAG]=true
	s.world.position=s.world.tiles.find("altar")
	check(s.save_world(),"prior rumor chain saved")
	var at: int=s.world.position
	check(Altar.begin(s,at),"altar arrival saved")
	check(Altar.advance(s,at,0),"altar ritual saved")
	check(Altar.advance(s,at,1),"altar choice saved")
	check(Altar.choose(s,at,2,"pass"),"altar pass saved")
	check(Altar.finish(s,at),"prior tracking quest confirmed")
	s.world.position=s.world.tiles.find(tile)
	check(s.world.position>=0,"eligible forest or event tile exists")
	check(s.save_world(),"portal landing saved")
	at=s.world.position
	check(Portal.begin(s,at),"portal discovery saved")
	for i in range(4): check(Portal.advance(s,at,i),"portal stage %d saved" % (i+1))
	check(Portal.choose_intervention(s,at,4),"canonical fifth intervention confirmed")
	return s

func source_contract() -> void:
	check(Beats.count()==5,"only original five ritual scenes exist")
	var won: Dictionary=Beats.aftermath("won")
	var lost: Dictionary=Beats.aftermath("lost")
	check(won.effect=="의식의 핵심을 파괴했다. 하지만 이미 넘어온 왕의 존재까지 되돌리지는 못했다. 불완전한 육체로 현세에 떨어진 마물의 왕이 어둠 속으로 사라진다.","original weak-revival text exact")
	check(won.dialogue=="[불완전하게 부활한 마물의 왕을 추적합니다.]","original weak-revival system quest text exact")
	check(lost.effect=="저지선이 무너지자 전이문이 완전히 열린다. 마물의 왕은 온전한 힘을 되찾은 채 현세에 모습을 드러내고, 곧 어둠 속으로 사라진다.","original full-revival text exact")
	check(lost.dialogue=="[완전히 부활한 마물의 왕을 추적합니다.]","original full-revival system quest text exact")
	check(won.speaker=="시스템" and lost.speaker=="시스템","source system narrator preserved")
	check(won.visual=="omen" and lost.visual=="omen","source existing omen art reused")
	check(Beats.aftermath("pending").is_empty(),"invalid/undecided result has no epilogue")
	check(Beats.beat(5).is_empty(),"after-battle outcome is not a sixth beat")
	var changed: Dictionary=Beats.aftermath("won")
	changed.effect="tampered"
	check(Beats.aftermath("won").effect.begins_with("의식의 핵심"),"result read cannot corrupt canonical source")
	check(Portal.WEAKENED_FLAG=="story:monster_king:revival_weakened","source weakened flag correct")
	check(Portal.FULL_REVIVAL_FLAG=="story:monster_king:revival_complete","source full flag correct")
	check(Portal.HUNT_FLAG=="quest:monster_king_hunt:active","source subsequent hunt flag correct")
	check(Portal.TRACKING_COMPLETE_FLAG=="quest:ritual_site_tracking:complete","source old quest completion flag correct")
	var src: String=FileAccess.get_file_as_string("res://map.gd")
	check(src.contains("func show_ritual_portal_aftermath(index: int) -> void:"),"original outcome view exists")
	check(src.contains("RitualPortalBeats.aftermath(result)"),"view uses exact source result")
	check(src.contains("RitualPortalBeats.OMEN_ART"),"result uses existing omen overlay")
	check(src.contains("func finish_ritual_portal(index: int) -> void:"),"explicit finish action exists")
	check(src.contains("RitualPortalEntry.finish(session,index)"),"UI sends action to atomic handoff")
	check(src.contains('location_button(panel,"마치기"'),"epilogue requires explicit Finish")
	check(src.contains('부활 확인" if event_id==RitualPortalEntry.EVENT_ID'),"battle result must first be acknowledged")
	check(src.contains("RitualPortalEntry.aftermath_ready(session,index)"),"resume/return flow guarded by real result")
	check(src.contains("show_ritual_portal_aftermath(index)"),"acknowledgement opens the canonical epilogue")
	check(src.contains("if world.tiles[index]==\"forest\":"),"forest tile retains exploration option")

func verify_completed(s,won: bool) -> void:
	var at: int=s.world.position
	check(Portal.aftermath_ready(s,at),"acknowledged result ready for epilogue")
	check(s.get_story_event(Portal.EVENT_ID).status=="active","display alone does not finish event")
	check(s.event_flag_is_set(Portal.TRACKING_FLAG),"old tracking quest stays active before Finish")
	check(not s.event_flag_is_set(Portal.HUNT_FLAG),"hunt is still locked before Finish")
	check(not s.event_flag_is_set(Portal.REVIVED_FLAG),"king revival not precommitted")
	check(not Portal.completed(s),"portal not complete before Finish")
	check(Portal.finish(s,at),"explicit Finish atomically confirms revival and hunt")
	check(Portal.completed(s),"finished story has internally consistent outcome receipts")
	var state: Dictionary=s.get_story_event(Portal.EVENT_ID)
	check(state.status=="complete" and state.choice=="intervene","story status and choice finalized")
	check(state.battle_result==("won" if won else "lost"),"original battle result preserved")
	for key in [Portal.SEEN_FLAG,Portal.INTERVENE_CHOICE_FLAG,Portal.COMPLETE_FLAG,Portal.PORTAL_FOUND_FLAG,Portal.SITE_LOCATION_FLAG,Portal.TRACKING_COMPLETE_FLAG,Portal.REVIVED_FLAG,Portal.HUNT_FLAG]:
		check(s.event_flag_is_set(key),"canonical completion flag: "+key)
	check(not s.event_flag_is_set(Portal.TRACKING_FLAG),"previous ritual tracking deactivated")
	check(not s.event_flag_is_set(Portal.INTERVENTION_FLAG),"intervention quest no longer active")
	check(s.event_flag_is_set(Portal.BATTLE_WON_FLAG)==won,"real battle win receipt retained")
	check(s.event_flag_is_set(Portal.BATTLE_LOST_FLAG)!=won,"real battle loss receipt retained")
	check(s.event_flag_is_set(Portal.WEAKENED_FLAG)==won,"weakened revival only on victory")
	check(s.event_flag_is_set(Portal.FULL_REVIVAL_FLAG)!=won,"full revival only on defeat")
	check(not s.event_flag_is_set(Portal.HUNT_EVENT_COMPLETE_FLAG),"later hunt event not completed prematurely")
	check(not s.event_flag_is_set(Portal.HUNT_QUEST_COMPLETE_FLAG),"later hunt quest not completed prematurely")
	check(not s.event_flag_is_set(Portal.SEALED_RUINS_KNOWN_FLAG),"sealed ruin location still unknown")
	check(not s.event_flag_is_set(Portal.FINAL_BATTLE_FLAG),"final king battle remains locked")
	check(not Portal.can_enter(s,at),"completed portal cannot replay its battle")
	check(not Portal.aftermath_ready(s,at),"finished result cannot be consumed twice")
	check(not s.start_story_encounter(Portal.EVENT_ID,at,[s.world.roster[0].id]),"completed intervention never restarts fight")
	var after: Dictionary=s.world.snapshot().duplicate(true)
	check(Portal.finish(s,at),"duplicate final Finish idempotent")
	check(s.world.snapshot()==after,"duplicate completion leaves entire world unchanged")
	s.reload_world()
	check(Portal.completed(s),"completed revival persists through game restart")
	check(s.event_flag_is_set(Portal.HUNT_FLAG),"new king hunt active after reload")
	check(not s.event_flag_is_set(Portal.TRACKING_FLAG),"old ritual site quest stays inactive after reload")
	check(s.event_flag_is_set(Portal.WEAKENED_FLAG)==won,"revival mode survives restart")

func battle_branch(winner: String, tile: String) -> void:
	var s=fixture(winner+"_"+tile,tile)
	var at: int=s.world.position
	var unit_id: String=str(s.world.roster[0].id)
	check(not Portal.aftermath_ready(s,at),"intervention intent alone cannot show a revival")
	check(not Portal.finish(s,at),"no completion before real combat")
	check(s.start_story_encounter(Portal.EVENT_ID,at,[unit_id]),"real portal battle starts from selected owned unit")
	check(not Portal.finish(s,at),"cannot complete while battle active")
	check(s.finish_encounter(BattleResult.new(winner)),"canonical portal battle outcome saved")
	var result: String="won" if winner=="ally" else "lost"
	check(s.get_story_event(Portal.EVENT_ID).battle_result==result,"outcome recorded without completing story")
	check(s.story_battle_result_pending(Portal.EVENT_ID),"unacknowledged battle result pending")
	check(not Portal.aftermath_ready(s,at),"result cannot bypass acknowledgement")
	check(not Portal.finish(s,at),"cannot complete without acknowledging battle")
	s.reload_world()
	check(s.story_battle_result_pending(Portal.EVENT_ID),"unacknowledged result survives reload")
	check(s.acknowledge_story_battle_result(Portal.EVENT_ID),"player explicitly acknowledges battle outcome")
	check(not s.story_battle_result_pending(Portal.EVENT_ID),"battle result receipt consumed once")
	check(Portal.aftermath_ready(s,at),"epilogue now ready")
	s.reload_world()
	check(Portal.aftermath_ready(s,at),"crash before Finish restores epilogue")
	verify_completed(s,winner=="ally")
	s.free()

func fail_save() -> void:
	for winner in ["ally","enemy"]:
		var s=fixture("failed_"+winner,"forest")
		var at: int=s.world.position
		check(s.start_story_encounter(Portal.EVENT_ID,at,[s.world.roster[0].id]),"rollback fixture begins combat")
		check(s.finish_encounter(BattleResult.new(winner)),"rollback fixture saves combat")
		check(s.acknowledge_story_battle_result(Portal.EVENT_ID),"rollback fixture acknowledges result")
		var before: Dictionary=s.world.snapshot().duplicate(true)
		var good: String=s.save_file_path
		s.save_file_path="user://ritual_revival_missing_%d/failed.json" % OS.get_process_id()
		check(not Portal.finish(s,at),"failed save prevents entire revival handoff")
		check(s.world.snapshot()==before,"failed save atomically restores story, quest and revival flags")
		check(Portal.aftermath_ready(s,at),"epilogue still available after failed Finish")
		check(not s.event_flag_is_set(Portal.REVIVED_FLAG),"failed write did not revive king")
		check(not s.event_flag_is_set(Portal.HUNT_FLAG),"failed write did not unlock king hunt")
		s.save_file_path=good
		check(Portal.finish(s,at),"storage recovery can finish the exact outcome")
		s.free()

func guards() -> void:
	var s=fixture("guards","forest")
	var at: int=s.world.position
	check(s.start_story_encounter(Portal.EVENT_ID,at,[s.world.roster[0].id]),"guard fixture starts real battle")
	check(s.finish_encounter(BattleResult.new("ally")),"guard fixture saves victory")
	check(s.acknowledge_story_battle_result(Portal.EVENT_ID),"guard fixture acknowledges battle")
	var baseline: Dictionary=s.world.snapshot().duplicate(true)
	check(not Portal.finish(s,at+1),"wrong tile cannot confirm revival")
	s.world.pending_move={"test":true}
	check(not Portal.finish(s,at),"pending move blocks completion")
	s.world.restore(baseline)
	s.world.pending_reward={"kind":"test"}
	check(not Portal.finish(s,at),"pending reward blocks completion")
	s.world.restore(baseline)
	s.world.active_encounter={"event_id":"test"}
	check(not Portal.finish(s,at),"active encounter blocks completion")
	s.world.restore(baseline)
	s.world.event_flags[Portal.TRACKING_FLAG]=false
	check(not Portal.finish(s,at),"removed prerequisite tracking quest blocks handoff")
	s.world.restore(baseline)
	s.world.event_flags[Portal.REVIVED_FLAG]=true
	check(not Portal.finish(s,at),"pre-forged revival receipt blocks handoff")
	s.world.restore(baseline)
	s.world.event_flags[Portal.WEAKENED_FLAG]=true
	check(not Portal.finish(s,at),"pre-forged weakened mode blocks handoff")
	s.world.restore(baseline)
	s.world.story_events[Portal.EVENT_ID].choice=""
	check(not Portal.finish(s,at),"missing deliberate intervention cannot complete")
	s.world.restore(baseline)
	s.world.event_flags[Portal.BATTLE_WON_FLAG]=false
	check(not Portal.finish(s,at),"mismatched winner receipt cannot complete")
	s.world.restore(baseline)
	check(Portal.aftermath_ready(s,at),"restored genuine save stays eligible")
	s.free()

func _run() -> void:
	source_contract()
	battle_branch("ally","forest")
	battle_branch("enemy","event")
	fail_save()
	guards()
	for path in paths: cleanup(path)
	print("RITUAL_PORTAL_REVIVAL_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
