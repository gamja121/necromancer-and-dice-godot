extends SceneTree
## P1-05D: full commander dialogue, recognition and hunter quest persistence.
const SessionScript=preload("res://systems/run_session.gd")
const Child=preload("res://systems/story_event_entry.gd")
const Rumor=preload("res://systems/village_rumor_entry.gd")
const RumorBeats=preload("res://systems/village_rumor_beats.gd")
const Commander=preload("res://systems/knight_commander_entry.gd")
const Beats=preload("res://systems/knight_commander_beats.gd")

class BattleResult:
	extends RefCounted
	var victor: String
	var units: Array=[]
	func _init(name: String) -> void: victor=name
	func winner() -> String: return victor
	func find_id(_id: String) -> Dictionary: return {}

var passed: int=0
var failed: int=0
var paths: Array[String]=[]

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, what: String) -> void:
	if ok:
		passed+=1
		print("PASS commander-dialogue: ",what)
	else:
		failed+=1
		printerr("FAIL commander-dialogue: ",what)

func delete(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func fixture(suffix: String):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://commander_dialogue_%d_%s.json" % [OS.get_process_id(),suffix]
	paths.append(path)
	delete(path)
	s.save_file_path=path
	s.start_new_world()
	var grave: int=s.world.tiles.find("graveyard")
	s.world.position=grave
	check(Child.begin(s,grave),"discover original child")
	check(Child.choose(s,grave,"protect_child"),"choose rescue route")
	check(s.start_story_encounter(Child.EVENT_ID,grave,[s.world.roster[0].id]),"start ghoul battle")
	check(s.finish_encounter(BattleResult.new("ally")),"defeat ghoul")
	check(s.acknowledge_graveyard_battle_result(),"accept rescue outcome")
	var village: int=s.world.tiles.find("village")
	s.world.position=village
	check(Rumor.begin(s,village)==Rumor.RESCUED_ID,"start rescued rumor")
	for i in range(RumorBeats.count(Rumor.RESCUED_ID)):
		check(Rumor.advance(s,village,Rumor.RESCUED_ID,i),"complete rescue rumor scene "+str(i))
	check(s.get_story_event(Rumor.RESCUED_ID).status=="complete","rescue rumor is completed")
	check(Commander.begin(s,village),"commander first landing saved")
	return s

func verify_source_beats() -> void:
	check(Beats.count()==7,"seven canonical source beats")
	var ids: Array=["arrival","confirm","player_reply","recognition","contamination","hunter","quest"]
	for index in range(ids.size()):
		check(Beats.beat(index).id==ids[index],"beat order "+ids[index])
	check(Beats.beat(-1).is_empty(),"negative beat rejected")
	check(Beats.beat(7).is_empty(),"postfinal beat rejected")
	check(Beats.beat(0)==Commander.FIRST_BEAT.merged({"portrait":Beats.COMMANDER}),"previous first arrival matches source")
	check(Beats.beat(1).dialogue=="공동묘지에서 아이를 구한 게 당신인가?","commander asks about saved child")
	check(Beats.beat(2).dialogue=="..." and Beats.beat(2).speaker=="주인공","player remains silent per source")
	check(Beats.beat(3).dialogue=="소문은 들었다. 네가 무엇을 거느리든, 아이를 구한 일만큼은 인정하지.","recognition line exact")
	check(Beats.beat(4).dialogue=="문제는 다른 곳에 있다. 성 밖의 오염이 점점 짙어지고 있어.","contamination line exact")
	check(Beats.beat(5).dialogue=="마물 사냥꾼 하나가 오염에 대해 뭔가 알고 있는 눈치더군. 그자를 찾아가 봐라.","hunter referral exact")
	check(Beats.beat(6).dialogue=="[오염에 대한 의뢰를 받았습니다.]","quest acceptance exact")
	check(Beats.beat(6).get("quest_accepted",false)==true,"final beat declares accepted quest")
	check(not Beats.is_final(5) and Beats.is_final(6),"last scene only")
	check(Beats.beat(2).portrait==Beats.PLAYER,"player portrait only on reply")
	for i in [0,1,3,4,5,6]:
		check(Beats.beat(i).portrait==Beats.COMMANDER,"commander remains visible on scene "+str(i))
	check(ResourceLoader.exists(Beats.COMMANDER),"commander portrait is bundled")
	check(ResourceLoader.exists(Beats.PLAYER),"protagonist portrait is bundled")
	check(ResourceLoader.exists(Commander.ART),"village background bundled")
	var copy: Dictionary=Beats.beat(3)
	copy.dialogue="tamper"
	check(Beats.beat(3).dialogue.begins_with("소문은"),"returned beat cannot change source")

func advance_full_story(use_event_tile: bool) -> void:
	var s=fixture("event" if use_event_tile else "village")
	var idx: int=s.world.position
	if use_event_tile:
		idx=s.world.tiles.find("event")
		check(idx>=0,"wildcard tile present")
		s.world.position=idx
	check(Commander.can_enter(s,idx),"commander can continue on designated/wildcard tile")
	check(Commander.current_beat(s)==0,"first scene starts at zero")
	check(Commander.progress_flag(0).is_empty(),"arrival flag implicit")
	check(Commander.progress_flag(7).is_empty(),"out of bounds progress flag absent")
	check(Commander.progress_flag(-1).is_empty(),"negative progress flag absent")
	check(not Commander.advance(s,idx,1),"cannot jump to second beat")
	check(not Commander.advance(s,idx+1,0),"cannot commit from another tile")
	for i in range(Beats.count()-1):
		check(Commander.current_beat(s)==i,"visible beat index "+str(i))
		check(Commander.advance(s,idx,i),"next dialogue saved at index "+str(i))
		check(s.event_flag_is_set(Commander.progress_flag(i+1)),"saved beat marker "+str(i+1))
		check(s.get_story_event(Commander.EVENT_ID).status=="seen","story still active before final")
		check(not s.event_flag_is_set(Commander.RECOGNIZED_FLAG),"no premature recognition "+str(i))
		check(not s.event_flag_is_set(Commander.QUEST_ACTIVE_FLAG),"quest inactive until last confirmation "+str(i))
		var snapshot: Dictionary=s.world.snapshot().duplicate(true)
		check(not Commander.advance(s,idx,i),"stale button cannot advance again "+str(i))
		check(s.world.snapshot()==snapshot,"stale click leaves snapshot unchanged "+str(i))
		s.reload_world()
		check(s.world.position==idx,"saved location restored "+str(i))
		check(Commander.current_beat(s)==i+1,"scene resumes after reload "+str(i+1))
		check(Commander.begin(s,idx),"reentry uses current scene")
	check(Beats.is_final(Commander.current_beat(s)),"final system message reached")
	check(not s.event_flag_is_set(Commander.COMPLETE_FLAG),"final message alone does not consume story")
	check(s.get_story_event(Commander.EVENT_ID).status=="seen","still seen until last click")
	s.reload_world()
	check(Commander.current_beat(s)==6,"final scene survives restart")
	check(Commander.advance(s,idx,6),"final click commits quest and recognition")
	check(s.get_story_event(Commander.EVENT_ID).status=="complete","commander event completed")
	check(s.event_flag_is_set(Commander.SEEN_FLAG),"seen remains true")
	check(s.event_flag_is_set(Commander.COMPLETE_FLAG),"completion persisted")
	check(s.event_flag_is_set(Commander.RECOGNIZED_FLAG),"recognition persisted")
	check(s.event_flag_is_set(Commander.QUEST_ACTIVE_FLAG),"hunter quest now active")
	check(not s.event_flag_is_set(Commander.QUEST_COMPLETE_FLAG),"hunter quest not pre-completed")
	check(not Commander.can_enter(s,idx),"completed commander does not retrigger")
	check(Commander.current_beat(s)==-1,"completed commander has no pending beat")
	check(not Commander.begin(s,idx),"completed commander cannot restart")
	check(not Commander.advance(s,idx,6),"stale final click cannot award twice")
	s.reload_world()
	check(s.get_story_event(Commander.EVENT_ID).status=="complete","completed story survives relaunch")
	check(s.event_flag_is_set(Commander.RECOGNIZED_FLAG),"recognition survives relaunch")
	check(s.event_flag_is_set(Commander.QUEST_ACTIVE_FLAG),"quest survives relaunch")
	check(not s.event_flag_is_set(Commander.QUEST_COMPLETE_FLAG),"hunter quest still awaits encounter")
	s.free()

func disk_failures() -> void:
	var s=fixture("disk")
	var idx: int=s.world.position
	var real_path: String=s.save_file_path
	var failure_path: String="user://commander_dialogue_no_dir_%d/save.json" % OS.get_process_id()
	var before: Dictionary=s.world.snapshot().duplicate(true)
	s.save_file_path=failure_path
	check(not Commander.advance(s,idx,0),"intermediate disk save failure reported")
	check(s.world.snapshot()==before,"intermediate failure rolls back all state")
	check(Commander.current_beat(s)==0,"failed scene save remains on original beat")
	s.save_file_path=real_path
	check(Commander.advance(s,idx,0),"intermediate retry succeeds")
	for i in range(1,Beats.count()-1):
		check(Commander.advance(s,idx,i),"prepare final beat "+str(i))
	check(Commander.current_beat(s)==6,"final beat visible for failure test")
	before=s.world.snapshot().duplicate(true)
	s.save_file_path=failure_path
	check(not Commander.advance(s,idx,6),"final acceptance save error reported")
	check(s.world.snapshot()==before,"failed final acknowledgement atomically reverted")
	check(s.get_story_event(Commander.EVENT_ID).status=="seen","failed final does not complete")
	check(not s.event_flag_is_set(Commander.COMPLETE_FLAG),"failed final has no completion flag")
	check(not s.event_flag_is_set(Commander.RECOGNIZED_FLAG),"failed final has no recognition")
	check(not s.event_flag_is_set(Commander.QUEST_ACTIVE_FLAG),"failed final has no quest")
	s.save_file_path=real_path
	s.reload_world()
	check(Commander.current_beat(s)==6,"final scene resumes after I/O failure and restart")
	check(Commander.advance(s,idx,6),"final save succeeds after recovery")
	s.reload_world()
	check(s.event_flag_is_set(Commander.QUEST_ACTIVE_FLAG),"recovered quest persists")
	s.free()

func guarded_progress() -> void:
	var s=fixture("corrupt")
	var idx: int=s.world.position
	s.world.event_flags[Commander.progress_flag(2)]=true
	check(Commander.current_beat(s)==-1,"skipped beat flag detected")
	check(not Commander.advance(s,idx,0),"skipped beat does not allow advancement")
	s.world.event_flags.erase(Commander.progress_flag(2))
	check(Commander.current_beat(s)==0,"removing invalid flag restores beat")
	s.world.pending_reward={"kind":"test"}
	check(not Commander.advance(s,idx,0),"pending reward blocks dialogue save")
	s.world.pending_reward={}
	s.world.active_encounter={"testing":true}
	check(not Commander.advance(s,idx,0),"active encounter blocks dialogue save")
	s.world.active_encounter={}
	check(Commander.advance(s,idx,0),"dialogue resumes when blockers resolved")
	s.world.event_flags[Commander.RECOGNIZED_FLAG]=true
	check(Commander.current_beat(s)==-1,"premature recognition flag invalidates event")
	check(not Commander.advance(s,idx,1),"cannot continue a contradicted event state")
	s.free()

func ui_wiring() -> void:
	var src: String=FileAccess.get_file_as_string("res://map.gd")
	check(src.contains('func show_knight_commander_intro(index: int) -> void:'),"old intro entry preserved")
	check(src.contains('func show_knight_commander_beat(index: int) -> void:'),"all dialogue rendered by saved index")
	check(src.contains('KnightCommanderEntry.current_beat(session)'),"scene reads persisted progress")
	check(src.contains('KnightCommanderBeats.beat(beat_index)'),"scene looks up original dialogue")
	check(src.contains('str(beat.portrait)'),"scene switches commander and player portrait")
	check(src.contains('str(beat.dialogue)'),"scene displays full dialogue")
	check(src.contains('func advance_knight_commander(index: int, shown_beat: int) -> void:'),"guarded advance UI handler")
	check(src.contains('KnightCommanderEntry.advance(session,index,shown_beat)'),"UI persists only clicked step")
	check(src.contains('KnightCommanderBeats.is_final(shown_beat)'),"last scene recognized by UI")
	check(src.contains('"마치기"'),"explicit final acceptance button")
	check(src.contains('"마을 기능"'),"original village actions retained")
	check(src.contains('"돌아가기"'),"player may exit unfinished scene")
	check(src.contains('session.get_story_event(KnightCommanderEntry.EVENT_ID).status=="seen"'),"only started story automatically resumes")
	check(src.contains('if not Commander')==false,"map remains independent from test aliases")

func _run() -> void:
	verify_source_beats()
	advance_full_story(false)
	advance_full_story(true)
	disk_failures()
	guarded_progress()
	ui_wiring()
	for path in paths: delete(path)
	print("KNIGHT_COMMANDER_DIALOGUE_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
