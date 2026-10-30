extends SceneTree
## Real abandoned route, persisted dialogue, rollback and source provenance.
const Session=preload("res://systems/run_session.gd")
const Child=preload("res://systems/story_event_entry.gd")
const Rumor=preload("res://systems/village_rumor_entry.gd")
const RumorBeats=preload("res://systems/village_rumor_beats.gd")
const Commander=preload("res://systems/knight_commander_entry.gd")
const CommanderBeats=preload("res://systems/knight_commander_beats.gd")
const Hunter=preload("res://systems/monster_hunter_entry.gd")
const Prophet=preload("res://systems/prophet_story_entry.gd")
const Beats=preload("res://systems/prophet_story_beats.gd")
const Cultist=preload("res://systems/cultist_rumor_entry.gd")
const CultistBeats=preload("res://systems/cultist_rumor_beats.gd")
var passed: int=0
var failed: int=0
var paths: Array[String]=[]

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("PASS prophet-story: ",label)
	else: failed+=1; printerr("FAIL prophet-story: ",label)
func cleanup(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
func fresh(label: String):
	var s=Session.new()
	root.add_child(s)
	var path: String="user://prophet_story_%d_%s.json" % [OS.get_process_id(),label]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	s.world.contamination=93
	s.world.lap_ready=true
	s.world.leave_home()
	return s
func no_hunter(s) -> bool:
	return s.get_story_event(Hunter.EVENT_ID).status=="unseen" and not s.event_flag_is_set(Hunter.SEEN_FLAG) and not s.event_flag_is_set(Hunter.COMPLETE_FLAG) and not s.event_flag_is_set(Hunter.QUEST_ACTIVE_FLAG) and not s.event_flag_is_set(Hunter.QUEST_COMPLETE_FLAG) and not s.event_flag_is_set(Commander.RECOGNIZED_FLAG)
func prepared(label: String):
	var s=fresh(label)
	var grave: int=s.world.tiles.find("graveyard")
	s.world.position=grave
	check(Child.begin(s,grave) and Child.choose(s,grave,"leave"),"actual child abandonment")
	var village: int=s.world.tiles.find("village")
	s.world.position=village
	check(Rumor.begin(s,village)==Rumor.ABANDONED_ID,"matching village rumor")
	check(not Commander.can_enter(s,village),"unfinished rumor blocks referral")
	for i in range(RumorBeats.count(Rumor.ABANDONED_ID)):
		check(Rumor.advance(s,village,Rumor.ABANDONED_ID,i),"rumor checkpoint "+str(i))
	check(Commander.route(s)=="prophet" and Commander.begin(s,village),"actual history selects prophet referral")
	for i in range(CommanderBeats.count("prophet")):
		check(not s.event_flag_is_set(Prophet.QUEST_ACTIVE_FLAG) and no_hunter(s),"no premature referral")
		check(Commander.advance(s,village,i),"commander checkpoint "+str(i))
	check(s.event_flag_is_set(Prophet.QUEST_ACTIVE_FLAG) and no_hunter(s),"referral never manufactures hunter history")
	s.world.position=s.world.tiles.find("fortune-teller-camp")
	return s

func branch_chain() -> void:
	var s=prepared("chain")
	var camp: int=s.world.position
	var event_index: int=s.world.tiles.find("event")
	var before: Dictionary=s.world.snapshot().duplicate(true)
	check(not Prophet.begin(s,event_index) and s.world.snapshot()==before,"remote preview cannot start story")
	s.world.position=event_index
	check(not Prophet.can_enter(s,event_index),"generic event cannot replace actual camp")
	s.world.position=camp
	s.world.contamination=29
	check(not Prophet.begin(s,camp),"unseen prophet respects contamination 30")
	s.world.contamination=30
	var rng_before: int=s.world.rng.state
	var receipts: Array=s.world.reward_receipts.duplicate(true)
	var prophecy: Dictionary=s.world.prophecy.duplicate(true)
	check(Prophet.begin(s,camp),"actual camp discovery")
	check(s.world.rng.state==rng_before and s.world.reward_receipts==receipts and s.world.prophecy==prophecy,"story does not consume prophecy or RNG")
	before=s.world.snapshot().duplicate(true)
	check(Prophet.begin(s,camp) and s.world.snapshot()==before,"reopening idempotent")
	check(not Prophet.advance(s,camp,1) and not Prophet.advance(s,event_index,0),"skip and remote callbacks rejected")
	for i in range(Beats.count()-1):
		check(Prophet.current_beat(s)==i and Prophet.advance(s,camp,i),"actual saved prophet checkpoint "+str(i))
		check(not s.event_flag_is_set(Prophet.HUMAN_CLUE_FLAG) and not s.event_flag_is_set(Prophet.QUEST_COMPLETE_FLAG),"no clue before explicit final acknowledgement")
		before=s.world.snapshot().duplicate(true)
		check(not Prophet.advance(s,camp,i) and s.world.snapshot()==before,"duplicate old callback cannot advance")
		if i==0:
			s.world.contamination=0
			check(s.save_world(),"lower contamination checkpoint")
			s.reload_world()
			check(Prophet.current_beat(s)==1 and Prophet.can_enter(s,camp),"saved scene resumes after purification")
	check(Prophet.advance(s,camp,Beats.count()-1),"explicit final acknowledgement")
	check(Prophet.completed(s) and no_hunter(s),"complete provenance and untouched hunter route")
	before=s.world.snapshot().duplicate(true)
	check(not Prophet.advance(s,camp,Beats.count()-1) and not Prophet.begin(s,camp) and s.world.snapshot()==before,"completed story cannot repeat")
	s.reload_world()
	check(Prophet.completed(s) and no_hunter(s),"final result survives reload")
	s.world.position=s.world.tiles.find("village")
	s.world.contamination=39
	check(not Cultist.can_enter(s,s.world.position),"cultist rumor retains contamination 40")
	s.world.contamination=40
	check(Cultist.route(s)=="prophet" and Cultist.can_enter(s,s.world.position),"prophet clue genuinely unlocks next event")
	var first_receipt: String=Prophet.progress_flag(1)
	s.world.event_flags.erase(first_receipt)
	check(Cultist.route(s).is_empty() and not Cultist.can_enter(s,s.world.position),"missing acknowledged source beat rejects forged completion")
	s.world.event_flags[first_receipt]=true
	check(CultistBeats.beat(3,"prophet").effect.contains("예언가") and CultistBeats.beat(3).effect.contains("사냥꾼"),"later dialogue names actual information source")
	check(Cultist.begin(s,s.world.position),"next event begins without fake hunter quest")
	for i in range(CultistBeats.count()): check(Cultist.advance(s,s.world.position,i),"cultist checkpoint "+str(i))
	check(s.event_flag_is_set(Cultist.TRACKING_FLAG) and no_hunter(s),"next final acknowledgement opens tracking")
	s.free()

func blockers() -> void:
	var s=prepared("guards")
	var index: int=s.world.position
	check(Prophet.can_enter(s,index),"valid entry baseline")
	check(not Prophet.can_enter(s,-1) and not Prophet.can_enter(s,s.world.tiles.size()),"invalid indices")
	s.world.pending_move={"test":true}
	check(not Prophet.can_enter(s,index),"pending move")
	s.world.pending_move={}
	s.world.pending_reward={"kind":"test"}
	check(not Prophet.can_enter(s,index),"pending reward")
	s.world.pending_reward={}
	s.encounter={"test":true}
	check(not Prophet.can_enter(s,index),"live battle")
	s.encounter={}
	s.world.active_encounter={"test":true}
	check(not Prophet.can_enter(s,index),"saved battle")
	s.world.active_encounter={}
	s.world.run_result={"ended":true,"reason":"battle_defeat"}
	check(not Prophet.can_enter(s,index),"terminal run cannot mutate story")
	s.world.run_result={}
	s.world.event_flags[Prophet.QUEST_ACTIVE_FLAG]=false
	check(not Prophet.can_enter(s,index),"missing referral")
	s.world.event_flags[Prophet.QUEST_ACTIVE_FLAG]=true
	var receipt: String=Commander.progress_flag(1,"prophet")
	s.world.event_flags.erase(receipt)
	check(not Prophet.can_enter(s,index),"incomplete referral history")
	s.world.event_flags[receipt]=true
	check(Prophet.begin(s,index),"valid history recovers")
	s.world.event_flags[Prophet.progress_flag(2)]=true
	check(Prophet.current_beat(s)==-1 and not Prophet.advance(s,index,0),"out-of-order checkpoint fails closed")
	s.world.event_flags.erase(Prophet.progress_flag(2))
	s.world.event_flags[Prophet.HUMAN_CLUE_FLAG]=true
	check(not Prophet.can_enter(s,index),"premature clue fails closed")
	s.world.event_flags[Prophet.HUMAN_CLUE_FLAG]=false
	s.world.position=s.world.tiles.find("event")
	s.world.event_flags[Hunter.QUEST_ACTIVE_FLAG]=true
	s.world.event_flags[Commander.RECOGNIZED_FLAG]=true
	check(not Hunter.can_enter(s,s.world.position),"forged hunter flags cannot cross real abandoned history")
	s.free()
	var isolated=fresh("isolated")
	isolated.world.position=isolated.world.tiles.find("fortune-teller-camp")
	isolated.world.event_flags[Prophet.QUEST_ACTIVE_FLAG]=true
	check(not Prophet.begin(isolated,isolated.world.position),"isolated active flag cannot fabricate referral")
	isolated.world.event_flags[Prophet.QUEST_ACTIVE_FLAG]=false
	isolated.world.event_flags[Prophet.QUEST_COMPLETE_FLAG]=true
	isolated.world.event_flags[Prophet.HUMAN_CLUE_FLAG]=true
	isolated.world.position=isolated.world.tiles.find("village")
	check(Cultist.route(isolated).is_empty(),"isolated clue cannot fabricate source")
	isolated.free()

func save_failures() -> void:
	var s=prepared("rollback")
	var index: int=s.world.position
	var good: String=s.save_file_path
	var bad: String="user://prophet_missing_%d/save.json" % OS.get_process_id()
	var before: Dictionary=s.world.snapshot().duplicate(true)
	s.save_file_path=bad
	check(not Prophet.begin(s,index) and s.world.snapshot()==before,"failed first save rolls back")
	s.save_file_path=good
	check(Prophet.begin(s,index),"first save recovers")
	before=s.world.snapshot().duplicate(true)
	s.save_file_path=bad
	check(not Prophet.advance(s,index,0) and s.world.snapshot()==before,"failed middle save rolls back")
	s.save_file_path=good
	s.reload_world()
	check(Prophet.current_beat(s)==0,"failed middle save reloads original beat")
	for i in range(Beats.count()-1): check(Prophet.advance(s,index,i),"prepare final checkpoint "+str(i))
	before=s.world.snapshot().duplicate(true)
	s.save_file_path=bad
	check(not Prophet.advance(s,index,Beats.count()-1) and s.world.snapshot()==before,"failed final save rolls back event quest and clue atomically")
	check(not s.event_flag_is_set(Prophet.HUMAN_CLUE_FLAG) and s.event_flag_is_set(Prophet.QUEST_ACTIVE_FLAG),"failed final save retains active quest")
	s.save_file_path=good
	s.reload_world()
	check(Prophet.current_beat(s)==Beats.count()-1,"final beat survives storage failure")
	check(Prophet.advance(s,index,Beats.count()-1),"final acknowledgement retries")
	s.reload_world()
	check(Prophet.completed(s) and no_hunter(s),"recovered final outcome durable")
	s.free()

func ordinary_prophecy() -> void:
	var s=fresh("ordinary")
	var index: int=s.world.tiles.find("fortune-teller-camp")
	s.world.position=index
	var flags: Dictionary=s.world.event_flags.duplicate(true)
	var events: Dictionary=s.world.story_events.duplicate(true)
	var result: Dictionary=s.fortune_prophecy(index)
	check(result.ok and int(result.face)>=1 and int(result.face)<=6,"ordinary prophecy rolls real die")
	check(s.world.event_flags==flags and s.world.story_events==events,"ordinary prophecy does not mutate narrative")
	var before: Dictionary=s.world.snapshot().duplicate(true)
	check(not s.fortune_prophecy(index).ok and s.world.snapshot()==before,"ordinary visit receipt unchanged")
	s.reload_world()
	check(int(s.world.last_prophecy.face)==int(result.face) and not s.fortune_prophecy(index).ok,"ordinary prophecy survives reload")
	s.free()

func run() -> void:
	branch_chain()
	blockers()
	save_failures()
	ordinary_prophecy()
	for path in paths: cleanup(path)
	print("PROPHET_STORY_ENTRY_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
