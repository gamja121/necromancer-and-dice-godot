extends SceneTree
## P1-05G: prove cultist rumor first arrival requires completed hunter clue.
const SessionScript=preload("res://systems/run_session.gd")
const Child=preload("res://systems/story_event_entry.gd")
const Rumor=preload("res://systems/village_rumor_entry.gd")
const RumorBeats=preload("res://systems/village_rumor_beats.gd")
const Commander=preload("res://systems/knight_commander_entry.gd")
const CommanderBeats=preload("res://systems/knight_commander_beats.gd")
const Hunter=preload("res://systems/monster_hunter_entry.gd")
const HunterBeats=preload("res://systems/monster_hunter_beats.gd")
const Cultist=preload("res://systems/cultist_rumor_entry.gd")

class Result:
	extends RefCounted
	var outcome: String
	var units: Array=[]
	func _init(winner_name: String) -> void: outcome=winner_name
	func winner() -> String: return outcome
	func find_id(_id: String) -> Dictionary: return {}

var passed: int=0
var failed: int=0
var paths: Array[String]=[]

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, what: String) -> void:
	if ok:
		passed+=1
		print("PASS cultist-rumor-entry: ",what)
	else:
		failed+=1
		printerr("FAIL cultist-rumor-entry: ",what)

func cleanup(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func make(suffix: String):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://cultist_rumor_entry_%d_%s.json" % [OS.get_process_id(),suffix]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	return s

func complete_rescue_and_commander(s) -> void:
	var grave: int=s.world.tiles.find("graveyard")
	s.world.position=grave
	check(Child.begin(s,grave),"child encounter discovered")
	check(Child.choose(s,grave,"protect_child"),"rescue branch chosen")
	check(s.start_story_encounter(Child.EVENT_ID,grave,[s.world.roster[0].id]),"ghoul story combat created")
	check(s.finish_encounter(Result.new("ally")),"child rescue victory")
	check(s.acknowledge_graveyard_battle_result(),"rescue result confirmed")
	var village: int=s.world.tiles.find("village")
	s.world.position=village
	check(Rumor.begin(s,village)==Rumor.RESCUED_ID,"rescue rumor discovered")
	for i in range(RumorBeats.count(Rumor.RESCUED_ID)):
		check(Rumor.advance(s,village,Rumor.RESCUED_ID,i),"rescue rumor beat saved "+str(i))
	check(Commander.begin(s,village),"commander discovered")
	for i in range(CommanderBeats.count()):
		check(Commander.advance(s,village,i),"commander beat saved "+str(i))
	check(s.event_flag_is_set(Hunter.QUEST_ACTIVE_FLAG),"investigation quest now active")

func complete_hunter(s) -> void:
	var tree: int=s.world.tiles.find("unknown")
	s.world.position=tree
	check(Hunter.begin(s,tree),"hunter discovered at world tree")
	for i in range(HunterBeats.count()):
		check(Hunter.advance(s,tree,i),"hunter beat saved "+str(i))
	check(s.get_story_event(Hunter.EVENT_ID).status=="complete","hunter fully completed")
	check(s.event_flag_is_set(Hunter.QUEST_COMPLETE_FLAG),"investigation quest completed")
	check(s.event_flag_is_set(Hunter.CULTIST_CLUE_FLAG),"human involvement clue saved")
	check(not s.event_flag_is_set(Hunter.QUEST_ACTIVE_FLAG),"investigation no longer active")

func scenario(wildcard: bool) -> void:
	var s=make("event" if wildcard else "village")
	var village: int=s.world.tiles.find("village")
	var event_tile: int=s.world.tiles.find("event")
	s.world.position=village
	check(not Cultist.can_enter(s,village),"unstarted story cannot show cultists")
	check(not Cultist.begin(s,village),"cannot record rumor before hunter")
	complete_rescue_and_commander(s)
	s.world.position=village
	check(not Cultist.can_enter(s,village),"commander quest alone not enough")
	complete_hunter(s)
	var idx: int=event_tile if wildcard else village
	check(idx>=0,"target cultist rumor tile exists")
	s.world.position=idx
	check(Cultist.can_enter(s,idx),"finished hunter unlocks actual tile")
	check(not Cultist.can_enter(s,-1),"negative index denied")
	check(not Cultist.can_enter(s,s.world.tiles.size()),"out of range denied")
	var other: int=village if wildcard else event_tile
	check(not Cultist.can_enter(s,other),"other tile cannot be preview-triggered")
	var before: Dictionary=s.world.snapshot().duplicate(true)
	check(not Cultist.begin(s,other),"remote tile discovery refused")
	check(s.world.snapshot()==before,"invalid discovery leaves world unchanged")
	check(Cultist.begin(s,idx),"first cultist rumor seen persisted")
	check(s.get_story_event(Cultist.EVENT_ID).status=="seen","cultist story remains seen")
	check(s.get_story_event(Cultist.EVENT_ID).choice.is_empty(),"no choice fabricated")
	check(s.get_story_event(Cultist.EVENT_ID).battle_result.is_empty(),"no fight fabricated")
	check(s.event_flag_is_set(Cultist.SEEN_FLAG),"source-compatible seen flag stored")
	check(not s.event_flag_is_set(Cultist.COMPLETE_FLAG),"rumor not completed yet")
	check(not s.event_flag_is_set(Cultist.TRACKING_FLAG),"tracking quest not prematurely granted")
	check(not s.event_flag_is_set(Cultist.KING_RUMOR_FLAG),"monster king rumor not prematurely granted")
	check(s.event_flag_is_set(Hunter.QUEST_COMPLETE_FLAG),"prior quest completion retained")
	var saved: Dictionary=s.world.snapshot().duplicate(true)
	check(Cultist.begin(s,idx),"reopening first scene idempotent")
	check(s.world.snapshot()==saved,"reopening does not resave")
	s.reload_world()
	check(s.world.position==idx,"location restored after restart")
	check(Cultist.can_enter(s,idx),"unfinished first scene still accessible")
	check(s.get_story_event(Cultist.EVENT_ID).status=="seen","seen status survives reload")
	check(s.event_flag_is_set(Cultist.SEEN_FLAG),"seen marker survives reload")
	check(Cultist.begin(s,idx),"reloaded scene can be opened")
	check(not s.event_flag_is_set(Cultist.COMPLETE_FLAG),"reload never marks complete")
	check(not s.event_flag_is_set(Cultist.TRACKING_FLAG),"reload does not activate tracking")
	s.free()

func invalid_conditions() -> void:
	var s=make("blockers")
	complete_rescue_and_commander(s)
	complete_hunter(s)
	var idx: int=s.world.tiles.find("village")
	s.world.position=idx
	check(Cultist.can_enter(s,idx),"baseline valid completed hunter route")
	s.world.pending_move={"test":true}
	check(not Cultist.can_enter(s,idx),"pending movement blocks rumor")
	s.world.pending_move={}
	s.world.pending_reward={"kind":"test"}
	check(not Cultist.can_enter(s,idx),"pending reward blocks rumor")
	s.world.pending_reward={}
	s.encounter={"test":true}
	check(not Cultist.can_enter(s,idx),"live combat blocks rumor")
	s.encounter={}
	s.world.active_encounter={"test":true}
	check(not Cultist.can_enter(s,idx),"persisted combat blocks rumor")
	s.world.active_encounter={}
	s.world.tiles[idx]="forest"
	check(not Cultist.can_enter(s,idx),"forest tile cannot trigger village rumor")
	s.world.tiles[idx]="village"
	s.world.event_flags[Cultist.HUNTER_COMPLETE_FLAG]=false
	check(not Cultist.can_enter(s,idx),"hunter event completion flag required")
	s.world.event_flags[Cultist.HUNTER_COMPLETE_FLAG]=true
	s.world.story_events[Cultist.HUNTER_ID].status="seen"
	check(not Cultist.can_enter(s,idx),"hunter story must actually be completed")
	s.world.story_events[Cultist.HUNTER_ID].status="complete"
	s.world.event_flags[Cultist.HUNTER_QUEST_COMPLETE_FLAG]=false
	check(not Cultist.can_enter(s,idx),"investigation quest completion required")
	s.world.event_flags[Cultist.HUNTER_QUEST_COMPLETE_FLAG]=true
	s.world.event_flags[Cultist.HUNTER_QUEST_ACTIVE_FLAG]=true
	check(not Cultist.can_enter(s,idx),"active investigation blocks cultist rumor")
	s.world.event_flags[Cultist.HUNTER_QUEST_ACTIVE_FLAG]=false
	s.world.event_flags[Cultist.HUMAN_CLUE_FLAG]=false
	check(not Cultist.can_enter(s,idx),"human involvement clue required")
	s.world.event_flags[Cultist.HUMAN_CLUE_FLAG]=true
	s.world.event_flags[Cultist.TRACKING_FLAG]=true
	check(not Cultist.can_enter(s,idx),"already active cultist tracking cannot regress")
	s.world.event_flags[Cultist.TRACKING_FLAG]=false
	s.world.event_flags[Cultist.KING_RUMOR_FLAG]=true
	check(not Cultist.can_enter(s,idx),"already known monster king rumor cannot regress")
	s.world.event_flags[Cultist.KING_RUMOR_FLAG]=false
	s.world.event_flags[Cultist.COMPLETE_FLAG]=true
	check(not Cultist.can_enter(s,idx),"completed cultist rumor cannot repeat")
	s.world.event_flags[Cultist.COMPLETE_FLAG]=false
	s.world.event_flags[Cultist.SEEN_FLAG]=true
	check(not Cultist.can_enter(s,idx),"stray seen flag cannot force unseen event")
	s.world.event_flags.erase(Cultist.SEEN_FLAG)
	s.world.story_events[Cultist.EVENT_ID]={"status":"seen","choice":"","battle_result":""}
	check(not Cultist.can_enter(s,idx),"missing seen flag cannot repeat saved seen event")
	s.world.story_events.erase(Cultist.EVENT_ID)
	check(Cultist.can_enter(s,idx),"consistent prerequisites recover first visit")
	s.free()

func rollback() -> void:
	var s=make("io")
	complete_rescue_and_commander(s)
	complete_hunter(s)
	var idx: int=s.world.tiles.find("village")
	s.world.position=idx
	var before: Dictionary=s.world.snapshot().duplicate(true)
	var good: String=s.save_file_path
	s.save_file_path="user://cultist_rumor_missing_%d/failed.json" % OS.get_process_id()
	check(not Cultist.begin(s,idx),"write failure prevents cultist discovery")
	check(s.world.snapshot()==before,"failed write rolls back every field")
	check(s.get_story_event(Cultist.EVENT_ID).status=="unseen","failed write keeps unseen event")
	check(not s.event_flag_is_set(Cultist.SEEN_FLAG),"failed write cannot set seen flag")
	s.save_file_path=good
	check(Cultist.begin(s,idx),"discovery succeeds after save recovery")
	s.reload_world()
	check(s.get_story_event(Cultist.EVENT_ID).status=="seen","successful retry survives reload")
	s.free()

func inspect_art_and_map() -> void:
	check(Cultist.EVENT_ID=="cultist_rumor_01","canonical source story id")
	check(Cultist.FIRST_BEAT.id=="arrival","exact opening beat id")
	check(Cultist.FIRST_BEAT.effect=="밤이 깊은 마을. 평소보다 일찍 문을 닫은 집들 사이로 인기척이 드물다.","opening source narration unchanged")
	check(Cultist.FIRST_BEAT.dialogue.is_empty(),"initial cultist rumor is silent")
	check(Cultist.FIRST_BEAT.visual=="base","opening shows only village base")
	check(ResourceLoader.exists(Cultist.BASE_ART),"existing original village base art exists")
	check(ResourceLoader.exists(Cultist.PROCESSION_ART),"following original cultist procession layer retained")
	var map: String=FileAccess.get_file_as_string("res://map.gd")
	check(map.contains("CultistRumorEntry.can_enter(session,index)"),"map checks eligible cultist story")
	check(map.contains("CultistRumorEntry.begin(session,index)"),"map saves before opening first scene")
	check(map.contains('func show_cultist_rumor_intro(index: int) -> void:'),"actual first rumor modal created")
	check(map.contains('str(CultistRumorEntry.FIRST_BEAT.effect)'),"source arrival text displayed")
	check(map.contains("CultistRumorEntry.BASE_ART"),"original background displayed")
	check(map.contains('session.get_story_event(CultistRumorEntry.EVENT_ID).status=="seen"'),"restart only reopens already discovered cultists")
	check(map.contains('"마을 기능"'),"original village actions remain")
	check(map.contains('"돌아가기"'),"return without forcing completion")
	var a: int=map.find("StoryEventEntry.can_enter(session,index)")
	var b: int=map.find("VillageRumorEntry.eligible_event_id(session,index)")
	var c: int=map.find("KnightCommanderEntry.can_enter(session,index)")
	var d: int=map.find("MonsterHunterEntry.can_enter(session,index)")
	var e: int=map.find("CultistRumorEntry.can_enter(session,index)")
	check(a>=0 and a<b and b<c and c<d and d<e,"original story priority not skipped")
	check(not map.contains("func advance_cultist_rumor("),"no future tracking quest UI activated")

func _run() -> void:
	scenario(false)
	scenario(true)
	invalid_conditions()
	rollback()
	inspect_art_and_map()
	for p in paths: cleanup(p)
	print("CULTIST_RUMOR_ENTRY_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
