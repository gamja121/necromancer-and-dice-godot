extends SceneTree
## P1-05A: safely discover either village rumor, but do not finish it.
const SessionScript=preload("res://systems/run_session.gd")
const Child=preload("res://systems/story_event_entry.gd")
const Rumor=preload("res://systems/village_rumor_entry.gd")

class Result:
	extends RefCounted
	var outcome: String
	var units: Array=[]
	func _init(value: String) -> void: outcome=value
	func winner() -> String: return outcome
	func find_id(_id: String) -> Dictionary: return {}

var passed: int=0
var failed: int=0
var files: Array[String]=[]

func _initialize() -> void: call_deferred("_run")

func check(value: bool, label: String) -> void:
	if value:
		passed+=1
		print("PASS village-rumor: ",label)
	else:
		failed+=1
		printerr("FAIL village-rumor: ",label)

func cleanup(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func create(suffix: String):
	var s=SessionScript.new()
	root.add_child(s)
	var path="user://village_rumor_%d_%s.json" % [OS.get_process_id(),suffix]
	files.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	check(s.has_save(),"disposable save exists")
	return s

func resolve_child(s, rescued: bool) -> void:
	var index: int=s.world.tiles.find("graveyard")
	check(index>=0,"graveyard tile exists")
	s.world.position=index
	check(Child.begin(s,index),"child discovery")
	if rescued:
		check(Child.choose(s,index,"protect_child"),"child protection chosen")
		check(s.start_story_encounter(Child.EVENT_ID,index,[s.world.roster[0].id]),"real ghoul encounter starts")
		check(s.finish_encounter(Result.new("ally")),"ghoul victory resolves")
		check(s.event_flag_is_set("event:graveyard_child_ambush_01:rescued"),"child rescue is durable")
	else:
		check(Child.choose(s,index,"leave"),"child abandonment resolves")
		check(s.event_flag_is_set("event:graveyard_child_ambush_01:abandoned"),"abandon flag is durable")

func visit_village(s) -> int:
	var idx: int=s.world.tiles.find("village")
	check(idx>=0,"village tile exists")
	s.world.position=idx
	return idx

func scenario(rescued: bool) -> void:
	var s=create("rescued" if rescued else "abandoned")
	resolve_child(s,rescued)
	var idx: int=visit_village(s)
	var chosen: String=Rumor.RESCUED_ID if rescued else Rumor.ABANDONED_ID
	var opposite: String=Rumor.ABANDONED_ID if rescued else Rumor.RESCUED_ID
	if rescued:
		check(Rumor.eligible_event_id(s,idx).is_empty(),"unacknowledged rescue result blocks rumors")
		check(s.acknowledge_graveyard_battle_result(),"victory result must be acknowledged")
	check(Rumor.eligible_event_id(s,idx)==chosen,"only matching rumor selected")
	check(Rumor.begin(s,idx)==chosen,"matching rumor discovery persisted")
	check(s.get_story_event(chosen).status=="seen","rumor remains seen, not completed")
	check(s.get_story_event(chosen).choice.is_empty(),"rumor has no fake choice")
	check(s.get_story_event(chosen).battle_result.is_empty(),"rumor has no fake battle outcome")
	check(s.event_flag_is_set(Rumor.seen_flag(chosen)),"web compatible seen flag stored")
	check(not s.event_flag_is_set(Rumor.complete_flag(chosen)),"rumor completion remains false")
	check(s.get_story_event(opposite).status=="unseen","other branch remains unseen")
	check(not s.event_flag_is_set(Rumor.seen_flag(opposite)),"other branch does not save seen marker")
	check(not s.event_flag_is_set(Rumor.complete_flag(opposite)),"other branch remains incomplete")
	var before: Dictionary=s.world.snapshot().duplicate(true)
	check(Rumor.begin(s,idx)==chosen,"reopening intro is idempotent")
	check(s.world.snapshot()==before,"reopening does not rewrite story state")
	s.reload_world()
	check(s.world.position==idx,"scene location preserved after reload")
	check(s.get_story_event(chosen).status=="seen","unfinished rumor reloads")
	check(s.event_flag_is_set(Rumor.seen_flag(chosen)),"seen flag reloads")
	check(Rumor.eligible_event_id(s,idx)==chosen,"uncompleted rumor can resume at village")
	check(Rumor.begin(s,idx)==chosen,"reload intro reopens")
	s.free()

func untriggered_and_wildcard() -> void:
	var s=create("gates")
	var village: int=visit_village(s)
	check(Rumor.eligible_event_id(s,village).is_empty(),"no rumor before child resolved")
	check(Rumor.begin(s,village).is_empty(),"cannot mark unseen rumor early")
	resolve_child(s,false)
	var original: int=s.world.position
	check(Rumor.eligible_event_id(s,village).is_empty(),"preview another tile cannot trigger")
	s.world.position=village
	check(Rumor.eligible_event_id(s,village)==Rumor.ABANDONED_ID,"abandoned rumor is pending at village")
	check(Rumor.eligible_event_id(s,-1).is_empty(),"negative index rejected")
	check(Rumor.eligible_event_id(s,s.world.tiles.size()).is_empty(),"out of bounds index rejected")
	var old: String=s.world.tiles[village]
	s.world.tiles[village]="forest"
	check(Rumor.eligible_event_id(s,village).is_empty(),"forest cannot launch village rumor")
	s.world.tiles[village]=old
	var event_tile: int=s.world.tiles.find("event")
	check(event_tile>=0,"generic event tile exists")
	if event_tile>=0:
		s.world.position=event_tile
		check(Rumor.eligible_event_id(s,event_tile)==Rumor.ABANDONED_ID,"generic event tile is wildcard alternate")
		check(Rumor.begin(s,event_tile)==Rumor.ABANDONED_ID,"generic event landing saves rumor")
		check(s.get_story_event(Rumor.ABANDONED_ID).status=="seen","wildcard leaves event unfinished")
	s.free()

func blocked_guards() -> void:
	var s=create("blockers")
	resolve_child(s,false)
	var village: int=visit_village(s)
	s.world.pending_move={"testing":true}
	check(Rumor.eligible_event_id(s,village).is_empty(),"pending map move blocks discovery")
	s.world.pending_move={}
	s.world.pending_reward={"kind":"treasure"}
	check(Rumor.eligible_event_id(s,village).is_empty(),"pending reward blocks discovery")
	s.world.pending_reward={}
	s.encounter={"testing":true}
	check(Rumor.eligible_event_id(s,village).is_empty(),"active local encounter blocks discovery")
	s.encounter={}
	s.world.active_encounter={"testing":true}
	check(Rumor.eligible_event_id(s,village).is_empty(),"persisted encounter blocks discovery")
	s.world.active_encounter={}
	s.world.event_flags["story:graveyard_child_ambush_01:result_pending"]=true
	check(Rumor.eligible_event_id(s,village).is_empty(),"unacknowledged result flag blocks discovery")
	s.world.event_flags.erase("story:graveyard_child_ambush_01:result_pending")
	s.world.event_flags["event:graveyard_child_ambush_01:rescued"]=true
	check(Rumor.eligible_event_id(s,village).is_empty(),"contradictory rescue/abandon outcome blocks rumor")
	s.world.event_flags.erase("event:graveyard_child_ambush_01:rescued")
	check(Rumor.eligible_event_id(s,village)==Rumor.ABANDONED_ID,"consistent branch remains eligible")
	s.world.story_events[Child.EVENT_ID].status="seen"
	check(Rumor.eligible_event_id(s,village).is_empty(),"unfinished graveyard event blocks rumor")
	s.world.story_events[Child.EVENT_ID].status="complete"
	s.world.event_flags["event:graveyard_child_ambush_01:complete"]=false
	check(Rumor.eligible_event_id(s,village).is_empty(),"graveyard complete flag required")
	s.free()

func rollback_and_consumption() -> void:
	var s=create("rollback")
	resolve_child(s,false)
	var index: int=visit_village(s)
	var before: Dictionary=s.world.snapshot().duplicate(true)
	var good_path: String=s.save_file_path
	s.save_file_path="user://village_rumor_missing_%d/no.json" % OS.get_process_id()
	check(Rumor.begin(s,index).is_empty(),"unwritable rumor discovery rejected")
	check(s.world.snapshot()==before,"failed rumor saves do not consume it")
	check(not s.event_flag_is_set(Rumor.seen_flag(Rumor.ABANDONED_ID)),"failed save leaves no seen marker")
	s.save_file_path=good_path
	check(Rumor.begin(s,index)==Rumor.ABANDONED_ID,"retry after save recovery succeeds")
	s.world.event_flags[Rumor.complete_flag(Rumor.ABANDONED_ID)]=true
	check(Rumor.eligible_event_id(s,index).is_empty(),"completed rumor cannot replay")
	check(Rumor.begin(s,index).is_empty(),"consumed rumor cannot be started")
	s.free()

func inspect_ui() -> void:
	var src: String=FileAccess.get_file_as_string("res://map.gd")
	check(src.contains("VillageRumorEntry.eligible_event_id(session,index)"),"map dispatch checks pending village rumor")
	check(src.contains("VillageRumorEntry.begin(session,index)"),"map atomically persists first rumor seen")
	check(src.contains("func show_village_rumor_intro(index: int, event_id: String) -> void:"),"village intro scene exists")
	check(src.find("StoryEventEntry.can_enter(session,index)")<src.find("VillageRumorEntry.eligible_event_id(session,index)"),"graveyard event dispatch keeps priority")
	check(ResourceLoader.exists(Rumor.SCENE_ART),"original village background exists")
	check(Rumor.INTRO[Rumor.RESCUED_ID].begins_with("마을에 들어서자"),"original rescue rumor first beat")
	check(Rumor.INTRO[Rumor.ABANDONED_ID].begins_with("마을 어귀에 들어서자"),"original abandon rumor first beat")
	check(src.contains('"마을 기능"'),"existing village features remain accessible")
	check(src.contains('"돌아가기"'),"player can exit unfinished intro")
	check(Rumor.seen_flag("invalid").is_empty() and Rumor.complete_flag("invalid").is_empty(),"unrecognized flags rejected")

func _run() -> void:
	scenario(true)
	scenario(false)
	untriggered_and_wildcard()
	blocked_guards()
	rollback_and_consumption()
	inspect_ui()
	for path in files: cleanup(path)
	print("VILLAGE_RUMOR_ENTRY_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
