extends SceneTree
## P1-05I-3: original choice screen with durable, reversible intent, no outcome.
const SessionScript = preload("res://systems/run_session.gd")
const Rumor = preload("res://systems/cultist_rumor_entry.gd")
const Altar = preload("res://systems/cultist_altar_entry.gd")
const Beats = preload("res://systems/cultist_altar_beats.gd")
const Registry = preload("res://systems/story_battle_registry.gd")

var passed: int=0
var failed: int=0
var paths: Array[String]=[]

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, what: String) -> void:
	if ok:
		passed+=1
		print("PASS cultist-altar-choice: ",what)
	else:
		failed+=1
		printerr("FAIL cultist-altar-choice: ",what)

func cleanup(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func fixture(suffix: String,on_event_tile: bool=false):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://cultist_altar_choice_%d_%s.json" % [OS.get_process_id(),suffix]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	s.world.story_events[Rumor.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	s.world.event_flags[Rumor.SEEN_FLAG]=true
	s.world.event_flags[Rumor.COMPLETE_FLAG]=true
	s.world.event_flags[Rumor.TRACKING_FLAG]=true
	s.world.position=s.world.tiles.find("event" if on_event_tile else "altar")
	check(s.save_world(),"prerequisite rumor state persisted")
	var index: int=s.world.position
	check(Altar.begin(s,index),"first altar scene persisted")
	check(Altar.advance(s,index,0),"ritual reveal persisted")
	check(Altar.advance(s,index,1),"choice scene persisted")
	check(Altar.current_beat(s)==2,"original choice scene now visible")
	return s

func original_contract() -> void:
	check(Beats.count()==3,"three canonical altar beats, no future stages")
	check(Beats.beat(2).id=="choice","exact canonical final beat id")
	check(Beats.beat(2).effect=="아직 그들은 당신을 눈치채지 못했다.","original choice narration verbatim")
	check(Beats.beat(2).dialogue.is_empty(),"no invented dialogue")
	check(Beats.beat(2).speaker.is_empty(),"no invented speaker")
	check(Beats.beat(2).visual=="ritual","same existing ritual layer retained")
	check(Beats.beat(2).choice==true,"canonical choice bit true")
	check(Beats.layer_for(str(Beats.beat(2).visual))==Beats.RITUAL,"no new art invented")
	check(Beats.beat(3).is_empty(),"no subsequent scene unlocked")
	check(Altar.progress_flag(2)=="event:cultist_altar_encounter_01:beat:2","third beat checkpoint uses existing save schema")
	check(Altar.progress_flag(3).is_empty(),"later checkpoint blocked")
	check(Registry.definition(Altar.EVENT_ID).is_empty(),"cultist combat registration disabled")
	var src: String=FileAccess.get_file_as_string("res://map.gd")
	check(src.contains('location_button(panel,"싸운다"'),"fight option shown in choice UI")
	check(src.contains('location_button(panel,"지나간다"'),"pass option shown in choice UI")
	check(src.contains('elif altar_state.status=="seen" and beat.get("choice",false)==true:'),"options gated to original choice beat")
	check(src.contains("CultistAltarEntry.choose(session,index,shown_beat,decision)"),"choice button explicitly saves intent")
	check(src.contains('location_button(panel,"선택 변경"'),"pending choice may be changed")
	check(src.contains("CultistAltarEntry.reconsider(session,index)"),"change button restores choice without reset")
	check(src.contains("InkSceneReveal.play(ritual_art)"),"ritual illustration remains in scene")
	check(src.contains("str(beat.effect)"),"original text rendered")
	check(src.contains('session.get_story_event(CultistAltarEntry.EVENT_ID).status=="active"'),"reconnect reopens saved pending choice")
	check(not src.contains("start_cultist_altar_battle("),"no combat launch handler")
	check(not src.contains("complete_cultist_altar_event("),"no instant passage completion")

func choose_and_reconsider(decision: String,on_event_tile: bool) -> void:
	var suffix: String=decision+("_event" if on_event_tile else "_altar")
	var s=fixture(suffix,on_event_tile)
	var i: int=s.world.position
	check(not Altar.choose(s,i,1,decision),"cannot choose from previous beat")
	check(not Altar.choose(s,i+1,2,decision),"cannot choose from adjacent tile")
	check(not Altar.choose(s,i,2,"escape"),"unknown branch rejected")
	check(not Altar.choose(s,i,2,""),"empty branch rejected")
	check(Altar.choose(s,i,2,decision),"choice selected and atomically saved")
	var correct_flag: String=Altar.FIGHT_FLAG if decision=="fight" else Altar.PASS_FLAG
	var wrong_flag: String=Altar.PASS_FLAG if decision=="fight" else Altar.FIGHT_FLAG
	check(s.get_story_event(Altar.EVENT_ID).status=="active","pending decision is active, not complete")
	check(s.get_story_event(Altar.EVENT_ID).choice==decision,"canonical story choice records decision")
	check(s.event_flag_is_set(correct_flag),"matching branch receipt saved")
	check(not s.event_flag_is_set(wrong_flag),"mutually exclusive other branch remains false")
	check(Altar.current_beat(s)==2,"scene remains on saved choice, never jumps into battle")
	check(not s.event_flag_is_set(Altar.COMPLETE_FLAG),"no event completion")
	check(not s.event_flag_is_set(Altar.RITUAL_CONFIRMED_FLAG),"no ritual confirmation")
	check(not s.event_flag_is_set(Altar.RITUAL_TRACKING_FLAG),"no later quest activation")
	check(s.encounter.is_empty(),"no immediate active encounter")
	check(s.world.active_encounter.is_empty(),"no persisted combat launch")
	check(s.world.pending_reward.is_empty(),"no reward generated")
	check(not Altar.choose(s,i,2,decision),"duplicate choice not applied")
	check(not Altar.choose(s,i,2,"pass" if decision=="fight" else "fight"),"cannot switch without explicit reconsider")
	check(not Altar.advance(s,i,1),"old Continue click blocked after choice")
	var confirmed: Dictionary=s.world.snapshot().duplicate(true)
	s.reload_world()
	check(Altar.can_enter(s,i),"reconnect permits canonical unfinished choice")
	check(Altar.current_beat(s)==2,"reconnect restores pending choice screen")
	check(s.get_story_event(Altar.EVENT_ID).choice==decision,"reconnect restores chosen branch")
	check(s.world.snapshot()==confirmed,"reload did not grant rewards or additional events")
	check(Altar.begin(s,i),"reopening active story is idempotent")
	check(s.world.snapshot()==confirmed,"reopen cannot reset recorded choice")
	check(Altar.reconsider(s,i),"explicit choice-change click restores undecided view")
	check(Altar.current_beat(s)==2,"change retains the same choice checkpoint")
	check(s.get_story_event(Altar.EVENT_ID).status=="seen","choice cleared without completing")
	check(s.get_story_event(Altar.EVENT_ID).choice.is_empty(),"decision cleared")
	check(not s.event_flag_is_set(Altar.FIGHT_FLAG),"fight receipt cleared")
	check(not s.event_flag_is_set(Altar.PASS_FLAG),"pass receipt cleared")
	check(not Altar.reconsider(s,i),"second reconsider blocked")
	check(Altar.choose(s,i,2,"pass" if decision=="fight" else "fight"),"other option can now be selected")
	s.reload_world()
	check(s.get_story_event(Altar.EVENT_ID).choice!=decision,"changed decision persists")
	check(Altar.current_beat(s)==2,"changed decision reopens same screen")
	s.free()

func failures() -> void:
	var s=fixture("save_error")
	var index: int=s.world.position
	var good: String=s.save_file_path
	var before: Dictionary=s.world.snapshot().duplicate(true)
	s.save_file_path="user://altar_choice_missing_%d/failed.json" % OS.get_process_id()
	check(not Altar.choose(s,index,2,"fight"),"storage failure blocks fight choice")
	check(s.world.snapshot()==before,"failed fight rolls back flags and story together")
	check(not Altar.choose(s,index,2,"pass"),"storage failure blocks pass choice")
	check(s.world.snapshot()==before,"failed pass rolls back all changes")
	s.save_file_path=good
	check(Altar.choose(s,index,2,"pass"),"choice retry after storage fix succeeds")
	var chosen: Dictionary=s.world.snapshot().duplicate(true)
	s.save_file_path="user://altar_choice_missing_%d/failed.json" % OS.get_process_id()
	check(not Altar.reconsider(s,index),"failed choice-change cannot clear decision")
	check(s.world.snapshot()==chosen,"failed reconsider rolls back to selected option")
	s.save_file_path=good
	check(Altar.reconsider(s,index),"reconsider retries successfully after recovery")
	s.reload_world()
	check(Altar.current_beat(s)==2,"successful reconsider persists undecided screen")
	check(s.get_story_event(Altar.EVENT_ID).choice.is_empty(),"choice cleared after reconnect")
	s.free()

func guards() -> void:
	var s=fixture("guards")
	var i: int=s.world.position
	var baseline: Dictionary=s.world.snapshot().duplicate(true)
	s.world.event_flags[Altar.PASS_FLAG]=true
	check(not Altar.can_enter(s,i),"stray pass flag invalid without chosen active state")
	check(not Altar.choose(s,i,2,"fight"),"cannot choose from corrupt flag state")
	s.world.restore(baseline)
	s.world.event_flags[Altar.progress_flag(1)]=false
	check(not Altar.can_enter(s,i),"choice checkpoint without ritual checkpoint rejected")
	s.world.restore(baseline)
	s.world.pending_move={"test":true}
	check(not Altar.choose(s,i,2,"pass"),"pending movement blocks choice")
	s.world.restore(baseline)
	s.world.active_encounter={"test":true}
	check(not Altar.choose(s,i,2,"pass"),"active combat blocks choice")
	s.world.restore(baseline)
	s.world.tiles[i]="forest"
	check(not Altar.choose(s,i,2,"pass"),"wrong tile blocks choice")
	s.world.restore(baseline)
	check(Altar.choose(s,i,2,"fight"),"valid choice can recover after guards")
	var chosen: Dictionary=s.world.snapshot().duplicate(true)
	s.world.event_flags[Altar.PASS_FLAG]=true
	check(not Altar.can_enter(s,i),"both opposing decisions fail closed")
	s.world.restore(chosen)
	s.world.story_events[Altar.EVENT_ID].choice="pass"
	check(not Altar.can_enter(s,i),"choice mismatch to fight receipt fails closed")
	s.world.restore(chosen)
	s.world.event_flags[Altar.FIGHT_FLAG]=false
	check(not Altar.can_enter(s,i),"missing decision receipt fails closed")
	s.world.restore(chosen)
	s.world.event_flags[Altar.RITUAL_CONFIRMED_FLAG]=true
	check(not Altar.can_enter(s,i),"later ritual blocks old selection replay")
	s.world.restore(chosen)
	check(Altar.can_enter(s,i),"all guards are recoverable")
	s.free()

func _run() -> void:
	original_contract()
	choose_and_reconsider("fight",false)
	choose_and_reconsider("pass",true)
	failures()
	guards()
	for path in paths: cleanup(path)
	print("CULTIST_ALTAR_CHOICE_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
