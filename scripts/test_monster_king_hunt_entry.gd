extends SceneTree
## P1-05K-1: canonical first world-tree hunt, prerequisite real portal
## outcome, weakened/full modes, event tile, reboot and rollback.
const SessionScript=preload("res://systems/run_session.gd")
const Rumor=preload("res://systems/cultist_rumor_entry.gd")
const Altar=preload("res://systems/cultist_altar_entry.gd")
const Portal=preload("res://systems/ritual_portal_entry.gd")
const Hunt=preload("res://systems/monster_king_hunt_entry.gd")
const Beats=preload("res://systems/monster_king_hunt_beats.gd")
const Registry=preload("res://systems/story_battle_registry.gd")

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

func check(ok: bool, detail: String) -> void:
	if ok:
		passed+=1
		print("PASS monster-king-hunt-entry: ",detail)
	else:
		failed+=1
		printerr("FAIL monster-king-hunt-entry: ",detail)

func cleanup(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

## Every eligible fixture completes the actual previous altar and portal
## transitions including one real win/loss and final human acknowledgment.
func fixture(tag: String, winner: String, destination: String):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://monster_king_hunt_entry_%d_%s.json" % [OS.get_process_id(),tag]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	# Build the modern high-contamination second board at home exit,
	# preserving the only event and forest tiles when the boss appears.
	s.world.contamination = 93
	s.world.lap_ready = true
	s.world.leave_home()
	# Legacy save compatibility: dedicated altar/world-tree paths are still
	# accepted even though the present map generates their event equivalents.
	var legacy_altar_index: int = s.world.tiles.find("basic")
	assert(legacy_altar_index>=0)
	s.world.tiles[legacy_altar_index] = "altar"
	var legacy_tree_index: int = s.world.tiles.find("basic")
	assert(legacy_tree_index>=0)
	s.world.tiles[legacy_tree_index] = "unknown"
	s.world.story_events[Rumor.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	s.world.event_flags[Rumor.SEEN_FLAG]=true
	s.world.event_flags[Rumor.COMPLETE_FLAG]=true
	s.world.event_flags[Rumor.TRACKING_FLAG]=true
	s.world.position=s.world.tiles.find("altar")
	check(s.save_world(),"prior rumor chain saved")
	var at: int=s.world.position
	check(Altar.begin(s,at),"altar arrival committed")
	check(Altar.advance(s,at,0),"altar ritual committed")
	check(Altar.advance(s,at,1),"altar choice committed")
	check(Altar.choose(s,at,2,"pass"),"altar passage committed")
	check(Altar.finish(s,at),"cultist tracking handed to ritual tracking")
	# The first board has no forest; discover it through a legitimate event
	# before entering the ritual portal or continuing the king hunt.
	var discovery_at: int = s.world.tiles.find("event")
	check(discovery_at >= 0,"real event tile available to unlock portal forest")
	if discovery_at >= 0:
		s.world.position = discovery_at
		var unlocked: Dictionary = s.discover_location_on_event(discovery_at,"forest")
		check(bool(unlocked.get("ok",false)) and s.world.tiles.count("forest")==1,"actual forest unlock persists for portal story")
	s.world.position=s.world.tiles.find("forest")
	check(s.world.position>=0 and s.save_world(),"real ritual portal location saved")
	at=s.world.position
	check(Portal.begin(s,at),"portal arrival committed")
	for beat in [0,1,2,3]:
		check(Portal.advance(s,at,beat),"portal scene %d committed" % (beat+1))
	check(Portal.choose_intervention(s,at,4),"final intervention choice committed")
	check(s.start_story_encounter(Portal.EVENT_ID,at,[s.world.roster[0].id]),"real portal battle started")
	check(s.finish_encounter(BattleResult.new(winner)),"real portal win/loss stored")
	check(s.acknowledge_story_battle_result(Portal.EVENT_ID),"player acknowledged combat return")
	check(Portal.finish(s,at),"original revival ending and king hunt committed")
	check(Portal.completed(s),"previous portal completion internally consistent")
	s.world.position=s.world.tiles.find(destination)
	check(s.world.position>=0 and s.save_world(),"new world-tree or wildcard landing saved")
	return s

func original_contract() -> void:
	check(Beats.count()==5,"first four source beats present including destination clue")
	check(Beats.beat(0).id=="arrival","source hunt first beat ID")
	check(Beats.beat(0).effect=="세계수의 뿌리 부근. 의식이 끝난 뒤에도 검은 흔적이 땅을 타고 뻗어 있다.","exact original world-tree narration")
	check(Beats.beat(0).dialogue=="","source first beat has no dialogue")
	check(Beats.beat(0).speaker=="","source first beat has no speaker")
	check(Beats.beat(0).visual=="base","source first beat has only original base art")
	check(Beats.beat(1).id=="trace","source hunter trace second beat enabled")
	check(Beats.beat(2).is_empty(),"revival-mode beat cannot be shown without a valid mode")
	check(Beats.beat(2,"weakened").id=="revival","source third scene now available for correct branch")
	check(Beats.beat(3).id=="destination","fourth destination clue available after third scene")
	check(Beats.beat(-1).is_empty(),"invalid beat rejected")
	check(Beats.BASE_ART=="res://assets/map/events/manuscript_hunt_base.png","original world-tree illustration")
	check(Hunt.BASE_ART==Beats.BASE_ART,"hunt entry uses original world-tree art")
	check(Hunt.FIRST_BEAT==Beats.beat(0),"entry and scene data match")
	check(ResourceLoader.exists(Beats.BASE_ART),"original background can be loaded")
	check(Registry.definition(Hunt.EVENT_ID).is_empty(),"king hunt investigation is not a battle")
	var changed: Dictionary=Beats.beat(0)
	changed.effect="altered"
	check(Beats.beat(0).effect.begins_with("세계수의 뿌리"),"source narration remains immutable")
	var src: String=FileAccess.get_file_as_string("res://map.gd")
	check(src.contains('const MonsterKingHuntEntry = preload("res://systems/monster_king_hunt_entry.gd")'),"new entry imported")
	check(src.contains('if type in ["unknown","event"] and MonsterKingHuntEntry.can_enter(session,index):'),"only world-tree and event wildcard dispatch")
	check(src.contains("if MonsterKingHuntEntry.begin(session,index):"),"save before showing first scene")
	check(src.contains('func show_monster_king_hunt_intro(index: int) -> void:'),"dedicated first hunt view")
	check(src.contains("MonsterKingHuntBeats.beat(beat_index,MonsterKingHuntEntry.revival_mode(session))"),"scene uses saved beat and real revival mode")
	check(src.contains('사건 · 왕의 흔적'),"original event title")
	check(src.contains("InkSceneReveal.play(art)"),"first scene uses existing ink reveal")
	check(src.contains('location_button(panel,"세계수 기능"'),"prior world-tree tile action retained")
	check(src.contains('location_button(panel,"돌아가기"'),"map return button preserved")
	check(src.contains('session.get_story_event(MonsterKingHuntEntry.EVENT_ID).status=="seen"'),"restart resumes only a saved discovery")
	check(not src.contains("start_monster_king_hunt_battle("),"final king combat remains locked")
	check(not src.contains("finish_monster_king_hunt("),"completion handler not added prematurely")

func arrival(winner: String, destination: String) -> void:
	var s=fixture("arrive_"+winner+"_"+destination,winner,destination)
	var at: int=s.world.position
	var weakened: bool=winner=="ally"
	check(s.event_flag_is_set(Hunt.WEAKENED_FLAG)==weakened,"revival mode matches actual fight")
	check(s.event_flag_is_set(Hunt.FULL_REVIVAL_FLAG)!=weakened,"opposite revival flag absent")
	check(Hunt.can_enter(s,at),"king hunt eligible at actual landing")
	check(not Hunt.can_enter(s,at+1),"adjacent tile preview cannot reveal story")
	check(s.get_story_event(Hunt.EVENT_ID).status=="unseen","first encounter originally unseen")
	check(Hunt.current_beat(s)==-1,"unseen story cannot be resumed accidentally")
	check(not s.event_flag_is_set(Hunt.SEEN_FLAG),"seen receipt not issued before arrival")
	check(Hunt.begin(s,at),"first world-tree hunt event saved")
	check(s.get_story_event(Hunt.EVENT_ID).status=="seen","first encounter now seen")
	check(s.event_flag_is_set(Hunt.SEEN_FLAG),"seen receipt persisted")
	check(Hunt.current_beat(s)==0,"original first scene is displayed")
	check(not s.event_flag_is_set(Hunt.COMPLETE_FLAG),"hunt event not finished on arrival")
	check(s.event_flag_is_set(Hunt.HUNT_ACTIVE_FLAG),"king hunt stays active")
	check(not s.event_flag_is_set(Hunt.HUNT_COMPLETE_FLAG),"king hunt quest not completed")
	check(not s.event_flag_is_set(Hunt.SEALED_RUINS_FLAG),"sealed ruins still undiscovered")
	check(not s.event_flag_is_set(Hunt.FINAL_BATTLE_FLAG),"final king battle remains locked")
	check(s.event_flag_is_set(Portal.REVIVED_FLAG),"actual ritual revival preserved")
	check(s.get_story_event(Portal.EVENT_ID).battle_result==("won" if weakened else "lost"),"previous real battle outcome preserved")
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty(),"hunter first scene never starts battle")
	check(s.world.pending_reward.is_empty(),"first scene awards no reward")
	var before: Dictionary=s.world.snapshot().duplicate(true)
	check(Hunt.begin(s,at),"reopening is deliberately idempotent")
	check(s.world.snapshot()==before,"reopening does not rewrite saves")
	check(not Hunt.begin(s,at+1),"off-tile first-discovery forbidden")
	s.reload_world()
	check(Hunt.can_enter(s,at),"restored first hunt remains eligible")
	check(Hunt.current_beat(s)==0,"reconnect restores first scene before deliberate Continue")
	check(s.get_story_event(Hunt.EVENT_ID).status=="seen","first-scene status survives reboot")
	check(s.event_flag_is_set(Hunt.SEEN_FLAG),"first-scene receipt survives reboot")
	check(not s.event_flag_is_set(Hunt.COMPLETE_FLAG),"no premature hunt completion after reboot")
	check(s.event_flag_is_set(Hunt.WEAKENED_FLAG)==weakened,"branch outcome survives reboot")
	s.free()

func guards() -> void:
	var s=fixture("guards","ally","unknown")
	var at: int=s.world.position
	var stable: Dictionary=s.world.snapshot().duplicate(true)
	s.world.event_flags[Hunt.HUNT_ACTIVE_FLAG]=false
	check(not Hunt.begin(s,at),"inactive hunt quest blocks discovery")
	s.world.restore(stable)
	s.world.event_flags[Portal.COMPLETE_FLAG]=false
	check(not Hunt.begin(s,at),"uncompleted portal blocks discovery")
	s.world.restore(stable)
	s.world.story_events[Portal.EVENT_ID].status="active"
	check(not Hunt.begin(s,at),"forged prior completion blocks discovery")
	s.world.restore(stable)
	s.world.event_flags[Hunt.FULL_REVIVAL_FLAG]=true
	check(not Hunt.begin(s,at),"contradictory revival types block discovery")
	s.world.restore(stable)
	s.world.event_flags[Hunt.WEAKENED_FLAG]=false
	check(not Hunt.begin(s,at),"unknown revival mode blocks discovery")
	s.world.restore(stable)
	s.world.event_flags[Hunt.COMPLETE_FLAG]=true
	check(not Hunt.begin(s,at),"completed event cannot restart")
	s.world.restore(stable)
	s.world.event_flags[Hunt.SEALED_RUINS_FLAG]=true
	check(not Hunt.begin(s,at),"later destination cannot be fabricated")
	s.world.restore(stable)
	s.world.event_flags[Hunt.FINAL_BATTLE_FLAG]=true
	check(not Hunt.begin(s,at),"unlocked final fight prevents replay")
	s.world.restore(stable)
	s.world.pending_move={"test":true}
	check(not Hunt.begin(s,at),"unresolved travel blocks discovery")
	s.world.restore(stable)
	s.world.pending_reward={"test":true}
	check(not Hunt.begin(s,at),"unclaimed reward blocks discovery")
	s.world.restore(stable)
	s.world.active_encounter={"id":"test"}
	check(not Hunt.begin(s,at),"active combat blocks discovery")
	s.world.restore(stable)
	s.world.tiles[at]="graveyard"
	check(not Hunt.begin(s,at),"non-worldtree tile rejects hunt")
	s.world.restore(stable)
	s.world.story_events[Hunt.EVENT_ID]={"status":"seen","choice":"","battle_result":""}
	check(not Hunt.begin(s,at),"seen state without seen receipt rejected")
	s.world.restore(stable)
	s.world.event_flags[Hunt.SEEN_FLAG]=true
	check(not Hunt.begin(s,at),"seen receipt without scene state rejected")
	s.world.restore(stable)
	s.world.story_events[Hunt.EVENT_ID]={"status":"unseen","choice":"fight","battle_result":""}
	check(not Hunt.begin(s,at),"fake battle choice rejected")
	s.world.restore(stable)
	s.world.story_events[Hunt.EVENT_ID]={"status":"unseen","choice":"","battle_result":"won"}
	check(not Hunt.begin(s,at),"fake battle outcome rejected")
	s.world.restore(stable)
	check(Hunt.can_enter(s,at),"eligible state restored after guards")
	s.free()

func failed_save() -> void:
	var s=fixture("failed_save","enemy","event")
	var at: int=s.world.position
	var before: Dictionary=s.world.snapshot().duplicate(true)
	var saved_path: String=s.save_file_path
	s.save_file_path="user://missing_hunt_%d/failed.json" % OS.get_process_id()
	check(not Hunt.begin(s,at),"missing storage path rejects first scene")
	check(s.world.snapshot()==before,"failed write rolls back event state and receipt")
	check(s.get_story_event(Hunt.EVENT_ID).status=="unseen","failed discovery remains unseen")
	check(not s.event_flag_is_set(Hunt.SEEN_FLAG),"failed discovery does not set seen")
	check(not s.event_flag_is_set(Hunt.COMPLETE_FLAG),"failed discovery cannot complete quest")
	s.save_file_path=saved_path
	check(Hunt.begin(s,at),"retry after storage recovery works")
	s.reload_world()
	check(Hunt.current_beat(s)==0,"recovered discovery survives restart")
	s.free()

func _run() -> void:
	original_contract()
	arrival("ally","unknown")
	arrival("enemy","event")
	guards()
	failed_save()
	for path in paths: cleanup(path)
	print("MONSTER_KING_HUNT_ENTRY_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
