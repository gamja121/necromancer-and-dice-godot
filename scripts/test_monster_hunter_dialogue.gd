extends SceneTree
## P1-05F: all 11 canonical beats, source layers, saves and atomic clue reward.
const SessionScript=preload("res://systems/run_session.gd")
const Child=preload("res://systems/story_event_entry.gd")
const Rumor=preload("res://systems/village_rumor_entry.gd")
const RumorBeats=preload("res://systems/village_rumor_beats.gd")
const Commander=preload("res://systems/knight_commander_entry.gd")
const CommanderBeats=preload("res://systems/knight_commander_beats.gd")
const Hunter=preload("res://systems/monster_hunter_entry.gd")
const Beats=preload("res://systems/monster_hunter_beats.gd")

class Result:
	extends RefCounted
	var outcome: String
	var units: Array=[]
	func _init(name: String) -> void: outcome=name
	func winner() -> String: return outcome
	func find_id(_id: String) -> Dictionary: return {}

var passed: int=0
var failed: int=0
var paths: Array[String]=[]

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, name: String) -> void:
	if ok:
		passed+=1
		print("PASS hunter-dialogue: ",name)
	else:
		failed+=1
		printerr("FAIL hunter-dialogue: ",name)

func clear(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func fixture(suffix: String):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://hunter_dialogue_%d_%s.json" % [OS.get_process_id(),suffix]
	paths.append(path)
	clear(path)
	s.save_file_path=path
	s.start_new_world()
	var grave: int=s.world.tiles.find("graveyard")
	s.world.position=grave
	check(Child.begin(s,grave),"child story discovered")
	check(Child.choose(s,grave,"protect_child"),"rescue route chosen")
	check(s.start_story_encounter(Child.EVENT_ID,grave,[s.world.roster[0].id]),"ghoul encounter entered")
	check(s.finish_encounter(Result.new("ally")),"rescue victory committed")
	check(s.acknowledge_graveyard_battle_result(),"rescue result acknowledged")
	var village: int=s.world.tiles.find("village")
	s.world.position=village
	check(Rumor.begin(s,village)==Rumor.RESCUED_ID,"rescued rumor discovered")
	for i in range(RumorBeats.count(Rumor.RESCUED_ID)):
		check(Rumor.advance(s,village,Rumor.RESCUED_ID,i),"rescued rumor beat "+str(i))
	check(Commander.begin(s,village),"commander discovered")
	for i in range(CommanderBeats.count()):
		check(Commander.advance(s,village,i),"commander beat "+str(i))
	check(s.event_flag_is_set(Hunter.QUEST_ACTIVE_FLAG),"hunter investigation quest activated")
	check(not s.event_flag_is_set(Hunter.QUEST_COMPLETE_FLAG),"hunter quest not yet done")
	var tree: int=s.world.tiles.find("unknown")
	s.world.position=tree
	check(Hunter.begin(s,tree),"hunter seen marker persisted")
	return s

func verify_source() -> void:
	var ids: Array=["arrival","warning_reveal","warning","identify","player_reply","sent_by_commander","unnatural","gathered","mark","human","clue"]
	var visuals: Array=["base","scene","scene","portrait","player","portrait","scene","scene","portrait","portrait","scene"]
	check(Beats.count()==11,"all eleven canonical beats available")
	for i in range(ids.size()):
		var beat: Dictionary=Beats.beat(i)
		check(beat.id==ids[i],"canonical order "+ids[i])
		check(beat.visual==visuals[i],"canonical visual "+ids[i])
	check(Beats.beat(-1).is_empty(),"negative beat cannot render")
	check(Beats.beat(11).is_empty(),"postfinal beat cannot render")
	check(Beats.beat(0)==Hunter.FIRST_BEAT,"previous P1-05E opening preserved exactly")
	check(Beats.beat(1).effect=="다음 순간, 오염된 마물의 사체를 조사하던 노인이 당신의 기척을 알아챈다.","original hunter reveal")
	check(Beats.beat(2).dialogue=="거기서 멈춰.","original hunter warning")
	check(Beats.beat(3).dialogue=="죽은 것들을 끌고 다니는 놈이 있다는 소문은 들었는데… 네가 그놈이군.","original hunter identification")
	check(Beats.beat(4).speaker=="주인공" and Beats.beat(4).dialogue=="...","original protagonist silent response")
	check(Beats.beat(5).dialogue=="기사단장이 보냈나? 오염에 대해 묻고 싶은 거겠지.","original commander referral")
	check(Beats.beat(6).dialogue=="이건 자연스럽게 퍼지는 게 아니야.","unnatural corruption hint")
	check(Beats.beat(7).dialogue=="누군가 오염된 마물들을 모으고 있다. 일부러 말이지.","deliberate monster gathering")
	check(Beats.beat(8).dialogue=="놈들이 남긴 흔적을 몇 번 봤다. 같은 문양을 쓰더군.","cultist symbol hint")
	check(Beats.beat(9).dialogue=="사람들이야. 마물이 아니라.","human involvement revelation")
	check(Beats.beat(10).effect=="오염을 의도적으로 퍼뜨리는 자들에 대한 단서를 확보했다.","final clue narration")
	check(Beats.beat(10).dialogue=="[오염을 퍼뜨리는 자들에 대한 단서를 얻었습니다.]","exact final system reward text")
	check(Beats.beat(10).get("clue_obtained",false)==true,"only final beat yields clue")
	for i in range(10):
		check(Beats.beat(i).get("clue_obtained",false)==false,"no early clue metadata "+str(i))
	check(not Beats.is_final(9) and Beats.is_final(10),"only final beat requires completion")
	check(Beats.visual_art("base").is_empty(),"first arrival has no overlay")
	check(Beats.visual_art("scene")==Beats.SCENE,"corrupted beast illustration")
	check(Beats.visual_art("portrait")==Beats.HUNTER,"hunter portrait illustration")
	check(Beats.visual_art("player")==Beats.PLAYER,"protagonist image")
	check(Beats.visual_art("bogus").is_empty(),"unknown visual has no overlay")
	for art in [Beats.BASE,Beats.SCENE,Beats.HUNTER,Beats.PLAYER]:
		check(ResourceLoader.exists(art),"source illustration exists: "+art)
	var copy: Dictionary=Beats.beat(5)
	copy.dialogue="tamper"
	check(Beats.beat(5).dialogue.begins_with("기사단장이"),"beat retrieval never corrupts source")

func run_full(wildcard: bool) -> void:
	var s=fixture("event" if wildcard else "tree")
	var idx: int=s.world.position
	if wildcard:
		idx=s.world.tiles.find("event")
		check(idx>=0,"generic event tile available")
		s.world.position=idx
	check(Hunter.can_enter(s,idx),"hunter dialogue eligible on assigned tile")
	check(Hunter.current_beat(s)==0,"saved first arrival is beat zero")
	check(Hunter.progress_flag(0).is_empty(),"initial beat has no extra flag")
	check(Hunter.progress_flag(11).is_empty(),"out-of-bounds progress flag absent")
	check(Hunter.progress_flag(-1).is_empty(),"negative beat has no progress flag")
	check(not Hunter.advance(s,idx,1),"cannot skip first beat")
	check(not Hunter.advance(s,idx+1,0),"other tile cannot advance")
	for i in range(Beats.count()-1):
		check(Hunter.current_beat(s)==i,"current beat "+str(i))
		check(Hunter.advance(s,idx,i),"explicit next beat persisted "+str(i))
		check(s.event_flag_is_set(Hunter.progress_flag(i+1)),"beat flag stored "+str(i+1))
		check(s.get_story_event(Hunter.EVENT_ID).status=="seen","story still seen at step "+str(i))
		check(s.event_flag_is_set(Hunter.QUEST_ACTIVE_FLAG),"investigation quest active at step "+str(i))
		check(not s.event_flag_is_set(Hunter.QUEST_COMPLETE_FLAG),"quest not done early "+str(i))
		check(not s.event_flag_is_set(Hunter.CULTIST_CLUE_FLAG),"clue not awarded early "+str(i))
		check(not s.event_flag_is_set(Hunter.COMPLETE_FLAG),"event not done early "+str(i))
		var state: Dictionary=s.world.snapshot().duplicate(true)
		check(not Hunter.advance(s,idx,i),"stale click rejected "+str(i))
		check(s.world.snapshot()==state,"stale click makes no changes "+str(i))
		s.reload_world()
		check(s.world.position==idx,"save restores location "+str(i))
		check(Hunter.current_beat(s)==i+1,"save restores exact next beat "+str(i+1))
		check(Hunter.begin(s,idx),"resume allows already seen hunter")
	check(Hunter.current_beat(s)==10,"last clue scene visible")
	check(not s.event_flag_is_set(Hunter.CULTIST_CLUE_FLAG),"last scene display has not awarded clue")
	s.reload_world()
	check(Hunter.current_beat(s)==10,"last scene restart requires confirmation")
	check(Hunter.advance(s,idx,10),"explicit final click accepts clue")
	check(s.get_story_event(Hunter.EVENT_ID).status=="complete","hunter story completed")
	check(s.event_flag_is_set(Hunter.COMPLETE_FLAG),"hunter completion flag true")
	check(s.event_flag_is_set(Hunter.SEEN_FLAG),"seen flag retained")
	check(not s.event_flag_is_set(Hunter.QUEST_ACTIVE_FLAG),"hunter investigation marked inactive")
	check(s.event_flag_is_set(Hunter.QUEST_COMPLETE_FLAG),"hunter investigation marked complete")
	check(s.event_flag_is_set(Hunter.CULTIST_CLUE_FLAG),"human involvement clue awarded")
	check(s.event_flag_is_set(Hunter.RECOGNITION_FLAG),"commander recognition preserved")
	check(not Hunter.can_enter(s,idx),"completed encounter is not playable again")
	check(Hunter.current_beat(s)==-1,"completed story has no pending dialogue")
	check(not Hunter.begin(s,idx),"cannot re-trigger finished hunter")
	check(not Hunter.advance(s,idx,10),"stale final click cannot duplicate reward")
	s.reload_world()
	check(s.get_story_event(Hunter.EVENT_ID).status=="complete","completed scene reloads")
	check(s.event_flag_is_set(Hunter.CULTIST_CLUE_FLAG),"clue retained across restart")
	check(s.event_flag_is_set(Hunter.QUEST_COMPLETE_FLAG),"quest completion retained")
	check(not s.event_flag_is_set(Hunter.QUEST_ACTIVE_FLAG),"quest still inactive after restart")
	s.free()

func test_io_failure() -> void:
	var s=fixture("failed")
	var idx: int=s.world.position
	var original: String=s.save_file_path
	var denied: String="user://hunter_dialogue_no_dir_%d/no.json" % OS.get_process_id()
	var before: Dictionary=s.world.snapshot().duplicate(true)
	s.save_file_path=denied
	check(not Hunter.advance(s,idx,0),"intermediate save failure returned")
	check(s.world.snapshot()==before,"intermediate state rolled back")
	check(Hunter.current_beat(s)==0,"failed save keeps first beat")
	s.save_file_path=original
	check(Hunter.advance(s,idx,0),"saving resumed after I/O restored")
	for i in range(1,10):
		check(Hunter.advance(s,idx,i),"advance toward final beat "+str(i))
	check(Hunter.current_beat(s)==10,"final scene ready for failed commit")
	before=s.world.snapshot().duplicate(true)
	s.save_file_path=denied
	check(not Hunter.advance(s,idx,10),"final save failure returned")
	check(s.world.snapshot()==before,"failed completion rolled back all flags")
	check(s.get_story_event(Hunter.EVENT_ID).status=="seen","story remains seen on failure")
	check(not s.event_flag_is_set(Hunter.COMPLETE_FLAG),"hunter not completed after failure")
	check(s.event_flag_is_set(Hunter.QUEST_ACTIVE_FLAG),"quest remains active after failure")
	check(not s.event_flag_is_set(Hunter.QUEST_COMPLETE_FLAG),"quest complete not set on failure")
	check(not s.event_flag_is_set(Hunter.CULTIST_CLUE_FLAG),"human clue not granted on failure")
	s.save_file_path=original
	s.reload_world()
	check(Hunter.current_beat(s)==10,"last scene resumes after write failure")
	check(Hunter.advance(s,idx,10),"retry saves all final fields together")
	s.reload_world()
	check(s.event_flag_is_set(Hunter.COMPLETE_FLAG),"final event completion persists")
	check(s.event_flag_is_set(Hunter.QUEST_COMPLETE_FLAG),"final quest completion persists")
	check(s.event_flag_is_set(Hunter.CULTIST_CLUE_FLAG),"final clue persists")
	s.free()

func test_fail_closed() -> void:
	var s=fixture("badflags")
	var idx: int=s.world.position
	s.world.event_flags[Hunter.progress_flag(2)]=true
	check(Hunter.current_beat(s)==-1,"out-of-order future beat detected")
	check(not Hunter.advance(s,idx,0),"cannot skip missing scene")
	s.world.event_flags.erase(Hunter.progress_flag(2))
	check(Hunter.current_beat(s)==0,"valid order recovered")
	s.world.pending_reward={"kind":"test"}
	check(not Hunter.advance(s,idx,0),"pending reward blocks advancement")
	s.world.pending_reward={}
	s.world.pending_move={"testing":true}
	check(not Hunter.advance(s,idx,0),"pending movement blocks advancement")
	s.world.pending_move={}
	s.encounter={"testing":true}
	check(not Hunter.advance(s,idx,0),"active battle blocks advancement")
	s.encounter={}
	s.world.active_encounter={"testing":true}
	check(not Hunter.advance(s,idx,0),"saved battle blocks advancement")
	s.world.active_encounter={}
	s.world.event_flags[Hunter.QUEST_COMPLETE_FLAG]=true
	check(Hunter.current_beat(s)==-1,"premature quest completion blocks progress")
	check(not Hunter.advance(s,idx,0),"cannot accept clue on completed quest")
	s.world.event_flags[Hunter.QUEST_COMPLETE_FLAG]=false
	s.world.event_flags[Hunter.CULTIST_CLUE_FLAG]=true
	check(Hunter.current_beat(s)==-1,"premature clue blocks progress")
	check(not Hunter.advance(s,idx,0),"cannot advance after premature clue")
	s.world.event_flags[Hunter.CULTIST_CLUE_FLAG]=false
	s.world.tiles[idx]="forest"
	check(not Hunter.advance(s,idx,0),"wrong tile blocks progress")
	s.world.tiles[idx]="unknown"
	check(Hunter.current_beat(s)==0,"valid seen scene restored")
	check(Hunter.advance(s,idx,0),"valid progression recovers after corrupt flags repaired")
	s.free()

func test_ui() -> void:
	var ui: String=FileAccess.get_file_as_string("res://map.gd")
	check(ui.contains('func show_monster_hunter_intro(index: int) -> void:'),"old introduction API preserved")
	check(ui.contains('func show_monster_hunter_beat(index: int) -> void:'),"new saved hunter visual handler")
	check(ui.contains('MonsterHunterEntry.current_beat(session)'),"UI reads stored scene position")
	check(ui.contains('MonsterHunterBeats.beat(beat_index)'),"UI fetches canonical beat")
	check(ui.contains('MonsterHunterBeats.visual_art(str(beat.visual))'),"UI resolves correct overlay art")
	check(ui.contains('str(beat.effect)'),"UI renders beat narrative")
	check(ui.contains('str(beat.dialogue)'),"UI renders hunter dialogue")
	check(ui.contains('MonsterHunterEntry.advance(session,index,shown_beat)'),"UI persists explicit advance")
	check(ui.contains('MonsterHunterBeats.is_final(shown_beat)'),"final confirmation recognition")
	check(ui.contains('"마치기"'),"final confirmation button")
	check(ui.contains('"계속"'),"next beat button")
	check(ui.contains('"세계수 기능"'),"world-tree actions retained")
	check(ui.contains('"돌아가기"'),"scene can be dismissed unfinished")
	check(ui.contains('session.get_story_event(MonsterHunterEntry.EVENT_ID).status=="seen"'),"startup only reopens already discovered hunter")
	check(ui.contains('func advance_monster_hunter(index: int, shown_beat: int) -> void:'),"guarded final close callback")
	check(ui.contains('if finishing:'),"successful final closes story only after saved confirmation")

func _run() -> void:
	verify_source()
	run_full(false)
	run_full(true)
	test_io_failure()
	test_fail_closed()
	test_ui()
	for p in paths: clear(p)
	print("MONSTER_HUNTER_DIALOGUE_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
