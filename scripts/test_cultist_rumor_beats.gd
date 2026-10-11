extends SceneTree
## P1-05H: canonical cultist rumor scenes, saved checkpoints and tracking quest.
const SessionScript=preload("res://systems/run_session.gd")
const Child=preload("res://systems/story_event_entry.gd")
const Rumor=preload("res://systems/village_rumor_entry.gd")
const RumorBeats=preload("res://systems/village_rumor_beats.gd")
const Commander=preload("res://systems/knight_commander_entry.gd")
const CommanderBeats=preload("res://systems/knight_commander_beats.gd")
const Hunter=preload("res://systems/monster_hunter_entry.gd")
const HunterBeats=preload("res://systems/monster_hunter_beats.gd")
const Cultist=preload("res://systems/cultist_rumor_entry.gd")
const Beats=preload("res://systems/cultist_rumor_beats.gd")
const Registry=preload("res://systems/story_battle_registry.gd")

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
		print("PASS cultist-rumor-beats: ",what)
	else:
		failed+=1
		printerr("FAIL cultist-rumor-beats: ",what)

func cleanup(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func make(suffix: String):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://cultist_rumor_beats_%d_%s.json" % [OS.get_process_id(),suffix]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	var grave: int=s.world.tiles.find("graveyard")
	s.world.position=grave
	check(Child.begin(s,grave),"child rescue discovery")
	check(Child.choose(s,grave,"protect_child"),"child protected")
	check(s.start_story_encounter(Child.EVENT_ID,grave,[s.world.roster[0].id]),"ghoul battle created")
	check(s.finish_encounter(Result.new("ally")),"child rescued in battle")
	check(s.acknowledge_graveyard_battle_result(),"child outcome acknowledged")
	var village: int=s.world.tiles.find("village")
	s.world.position=village
	check(Rumor.begin(s,village)==Rumor.RESCUED_ID,"rescued rumor discovered")
	for i in range(RumorBeats.count(Rumor.RESCUED_ID)):
		check(Rumor.advance(s,village,Rumor.RESCUED_ID,i),"rescued rumor beat "+str(i))
	check(Commander.begin(s,village),"knight commander discovered")
	for i in range(CommanderBeats.count()):
		check(Commander.advance(s,village,i),"commander scene "+str(i))
	var tree: int=s.world.tiles.find("unknown")
	s.world.position=tree
	check(Hunter.begin(s,tree),"monster hunter found")
	for i in range(HunterBeats.count()):
		check(Hunter.advance(s,tree,i),"monster hunter scene "+str(i))
	check(s.event_flag_is_set(Cultist.HUMAN_CLUE_FLAG),"original human clue acquired")
	s.world.position=village
	check(Cultist.begin(s,village),"cultist rumor first encounter saved")
	return s

func source_beats() -> void:
	var ids: Array=["arrival","procession","gossip","mark","king","track"]
	var visuals: Array=["base","procession","procession","procession","procession","procession"]
	check(Beats.count()==6,"exact six cultist rumor scenes")
	for i in range(ids.size()):
		check(Beats.beat(i).id==ids[i],"canonical scene order "+ids[i])
		check(Beats.beat(i).visual==visuals[i],"canonical visual "+ids[i])
	check(Beats.beat(-1).is_empty(),"negative beat rejected")
	check(Beats.beat(6).is_empty(),"out-of-range beat rejected")
	check(Beats.beat(0)==Cultist.FIRST_BEAT,"existing P1-05G first scene unchanged")
	check(Beats.beat(1).effect=="골목 너머로 두건을 쓴 인간들이 오염된 마물의 사체와 정체를 알 수 없는 짐을 옮기고 있다.","original procession reveal text")
	check(Beats.beat(2).dialogue=="요즘 밤마다 이상한 놈들이 성 밖으로 뭔가를 실어 나른다더군.","original resident gossip")
	check(Beats.beat(3).dialogue=="저 문양 말이야. 다른 곳에서도 봤다는 사람이 있어.","repeated cultist symbol clue")
	check(Beats.beat(4).dialogue=="마물의 왕을 다시 불러내려는 자들이 있다는 말도 있어.","original monster king resurrection rumor dialogue")
	check(Beats.beat(5).effect=="같은 문양을 쓰는 자들이 향한 곳을 추적할 단서를 얻었다.","original final narration")
	check(Beats.beat(5).dialogue=="[광신도들의 흔적을 추적합니다.]","original tracking activation dialogue")
	check(Beats.beat(5).get("trackingActivated",false)==true,"final beat advertises tracking quest")
	for i in range(5):
		check(Beats.beat(i).get("trackingActivated",false)==false,"early scene has no tracking award "+str(i))
	check(Beats.is_final(5) and not Beats.is_final(4),"only last scene final")
	check(Beats.layer_for("base").is_empty(),"arrival has no procession")
	check(Beats.layer_for("procession")==Beats.PROCESSION,"procession art selected")
	check(Beats.layer_for("unregistered").is_empty(),"unknown art hidden")
	check(ResourceLoader.exists(Beats.BASE),"original village backdrop bundled")
	check(ResourceLoader.exists(Beats.PROCESSION),"original hooded procession art bundled")
	var dup: Dictionary=Beats.beat(2)
	dup.dialogue="tampered"
	check(Beats.beat(2).dialogue.begins_with("요즘 밤마다"),"beat cannot mutate original")
	check(Registry.valid_definition(Registry.definition(Registry.CULTIST_ALTAR_ID)),"altar battle registration requires later saved fight choice")

func full_story(wildcard: bool) -> void:
	var s=make("event" if wildcard else "village")
	var idx: int=s.world.position
	if wildcard:
		idx=s.world.tiles.find("event")
		check(idx>=0,"generic event tile exists")
		s.world.position=idx
	check(Cultist.can_enter(s,idx),"started cultist rumor eligible on tile")
	check(Cultist.current_beat(s)==0,"first scene starts at arrival")
	check(Cultist.progress_flag(0).is_empty(),"initial beat implicit")
	check(Cultist.progress_flag(-1).is_empty(),"negative flag denied")
	check(Cultist.progress_flag(6).is_empty(),"postfinal flag denied")
	check(not Cultist.advance(s,idx,1),"cannot jump over arrival")
	check(not Cultist.advance(s,idx+1,0),"cannot advance on another tile")
	for i in range(Beats.count()-1):
		check(Cultist.current_beat(s)==i,"current visible beat "+str(i))
		check(Cultist.advance(s,idx,i),"explicit beat advance stored "+str(i))
		check(s.event_flag_is_set(Cultist.progress_flag(i+1)),"next scene flag written "+str(i+1))
		check(s.get_story_event(Cultist.EVENT_ID).status=="seen","not completed before final "+str(i))
		check(s.event_flag_is_set(Cultist.HUMAN_CLUE_FLAG),"human clue remains known "+str(i))
		check(not s.event_flag_is_set(Cultist.COMPLETE_FLAG),"rumor incomplete before last click "+str(i))
		check(not s.event_flag_is_set(Cultist.TRACKING_FLAG),"tracking inactive until final confirmation "+str(i))
		check(not s.event_flag_is_set(Cultist.KING_RUMOR_FLAG),"king revival discovery not awarded "+str(i))
		var snapshot: Dictionary=s.world.snapshot().duplicate(true)
		check(not Cultist.advance(s,idx,i),"stale UI advance blocked "+str(i))
		check(s.world.snapshot()==snapshot,"stale click leaves world unchanged "+str(i))
		s.reload_world()
		check(s.world.position==idx,"reload restores tile "+str(i))
		check(Cultist.current_beat(s)==i+1,"reload resumes next scene "+str(i+1))
		check(Cultist.begin(s,idx),"already-seen encounter reopened")
	check(Beats.is_final(Cultist.current_beat(s)),"tracking system screen reached")
	check(not s.event_flag_is_set(Cultist.TRACKING_FLAG),"displaying tracking screen does not grant quest")
	s.reload_world()
	check(Cultist.current_beat(s)==5,"last screen awaits confirmation across restart")
	check(Cultist.advance(s,idx,5),"final click completes cultist rumor")
	check(s.get_story_event(Cultist.EVENT_ID).status=="complete","story status completed")
	check(s.event_flag_is_set(Cultist.SEEN_FLAG),"seen remains recorded")
	check(s.event_flag_is_set(Cultist.COMPLETE_FLAG),"cultist rumor complete flag saved")
	check(s.event_flag_is_set(Cultist.TRACKING_FLAG),"cultist tracking quest activated")
	check(not s.event_flag_is_set(Cultist.KING_RUMOR_FLAG),"later monster king rumor still disabled")
	check(not s.event_flag_is_set("event:cultist_altar_encounter_01:seen"),"later altar event not discovered")
	check(not s.event_flag_is_set("event:cultist_altar_encounter_01:complete"),"later altar event not completed")
	check(not Cultist.can_enter(s,idx),"finished rumor cannot restart")
	check(Cultist.current_beat(s)==-1,"finished rumor has no pending scene")
	check(not Cultist.begin(s,idx),"reopening finished rumor forbidden")
	check(not Cultist.advance(s,idx,5),"duplicate final acknowledgement blocked")
	s.reload_world()
	check(s.get_story_event(Cultist.EVENT_ID).status=="complete","completion survives restart")
	check(s.event_flag_is_set(Cultist.TRACKING_FLAG),"quest survives restart")
	check(not s.event_flag_is_set(Cultist.KING_RUMOR_FLAG),"king stage remains disabled after restart")
	s.free()

func storage_failure() -> void:
	var s=make("rollback")
	var idx: int=s.world.position
	var saved_path: String=s.save_file_path
	var bad_path: String="user://cultist_rumor_beats_no_dir_%d/no.json" % OS.get_process_id()
	var snapshot: Dictionary=s.world.snapshot().duplicate(true)
	s.save_file_path=bad_path
	check(not Cultist.advance(s,idx,0),"intermediate save error reported")
	check(s.world.snapshot()==snapshot,"intermediate failure rolls back snapshot")
	check(Cultist.current_beat(s)==0,"failed first advance remains on arrival")
	s.save_file_path=saved_path
	check(Cultist.advance(s,idx,0),"save retry advances to procession")
	for i in range(1,5):
		check(Cultist.advance(s,idx,i),"fixture advances to tracking scene "+str(i))
	check(Cultist.current_beat(s)==5,"tracking system screen visible")
	snapshot=s.world.snapshot().duplicate(true)
	s.save_file_path=bad_path
	check(not Cultist.advance(s,idx,5),"last tracking activation save error reported")
	check(s.world.snapshot()==snapshot,"failed tracking completion rolls back atomically")
	check(s.get_story_event(Cultist.EVENT_ID).status=="seen","rumor still seen on failure")
	check(not s.event_flag_is_set(Cultist.COMPLETE_FLAG),"rumor completion not prematurely saved")
	check(not s.event_flag_is_set(Cultist.TRACKING_FLAG),"tracking quest not activated after failed write")
	s.save_file_path=saved_path
	s.reload_world()
	check(Cultist.current_beat(s)==5,"failed completion reloads final screen")
	check(Cultist.advance(s,idx,5),"final save succeeds after recovery")
	s.reload_world()
	check(s.get_story_event(Cultist.EVENT_ID).status=="complete","retried completion durable")
	check(s.event_flag_is_set(Cultist.TRACKING_FLAG),"retried quest durable")
	s.free()

func corrupted_progress() -> void:
	var s=make("invalid")
	var idx: int=s.world.position
	s.world.event_flags[Cultist.progress_flag(2)]=true
	check(Cultist.current_beat(s)==-1,"noncontiguous progress rejected")
	check(not Cultist.advance(s,idx,0),"cannot skip over missing scene")
	s.world.event_flags.erase(Cultist.progress_flag(2))
	check(Cultist.current_beat(s)==0,"repair restores arrival")
	s.world.pending_reward={"kind":"treasure"}
	check(not Cultist.advance(s,idx,0),"pending reward blocks advancement")
	s.world.pending_reward={}
	s.world.pending_move={"testing":true}
	check(not Cultist.advance(s,idx,0),"pending movement blocks advancement")
	s.world.pending_move={}
	s.encounter={"testing":true}
	check(not Cultist.advance(s,idx,0),"running battle blocks advancement")
	s.encounter={}
	s.world.active_encounter={"testing":true}
	check(not Cultist.advance(s,idx,0),"saved battle blocks advancement")
	s.world.active_encounter={}
	s.world.event_flags[Cultist.TRACKING_FLAG]=true
	check(Cultist.current_beat(s)==-1,"premature tracking flag blocks current scene")
	check(not Cultist.advance(s,idx,0),"cannot advance after premature quest")
	s.world.event_flags[Cultist.TRACKING_FLAG]=false
	s.world.tiles[idx]="forest"
	check(not Cultist.advance(s,idx,0),"forest cannot host a village rumor")
	s.world.tiles[idx]="village"
	check(Cultist.advance(s,idx,0),"consistent state recovers")
	s.free()

func ui_wiring() -> void:
	var source: String=FileAccess.get_file_as_string("res://map.gd")
	check(source.contains('func show_cultist_rumor_intro(index: int) -> void:'),"first intro API preserved")
	check(source.contains('func show_cultist_rumor_beat(index: int) -> void:'),"dialogue scene renderer")
	check(source.contains('CultistRumorEntry.current_beat(session)'),"current scene restored from save")
	check(source.contains('CultistRumorBeats.beat(beat_index)'),"canonical dialogue loaded")
	check(source.contains('CultistRumorBeats.layer_for(str(beat.visual))'),"procession layer rendered")
	check(source.contains('str(beat.effect)'),"scene narration rendered")
	check(source.contains('str(beat.dialogue)'),"resident and system dialogue rendered")
	check(source.contains('CultistRumorEntry.advance(session,index,shown_beat)'),"each button saves one scene")
	check(source.contains('CultistRumorBeats.is_final(shown_beat)'),"UI identifies final tracking screen")
	check(source.contains('func advance_cultist_rumor(index: int, shown_beat: int) -> void:'),"guarded handler exists")
	check(source.contains('"계속"') and source.contains('"마치기"'),"continue/final buttons exist")
	check(source.contains('"마을 기능"') and source.contains('"돌아가기"'),"map and village actions preserved")
	check(source.contains('session.get_story_event(CultistRumorEntry.EVENT_ID).status=="seen"'),"reload only resumes previously seen rumor")

func _run() -> void:
	source_beats()
	full_story(false)
	full_story(true)
	storage_failure()
	corrupted_progress()
	ui_wiring()
	for p in paths: cleanup(p)
	print("CULTIST_RUMOR_BEATS_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
