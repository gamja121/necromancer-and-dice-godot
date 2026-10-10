extends SceneTree
## P1-05C: first knight commander landing only, independent of later quest.
const SessionScript=preload("res://systems/run_session.gd")
const Grave=preload("res://systems/story_event_entry.gd")
const Rumor=preload("res://systems/village_rumor_entry.gd")
const Beats=preload("res://systems/village_rumor_beats.gd")
const Commander=preload("res://systems/knight_commander_entry.gd")

class Result:
	extends RefCounted
	var outcome: String
	var units: Array=[]
	func _init(value: String) -> void: outcome=value
	func winner() -> String: return outcome
	func find_id(_id: String) -> Dictionary: return {}

var passed: int=0
var failed: int=0
var paths: Array[String]=[]

func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	if value:
		passed+=1
		print("PASS knight-entry: ",label)
	else:
		failed+=1
		printerr("FAIL knight-entry: ",label)

func clean(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func fresh(label: String):
	var s=SessionScript.new()
	root.add_child(s)
	var path="user://knight_entry_%d_%s.json" % [OS.get_process_id(),label]
	paths.append(path)
	clean(path)
	s.save_file_path=path
	s.start_new_world()
	return s

func resolve_child(s, rescue: bool) -> void:
	var idx: int=s.world.tiles.find("graveyard")
	check(idx>=0,"graveyard tile available")
	s.world.position=idx
	check(Grave.begin(s,idx),"graveyard discovery committed")
	if rescue:
		check(Grave.choose(s,idx,"protect_child"),"rescue chosen")
		check(s.start_story_encounter(Grave.EVENT_ID,idx,[s.world.roster[0].id]),"real story fight begins")
		check(s.finish_encounter(Result.new("ally")),"real victory marks rescued")
		check(s.acknowledge_graveyard_battle_result(),"postbattle result acknowledged")
	else:
		check(Grave.choose(s,idx,"leave"),"abandon child committed")

func start_rumor(s, rescue: bool) -> int:
	var idx: int=s.world.tiles.find("village")
	check(idx>=0,"village tile available")
	s.world.position=idx
	var rumor_id: String=Rumor.RESCUED_ID if rescue else Rumor.ABANDONED_ID
	check(Rumor.begin(s,idx)==rumor_id,"correct rumor discovered")
	return idx

func finish_rumor(s, rescue: bool, idx: int) -> void:
	var rumor_id: String=Rumor.RESCUED_ID if rescue else Rumor.ABANDONED_ID
	for beat_index in range(Beats.count(rumor_id)):
		check(Rumor.advance(s,idx,rumor_id,beat_index),"rumor beat confirmed "+str(beat_index))
	check(s.get_story_event(rumor_id).status=="complete","rumor fully completed")
	check(s.event_flag_is_set(Rumor.complete_flag(rumor_id)),"rumor completion flag saved")

func test_valid_entry(rescue: bool, event_tile: bool) -> void:
	var label: String=("win" if rescue else "leave")+("_event" if event_tile else "_village")
	var s=fresh(label)
	resolve_child(s,rescue)
	var village: int=start_rumor(s,rescue)
	check(not Commander.can_enter(s,village),"commander blocked when rumor only seen")
	finish_rumor(s,rescue,village)
	var idx: int=village
	if event_tile:
		idx=s.world.tiles.find("event")
		check(idx>=0,"generic event tile available")
		s.world.position=idx
	var before: Dictionary=s.world.snapshot().duplicate(true)
	if rescue:
		check(Commander.can_enter(s,idx),"rescued rumor completion enables commander")
		check(Commander.begin(s,idx),"first encounter persisted")
		check(s.get_story_event(Commander.EVENT_ID).status=="seen","commander status is seen")
		check(s.get_story_event(Commander.EVENT_ID).choice.is_empty(),"no fake choice")
		check(s.get_story_event(Commander.EVENT_ID).battle_result.is_empty(),"no fake battle")
		check(s.event_flag_is_set(Commander.SEEN_FLAG),"web compatible seen marker saved")
		check(not s.event_flag_is_set(Commander.COMPLETE_FLAG),"arrival not completed")
		check(not s.event_flag_is_set(Commander.RECOGNIZED_FLAG),"recognition not prematurely granted")
		check(not s.event_flag_is_set(Commander.QUEST_ACTIVE_FLAG),"hunter quest not prematurely active")
		check(not s.event_flag_is_set(Commander.QUEST_COMPLETE_FLAG),"hunter quest not completed")
		var after: Dictionary=s.world.snapshot().duplicate(true)
		check(Commander.begin(s,idx),"reopening is idempotent")
		check(s.world.snapshot()==after,"reopening does not rewrite state")
		s.reload_world()
		check(s.world.position==idx,"save reload restores arrival location")
		check(s.get_story_event(Commander.EVENT_ID).status=="seen","save reload retains commander seen status")
		check(s.event_flag_is_set(Commander.SEEN_FLAG),"save reload retains commander seen flag")
		check(Commander.can_enter(s,idx),"existing seen commander can reopen")
		check(Commander.begin(s,idx),"reload can reopen first scene")
		check(not s.event_flag_is_set(Commander.QUEST_ACTIVE_FLAG),"reopened scene does not grant quest")
		var off: int=s.world.tiles.find("forest")
		check(not Commander.can_enter(s,off),"preview of distant tile forbidden")
		check(not Commander.begin(s,off),"distant tile cannot save first encounter")
	else:
		check(not Commander.can_enter(s,idx),"abandoned branch never triggers knight")
		check(not Commander.begin(s,idx),"abandoned branch cannot mark knight seen")
		check(s.world.snapshot()==before,"abandoned attempt does not alter save")
		check(s.get_story_event(Commander.EVENT_ID).status=="unseen","abandoned branch knight remains unseen")
		check(not s.event_flag_is_set(Commander.SEEN_FLAG),"abandoned branch flag absent")
		s.reload_world()
		check(not Commander.can_enter(s,idx),"abandon remains blocked after reload")
	s.free()

func test_failed_save() -> void:
	var s=fresh("rollback")
	resolve_child(s,true)
	var village: int=start_rumor(s,true)
	finish_rumor(s,true,village)
	var before: Dictionary=s.world.snapshot().duplicate(true)
	var original: String=s.save_file_path
	s.save_file_path="user://knight_entry_missing_dir_%d/blocked.json" % OS.get_process_id()
	check(not Commander.begin(s,village),"unwritable commander discovery fails")
	check(s.world.snapshot()==before,"failed save reverts entire event state")
	check(not s.event_flag_is_set(Commander.SEEN_FLAG),"failed save leaves no seen marker")
	check(s.get_story_event(Commander.EVENT_ID).status=="unseen","failed save leaves status unseen")
	s.save_file_path=original
	check(Commander.begin(s,village),"retry after disk recovery saves encounter")
	s.reload_world()
	check(s.get_story_event(Commander.EVENT_ID).status=="seen","saved retry survives reload")
	s.free()

func test_blockers() -> void:
	var s=fresh("blockers")
	resolve_child(s,true)
	var idx: int=start_rumor(s,true)
	finish_rumor(s,true,idx)
	check(Commander.can_enter(s,idx),"valid commander baseline")
	check(not Commander.can_enter(s,-1),"negative tile cannot trigger")
	check(not Commander.can_enter(s,s.world.tiles.size()),"out-of-bounds tile cannot trigger")
	var previous: String=s.world.tiles[idx]
	s.world.tiles[idx]="forest"
	check(not Commander.can_enter(s,idx),"forest does not host commander")
	s.world.tiles[idx]=previous
	s.world.pending_move={"testing":true}
	check(not Commander.can_enter(s,idx),"pending move blocks event")
	s.world.pending_move={}
	s.world.pending_reward={"kind":"test"}
	check(not Commander.can_enter(s,idx),"pending reward blocks event")
	s.world.pending_reward={}
	s.encounter={"testing":true}
	check(not Commander.can_enter(s,idx),"live battle blocks event")
	s.encounter={}
	s.world.active_encounter={"testing":true}
	check(not Commander.can_enter(s,idx),"persisted encounter blocks event")
	s.world.active_encounter={}
	s.world.event_flags["story:graveyard_child_ambush_01:result_pending"]=true
	check(not Commander.can_enter(s,idx),"unacknowledged prior result blocks event")
	s.world.event_flags.erase("story:graveyard_child_ambush_01:result_pending")
	s.world.event_flags[Commander.QUEST_ACTIVE_FLAG]=true
	check(not Commander.can_enter(s,idx),"already active hunter quest prevents retroactive event")
	s.world.event_flags.erase(Commander.QUEST_ACTIVE_FLAG)
	s.world.event_flags[Commander.QUEST_COMPLETE_FLAG]=true
	check(not Commander.can_enter(s,idx),"completed hunter quest prevents event")
	s.world.event_flags.erase(Commander.QUEST_COMPLETE_FLAG)
	s.world.event_flags[Commander.RECOGNIZED_FLAG]=true
	check(not Commander.can_enter(s,idx),"already recognized commander not reintroduced")
	s.world.event_flags.erase(Commander.RECOGNIZED_FLAG)
	s.world.event_flags[Commander.COMPLETE_FLAG]=true
	check(not Commander.can_enter(s,idx),"complete marker prevents repeat")
	s.world.event_flags.erase(Commander.COMPLETE_FLAG)
	s.world.event_flags[Rumor.complete_flag(Rumor.RESCUED_ID)]=false
	check(not Commander.can_enter(s,idx),"rumor complete flag must be true")
	s.world.event_flags[Rumor.complete_flag(Rumor.RESCUED_ID)]=true
	s.world.story_events[Rumor.RESCUED_ID].status="seen"
	check(not Commander.can_enter(s,idx),"rumor must actually be complete")
	s.world.story_events[Rumor.RESCUED_ID].status="complete"
	s.world.event_flags[Commander.SEEN_FLAG]=true
	check(not Commander.can_enter(s,idx),"stray commander seen flag with unseen story rejected")
	s.world.event_flags.erase(Commander.SEEN_FLAG)
	s.world.event_flags[Commander.RESCUED_FLAG]=false
	check(not Commander.can_enter(s,idx),"missing real rescue flag rejected")
	s.world.event_flags[Commander.RESCUED_FLAG]=true
	s.world.event_flags[Commander.ABANDONED_FLAG]=true
	check(not Commander.can_enter(s,idx),"contradictory rescue and abandon flag rejected")
	s.world.event_flags[Commander.ABANDONED_FLAG]=false
	check(Commander.can_enter(s,idx),"fully valid prerequisites allow entry again")
	s.free()

func inspect_ui_and_asset() -> void:
	check(Commander.EVENT_ID=="knight_commander_contamination_01","canonical source event ID")
	check(Commander.FIRST_BEAT.effect=="길목에서 무장한 기사가 당신을 기다리고 있었다.","original first narration exact")
	check(Commander.FIRST_BEAT.dialogue=="여기 있었구만.","original opening dialogue exact")
	check(Commander.FIRST_BEAT.speaker=="기사단장","canonical source speaker")
	check(ResourceLoader.exists(Commander.ART),"original day village artwork exists")
	check(ResourceLoader.exists(Commander.PORTRAIT),"original HD commander fallback portrait exists")
	var ui: String=FileAccess.get_file_as_string("res://map.gd")
	check(ui.contains('KnightCommanderEntry.can_enter(session,index)'),"map routes through commander eligibility")
	check(ui.contains('KnightCommanderEntry.begin(session,index)'),"map only presents after durable seen save")
	check(ui.contains('func show_knight_commander_intro(index: int) -> void:'),"commander event modal exists")
	check(ui.contains('str(KnightCommanderEntry.FIRST_BEAT.dialogue)'),"original spoken line rendered")
	check(ui.contains('KnightCommanderEntry.PORTRAIT'),"commander portrait shown separately")
	check(ui.contains('session.get_story_event(KnightCommanderEntry.EVENT_ID).status=="seen"'),"only previously seen first scene auto-resumes")
	check(ui.contains('"마을 기능"'),"original village actions remain accessible")
	check(ui.contains('"돌아가기"'),"player can close unfinished scene")
	var grave: int=ui.find('StoryEventEntry.can_enter(session,index)')
	var rumor: int=ui.find('VillageRumorEntry.eligible_event_id(session,index)')
	var knight: int=ui.find('KnightCommanderEntry.can_enter(session,index)')
	check(grave>=0 and rumor>grave and knight>rumor,"event tile priority preserved")

func _run() -> void:
	test_valid_entry(true,false)
	test_valid_entry(true,true)
	test_valid_entry(false,false)
	test_valid_entry(false,true)
	test_failed_save()
	test_blockers()
	inspect_ui_and_asset()
	for path in paths: clean(path)
	print("KNIGHT_COMMANDER_ENTRY_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
