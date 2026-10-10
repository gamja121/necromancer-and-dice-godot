extends SceneTree
## P1-05E: hunter first-arrival gating and atomic discovery only.
const SessionScript = preload("res://systems/run_session.gd")
const Grave = preload("res://systems/story_event_entry.gd")
const Rumor = preload("res://systems/village_rumor_entry.gd")
const RumorBeats = preload("res://systems/village_rumor_beats.gd")
const Commander = preload("res://systems/knight_commander_entry.gd")
const CommanderBeats = preload("res://systems/knight_commander_beats.gd")
const Hunter = preload("res://systems/monster_hunter_entry.gd")

class BattleResult:
	extends RefCounted
	var result: String
	var units: Array=[]
	func _init(value: String) -> void: result=value
	func winner() -> String: return result
	func find_id(_id: String) -> Dictionary: return {}

var passed: int=0
var failed: int=0
var paths: Array[String]=[]

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, name: String) -> void:
	if ok:
		passed+=1
		print("PASS hunter-entry: ",name)
	else:
		failed+=1
		printerr("FAIL hunter-entry: ",name)

func clear(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func fresh(suffix: String):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://hunter_entry_%d_%s.json" % [OS.get_process_id(),suffix]
	paths.append(path)
	clear(path)
	s.save_file_path=path
	s.start_new_world()
	return s

func resolve_graveyard(s, rescued: bool) -> void:
	var idx: int=s.world.tiles.find("graveyard")
	check(idx>=0,"original graveyard tile exists")
	s.world.position=idx
	check(Grave.begin(s,idx),"discover child story")
	if rescued:
		check(Grave.choose(s,idx,"protect_child"),"protect child chosen")
		check(s.start_story_encounter(Grave.EVENT_ID,idx,[s.world.roster[0].id]),"ghoul combat checkpoint")
		check(s.finish_encounter(BattleResult.new("ally")),"ghoul combat success")
		check(s.acknowledge_graveyard_battle_result(),"child rescue result acknowledged")
	else:
		check(Grave.choose(s,idx,"leave"),"child abandoned")

func finish_rumor(s, rescued: bool) -> void:
	var idx: int=s.world.tiles.find("village")
	s.world.position=idx
	var id: String=Rumor.RESCUED_ID if rescued else Rumor.ABANDONED_ID
	check(Rumor.begin(s,idx)==id,"correct child rumor started")
	for i in range(RumorBeats.count(id)):
		check(Rumor.advance(s,idx,id,i),"rumor scene persisted "+str(i))
	check(s.get_story_event(id).status=="complete","rumor completed before commander")

func finish_commander(s) -> void:
	var idx: int=s.world.tiles.find("village")
	s.world.position=idx
	check(Commander.begin(s,idx),"commander meeting begins")
	for i in range(CommanderBeats.count()):
		check(Commander.advance(s,idx,i),"commander scene persisted "+str(i))
	check(s.get_story_event(Commander.EVENT_ID).status=="complete","commander story finished")
	check(s.event_flag_is_set(Commander.RECOGNIZED_FLAG),"commander recognition saved")
	check(s.event_flag_is_set(Commander.QUEST_ACTIVE_FLAG),"hunter quest active")

func test_worldtree_or_event(wildcard: bool) -> void:
	var s=fresh("event" if wildcard else "tree")
	resolve_graveyard(s,true)
	finish_rumor(s,true)
	var tree: int=s.world.tiles.find("unknown")
	check(tree>=0,"world tree exists")
	s.world.position=tree
	check(not Hunter.can_enter(s,tree),"hunter inaccessible before commander")
	check(not Hunter.begin(s,tree),"cannot discover hunter before commander quest")
	finish_commander(s)
	var idx: int=s.world.tiles.find("event") if wildcard else tree
	check(idx>=0,"encounter tile exists")
	s.world.position=idx
	var before: Dictionary=s.world.snapshot().duplicate(true)
	check(Hunter.can_enter(s,idx),"active quest permits hunter on correct tile")
	check(not Hunter.can_enter(s,idx+1),"noncurrent tile cannot trigger hunter")
	check(not Hunter.begin(s,idx+1),"remote tile cannot save encounter")
	check(s.world.snapshot()==before,"failed remote trigger cannot change world")
	check(Hunter.begin(s,idx),"first hunter seen save succeeds")
	check(s.get_story_event(Hunter.EVENT_ID).status=="seen","hunter first encounter only seen")
	check(s.event_flag_is_set(Hunter.SEEN_FLAG),"web compatible seen flag persisted")
	check(s.get_story_event(Hunter.EVENT_ID).choice.is_empty(),"no fake hunter choice")
	check(s.get_story_event(Hunter.EVENT_ID).battle_result.is_empty(),"no fake fight outcome")
	check(not s.event_flag_is_set(Hunter.COMPLETE_FLAG),"hunter event not completed prematurely")
	check(s.event_flag_is_set(Hunter.QUEST_ACTIVE_FLAG),"investigation quest remains active")
	check(not s.event_flag_is_set(Hunter.QUEST_COMPLETE_FLAG),"quest not completed by arrival")
	check(not s.event_flag_is_set(Hunter.CULTIST_CLUE_FLAG),"no human clue granted before dialogue")
	var saved: Dictionary=s.world.snapshot().duplicate(true)
	check(Hunter.begin(s,idx),"reopening seen hunter is allowed")
	check(s.world.snapshot()==saved,"repeat discovery leaves save unchanged")
	s.reload_world()
	check(s.world.position==idx,"reload returns to original event location")
	check(s.get_story_event(Hunter.EVENT_ID).status=="seen","seen state survives restart")
	check(s.event_flag_is_set(Hunter.SEEN_FLAG),"seen flag survives restart")
	check(Hunter.can_enter(s,idx),"uncompleted first scene resumes")
	check(Hunter.begin(s,idx),"reloaded first scene opens without re-saving")
	check(not s.event_flag_is_set(Hunter.COMPLETE_FLAG),"reload does not consume story")
	s.free()

func test_abandoned_route() -> void:
	var s=fresh("abandoned")
	resolve_graveyard(s,false)
	finish_rumor(s,false)
	var idx: int=s.world.tiles.find("unknown")
	s.world.position=idx
	check(not Hunter.can_enter(s,idx),"abandoned route has no hunter eligibility")
	check(not Hunter.begin(s,idx),"abandoned route cannot save hunter seen")
	check(s.get_story_event(Hunter.EVENT_ID).status=="unseen","hunter untouched on abandoned route")
	s.free()

func test_failclosed_flags() -> void:
	var s=fresh("flags")
	resolve_graveyard(s,true)
	finish_rumor(s,true)
	finish_commander(s)
	var idx: int=s.world.tiles.find("unknown")
	s.world.position=idx
	check(Hunter.can_enter(s,idx),"baseline quest and commander valid")
	check(not Hunter.can_enter(s,-1),"negative tile index rejected")
	check(not Hunter.can_enter(s,s.world.tiles.size()),"oversized index rejected")
	s.world.tiles[idx]="forest"
	check(not Hunter.can_enter(s,idx),"forest tile cannot launch hunter")
	s.world.tiles[idx]="unknown"
	s.world.pending_move={"testing":true}
	check(not Hunter.can_enter(s,idx),"pending movement blocks hunter")
	s.world.pending_move={}
	s.world.pending_reward={"kind":"treasure"}
	check(not Hunter.can_enter(s,idx),"pending reward blocks hunter")
	s.world.pending_reward={}
	s.encounter={"testing":true}
	check(not Hunter.can_enter(s,idx),"running battle blocks hunter")
	s.encounter={}
	s.world.active_encounter={"testing":true}
	check(not Hunter.can_enter(s,idx),"persisted battle blocks hunter")
	s.world.active_encounter={}
	s.world.event_flags[Hunter.QUEST_ACTIVE_FLAG]=false
	check(not Hunter.can_enter(s,idx),"inactive quest blocks hunter")
	s.world.event_flags[Hunter.QUEST_ACTIVE_FLAG]=true
	s.world.event_flags[Hunter.QUEST_COMPLETE_FLAG]=true
	check(not Hunter.can_enter(s,idx),"already completed quest blocks new hunter")
	s.world.event_flags[Hunter.QUEST_COMPLETE_FLAG]=false
	s.world.event_flags[Hunter.COMPLETE_FLAG]=true
	check(not Hunter.can_enter(s,idx),"already consumed hunter event blocked")
	s.world.event_flags[Hunter.COMPLETE_FLAG]=false
	s.world.event_flags[Hunter.CULTIST_CLUE_FLAG]=true
	check(not Hunter.can_enter(s,idx),"premature human clue blocks earlier scene")
	s.world.event_flags[Hunter.CULTIST_CLUE_FLAG]=false
	s.world.event_flags[Hunter.RECOGNITION_FLAG]=false
	check(not Hunter.can_enter(s,idx),"missing commander recognition rejected")
	s.world.event_flags[Hunter.RECOGNITION_FLAG]=true
	s.world.event_flags[Hunter.COMMANDER_COMPLETE_FLAG]=false
	check(not Hunter.can_enter(s,idx),"missing commander completion flag rejected")
	s.world.event_flags[Hunter.COMMANDER_COMPLETE_FLAG]=true
	s.world.story_events[Hunter.COMMANDER_ID].status="seen"
	check(not Hunter.can_enter(s,idx),"unfinished commander story rejected")
	s.world.story_events[Hunter.COMMANDER_ID].status="complete"
	s.world.event_flags[Hunter.SEEN_FLAG]=true
	check(not Hunter.can_enter(s,idx),"stray seen flag on unseen hunter rejected")
	s.world.event_flags.erase(Hunter.SEEN_FLAG)
	s.world.story_events[Hunter.EVENT_ID]={"status":"seen","choice":"","battle_result":""}
	check(not Hunter.can_enter(s,idx),"seen story missing seen flag rejected")
	s.world.story_events.erase(Hunter.EVENT_ID)
	check(Hunter.can_enter(s,idx),"valid prerequisites restore eligibility")
	s.free()

func test_failed_write() -> void:
	var s=fresh("rollback")
	resolve_graveyard(s,true)
	finish_rumor(s,true)
	finish_commander(s)
	var idx: int=s.world.tiles.find("unknown")
	s.world.position=idx
	var previous: Dictionary=s.world.snapshot().duplicate(true)
	var old_path: String=s.save_file_path
	s.save_file_path="user://hunter_entry_missing_folder_%d/blocked.json" % OS.get_process_id()
	check(not Hunter.begin(s,idx),"hunter discovery I/O failure propagates")
	check(s.world.snapshot()==previous,"failed hunter discovery fully rolls back")
	check(not s.event_flag_is_set(Hunter.SEEN_FLAG),"failed write does not set seen flag")
	check(s.get_story_event(Hunter.EVENT_ID).status=="unseen","failed write leaves event unseen")
	s.save_file_path=old_path
	check(Hunter.begin(s,idx),"retry after restoring storage works")
	s.reload_world()
	check(s.get_story_event(Hunter.EVENT_ID).status=="seen","retry survives restart")
	s.free()

func test_art_ui() -> void:
	check(Hunter.EVENT_ID=="monster_hunter_encounter_01","canonical hunter event identity")
	check(Hunter.FIRST_BEAT.id=="arrival","source opening beat identity")
	check(Hunter.FIRST_BEAT.effect=="세계수 성역 안쪽. 오래된 성역 사이로 불길한 오염의 흔적이 이어져 있다.","source arrival exact")
	check(Hunter.FIRST_BEAT.dialogue.is_empty(),"opening has no hunter dialogue")
	check(Hunter.FIRST_BEAT.visual=="base","opening shows base scene only")
	check(ResourceLoader.exists(Hunter.BASE_ART),"original world-tree hunter background bundled")
	check(ResourceLoader.exists(Hunter.SCENE_ART),"future corrupted beast scene available")
	check(ResourceLoader.exists(Hunter.PORTRAIT_ART),"future hunter portrait available")
	var map: String=FileAccess.get_file_as_string("res://map.gd")
	check(map.contains("MonsterHunterEntry.can_enter(session,index)"),"map dispatch eligibility wired")
	check(map.contains("MonsterHunterEntry.begin(session,index)"),"map saves hunter before displaying")
	check(map.contains('func show_monster_hunter_intro(index: int) -> void:'),"hunter first scene UI exists")
	check(map.contains('str(MonsterHunterEntry.FIRST_BEAT.effect)'),"map renders original narration")
	check(map.contains("MonsterHunterEntry.BASE_ART"),"original background drawn")
	check(map.contains('session.get_story_event(MonsterHunterEntry.EVENT_ID).status=="seen"'),"reload only reopens seen hunter")
	check(map.contains('world.tiles[world.position] in ["village","unknown","event"]'),"world tree startup can resume")
	check(map.contains('"세계수 기능"'),"world-tree location actions retained")
	check(map.contains('"돌아가기"'),"hunter scene has exit")
	var grave: int=map.find("StoryEventEntry.can_enter(session,index)")
	var rumor: int=map.find("VillageRumorEntry.eligible_event_id(session,index)")
	var commander: int=map.find("KnightCommanderEntry.can_enter(session,index)")
	var hunter: int=map.find("MonsterHunterEntry.can_enter(session,index)")
	check(grave>=0 and grave<rumor and rumor<commander and commander<hunter,"wildcard priority does not skip earlier events")

func _run() -> void:
	test_worldtree_or_event(false)
	test_worldtree_or_event(true)
	test_abandoned_route()
	test_failclosed_flags()
	test_failed_write()
	test_art_ui()
	for path in paths: clear(path)
	print("MONSTER_HUNTER_ENTRY_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
