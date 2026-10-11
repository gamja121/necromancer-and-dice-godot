extends SceneTree
## P1-05I-5: canonical pass/fight aftermath and atomic tracking-quest handoff.
const SessionScript=preload("res://systems/run_session.gd")
const Rumor=preload("res://systems/cultist_rumor_entry.gd")
const Altar=preload("res://systems/cultist_altar_entry.gd")
const Beats=preload("res://systems/cultist_altar_beats.gd")
const Registry=preload("res://systems/story_battle_registry.gd")

class BattleResult:
	extends RefCounted
	var outcome: String
	var units: Array=[]
	func _init(result: String) -> void: outcome=result
	func winner() -> String: return outcome
	func find_id(_id: String) -> Dictionary: return {}

var passed: int=0
var failed: int=0
var files: Array[String]=[]

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, what: String) -> void:
	if ok:
		passed+=1
		print("PASS cultist-altar-followup: ",what)
	else:
		failed+=1
		printerr("FAIL cultist-altar-followup: ",what)

func cleanup(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func fixture(tag: String,decision: String, on_event_tile: bool=false):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://cultist_altar_followup_%d_%s.json" % [OS.get_process_id(),tag]
	files.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	s.world.story_events[Rumor.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	s.world.event_flags[Rumor.SEEN_FLAG]=true
	s.world.event_flags[Rumor.COMPLETE_FLAG]=true
	s.world.event_flags[Rumor.TRACKING_FLAG]=true
	s.world.position=s.world.tiles.find("event" if on_event_tile else "altar")
	check(s.save_world(),"rumor chain committed")
	var at: int=s.world.position
	check(Altar.begin(s,at),"altar introduction committed")
	check(Altar.advance(s,at,0),"ritual reveal committed")
	check(Altar.advance(s,at,1),"choice scene committed")
	check(Altar.choose(s,at,2,decision),"original choice committed")
	return s

func verify_source() -> void:
	check(Beats.PASS_EFFECT=="지금은 충돌을 피한다. 하지만 제단에서 보았던 의식과 문양은 분명히 기억해 둔다.","original pass aftermath")
	check(Beats.FIGHT_WON_EFFECT=="소환된 마물들을 쓰러뜨렸다. 흐트러진 의식 도구 사이에서 다음 의식 장소를 가리키는 흔적을 발견했다.","original win aftermath")
	check(Beats.FIGHT_LOST_EFFECT=="소환된 마물들에게 밀려 물러났지만, 광신도들이 준비하던 부활 의식의 흔적은 확인했다.","original loss aftermath")
	check(Beats.FOLLOWUP_DIALOGUE=="[마물의 왕 부활 의식의 흔적을 추적합니다.]","original system follow-up notice")
	check(Beats.FOLLOWUP_SPEAKER=="시스템","canonical system speaker")
	check(Beats.followup_effect("pass","")==Beats.PASS_EFFECT,"pass narration routed")
	check(Beats.followup_effect("fight","won")==Beats.FIGHT_WON_EFFECT,"victory narration routed")
	check(Beats.followup_effect("fight","lost")==Beats.FIGHT_LOST_EFFECT,"defeat narration routed")
	check(Beats.followup_effect("fight","").is_empty(),"fight intent alone cannot create afterbattle narration")
	check(Beats.followup_effect("pass","won").is_empty(),"fake pass battle not presented")
	var map_src: String=FileAccess.get_file_as_string("res://map.gd")
	check(map_src.contains("func show_cultist_altar_followup(index: int) -> void:"),"original follow-up view exists")
	check(map_src.contains("CultistAltarBeats.followup_effect("),"narration comes only from source table")
	check(map_src.contains("CultistAltarBeats.FOLLOWUP_DIALOGUE"),"system notice rendered")
	check(map_src.contains("CultistAltarEntry.followup_ready(session,index)"),"saved state gates aftermath")
	check(map_src.contains('location_button(panel,"마치기"'),"explicit completion button present")
	check(map_src.contains("CultistAltarEntry.finish(session,index)"),"finish button commits tracking atomically")
	check(map_src.contains('"흔적 확인" if event_id==CultistAltarEntry.EVENT_ID else "맵으로"'),"battle result acknowledgement named")
	check(map_src.contains("show_cultist_altar_followup(index)"),"acknowledgement transitions to story aftermath")
	check(map_src.contains("show_location(index)"),"dedicated altar actions preserved")
	check(map_src.contains("show_story_battle_deck(event_id,index)"),"loss retry remains in generic deck selection")
	check(not map_src.contains("markRitualPortalEventComplete("),"next ritual resolution not enabled")

func verify_handoff(s,expected: String) -> void:
	var at: int=s.world.position
	check(Altar.followup_ready(s,at),"saved aftermath is ready")
	check(s.get_story_event(Altar.EVENT_ID).status=="active","event not completed on display")
	check(s.event_flag_is_set(Altar.TRACKING_FLAG),"old quest stays active until Finish")
	check(not s.event_flag_is_set(Altar.RITUAL_TRACKING_FLAG),"new quest is locked until Finish")
	check(not s.event_flag_is_set(Altar.RITUAL_CONFIRMED_FLAG),"ritual not confirmed before Finish")
	check(Altar.finish(s,at),"explicit Finish commits handoff")
	check(Altar.completed(s),"all canonical completion receipts consistent")
	var state: Dictionary=s.get_story_event(Altar.EVENT_ID)
	check(state.status=="complete" and state.choice==expected,"choice preserved on completed event")
	check(s.event_flag_is_set(Altar.COMPLETE_FLAG),"altar event completed")
	check(s.event_flag_is_set(Altar.SEEN_FLAG),"original discovery remains seen")
	check(s.event_flag_is_set(Altar.RITUAL_CONFIRMED_FLAG),"ritual evidence confirmed")
	check(not s.event_flag_is_set(Altar.TRACKING_FLAG),"old cultist tracking quest deactivated")
	check(s.event_flag_is_set(Altar.RITUAL_TRACKING_FLAG),"ritual-site tracking quest activated")
	check(not s.event_flag_is_set("story:monster_king:revived"),"actual resurrection not triggered")
	check(not s.event_flag_is_set("event:ritual_portal_trace_01:complete"),"portal story not skipped")
	check(not s.event_flag_is_set("quest:monster_king_hunt:active"),"king hunt not preemptively activated")
	check(not Altar.can_enter(s,at),"completed altar cannot silently retrigger")
	check(not Altar.followup_ready(s,at),"completed follow-up unavailable")
	check(not s.start_story_encounter(Altar.EVENT_ID,at,[s.world.roster[0].id]),"completed battle cannot start again")
	var done: Dictionary=s.world.snapshot().duplicate(true)
	check(Altar.finish(s,at),"repeated Finish accepted idempotently")
	check(s.world.snapshot()==done,"repeat Finish never duplicates state")
	s.reload_world()
	check(Altar.completed(s),"quest completion survives reconnect")
	check(s.get_story_event(Altar.EVENT_ID).status=="complete","story completion survives reconnect")
	check(s.event_flag_is_set(Altar.RITUAL_TRACKING_FLAG),"new quest persists through reconnect")
	check(not s.event_flag_is_set(Altar.TRACKING_FLAG),"previous quest remains deactivated after reload")

func passing() -> void:
	var s=fixture("pass","pass")
	var at: int=s.world.position
	check(Altar.followup_ready(s,at),"saved pass decision opens aftermath without battle")
	check(Beats.followup_effect("pass",str(s.get_story_event(Altar.EVENT_ID).battle_result))==Beats.PASS_EFFECT,"pass branch's exact line")
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty(),"passing starts no combat")
	check(not s.event_flag_is_set(Altar.BATTLE_WON_FLAG) and not s.event_flag_is_set(Altar.BATTLE_LOST_FLAG),"pass grants no fight outcome")
	s.reload_world()
	check(Altar.followup_ready(s,at),"pass follow-up reopens after reconnect")
	check(Altar.reconsider(s,at),"pass can still be deliberately changed before finishing")
	check(not Altar.followup_ready(s,at),"changing choice hides follow-up")
	check(Altar.choose(s,at,2,"pass"),"pass can be selected again")
	verify_handoff(s,"pass")
	check(s.get_story_event(Altar.EVENT_ID).battle_result=="","passing never invents fight history")
	s.free()

func after_battle(outcome: String, on_event_tile: bool) -> void:
	var label: String="win" if outcome=="ally" else "loss"
	var s=fixture(label,"fight",on_event_tile)
	var at: int=s.world.position
	check(not Altar.followup_ready(s,at),"mere fight choice is not conclusion")
	check(not Altar.finish(s,at),"fight cannot complete before battle")
	check(s.start_story_encounter(Altar.EVENT_ID,at,[s.world.roster[0].id]),"actual event battle begins")
	check(not Altar.finish(s,at),"active battle cannot finish event")
	check(s.finish_encounter(BattleResult.new(outcome)),"battle outcome saved")
	var result: String="won" if outcome=="ally" else "lost"
	check(s.get_story_event(Altar.EVENT_ID).battle_result==result,"actual battle result preserved")
	check(s.story_battle_result_pending(Altar.EVENT_ID),"battle return screen remains pending")
	check(not Altar.followup_ready(s,at),"unacknowledged result cannot bypass result scene")
	check(not Altar.finish(s,at),"cannot skip result acknowledgment")
	s.reload_world()
	check(s.story_battle_result_pending(Altar.EVENT_ID),"result reopens on reconnect")
	check(s.acknowledge_story_battle_result(Altar.EVENT_ID),"user confirms battle return")
	check(not s.story_battle_result_pending(Altar.EVENT_ID),"result screen receipt consumed")
	check(Altar.followup_ready(s,at),"canonical follow-up narration now unlocked")
	check(Beats.followup_effect("fight",result)==(Beats.FIGHT_WON_EFFECT if result=="won" else Beats.FIGHT_LOST_EFFECT),"source battle aftermath matched")
	s.reload_world()
	check(Altar.followup_ready(s,at),"acknowledged aftermath resumes without replaying fight")
	verify_handoff(s,"fight")
	check(s.get_story_event(Altar.EVENT_ID).battle_result==result,"final story keeps actual win/loss")
	check(s.event_flag_is_set(Altar.BATTLE_WON_FLAG)==(result=="won"),"victory receipt remains exact")
	check(s.event_flag_is_set(Altar.BATTLE_LOST_FLAG)==(result=="lost"),"defeat receipt remains exact")
	s.free()

func failed_write() -> void:
	for choice in ["pass","fight"]:
		var s=fixture("rollback_"+choice,choice)
		var at: int=s.world.position
		if choice=="fight":
			check(s.start_story_encounter(Altar.EVENT_ID,at,[s.world.roster[0].id]),"rollback setup battle starts")
			check(s.finish_encounter(BattleResult.new("ally")),"rollback setup wins")
			check(s.acknowledge_story_battle_result(Altar.EVENT_ID),"rollback setup result acknowledged")
		check(Altar.followup_ready(s,at),"rollback setup ready")
		var before: Dictionary=s.world.snapshot().duplicate(true)
		var good: String=s.save_file_path
		s.save_file_path="user://cultist_altar_followup_missing_%d/failed.json" % OS.get_process_id()
		check(not Altar.finish(s,at),"storage error rejects handoff")
		check(s.world.snapshot()==before,"failed save restores choice, flags and quest state")
		check(Altar.followup_ready(s,at),"failed save retains original follow-up")
		check(not s.event_flag_is_set(Altar.COMPLETE_FLAG),"failed save grants no completion")
		check(not s.event_flag_is_set(Altar.RITUAL_CONFIRMED_FLAG),"failed save grants no plot flag")
		s.save_file_path=good
		check(Altar.finish(s,at),"handoff retries successfully after recovery")
		s.free()

func guards() -> void:
	var s=fixture("guards","pass")
	var at: int=s.world.position
	var snapshot: Dictionary=s.world.snapshot().duplicate(true)
	check(not Altar.finish(s,at+1),"wrong tile cannot finish story")
	s.world.pending_move={"test":true}
	check(not Altar.finish(s,at),"pending movement blocks completion")
	s.world.restore(snapshot)
	s.world.pending_reward={"test":true}
	check(not Altar.finish(s,at),"pending reward blocks completion")
	s.world.restore(snapshot)
	s.world.event_flags[Altar.TRACKING_FLAG]=false
	check(not Altar.finish(s,at),"removed old quest blocks completion")
	s.world.restore(snapshot)
	s.world.event_flags[Altar.RESULT_PENDING_FLAG]=true
	check(not Altar.finish(s,at),"fake pending result blocks completion")
	s.world.restore(snapshot)
	s.world.story_events[Altar.EVENT_ID].choice="fight"
	check(not Altar.finish(s,at),"forged fight intent cannot complete")
	s.world.restore(snapshot)
	check(Altar.followup_ready(s,at),"guard recovery permits legitimate completion")
	s.free()

func _run() -> void:
	verify_source()
	passing()
	after_battle("ally",false)
	after_battle("enemy",true)
	failed_write()
	guards()
	for path in files: cleanup(path)
	print("CULTIST_ALTAR_FOLLOWUP_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
