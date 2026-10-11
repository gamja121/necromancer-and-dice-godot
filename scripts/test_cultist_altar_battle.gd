extends SceneTree
## P1-05I-4: original summon art, four unique enemies, real story combat and pending result.
const SessionScript = preload("res://systems/run_session.gd")
const Altar = preload("res://systems/cultist_altar_entry.gd")
const Rumor = preload("res://systems/cultist_rumor_entry.gd")
const Beats = preload("res://systems/cultist_altar_beats.gd")
const Registry = preload("res://systems/story_battle_registry.gd")
const Enemies = preload("res://systems/cultist_altar_enemies.gd")

class BattleResult:
	extends RefCounted
	var outcome: String
	var units: Array = []
	func _init(who: String) -> void: outcome=who
	func winner() -> String: return outcome
	func find_id(_id: String) -> Dictionary: return {}

var passed: int=0
var failed: int=0
var paths: Array[String]=[]

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		passed+=1
		print("PASS cultist-altar-battle: ",description)
	else:
		failed+=1
		printerr("FAIL cultist-altar-battle: ",description)

func cleanup(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func fixture(suffix: String,on_event_tile: bool=false):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://cultist_altar_battle_%d_%s.json" % [OS.get_process_id(),suffix]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	s.world.story_events[Rumor.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	s.world.event_flags[Rumor.SEEN_FLAG]=true
	s.world.event_flags[Rumor.COMPLETE_FLAG]=true
	s.world.event_flags[Rumor.TRACKING_FLAG]=true
	s.world.position=s.world.tiles.find("event" if on_event_tile else "altar")
	check(s.save_world(),"completed cultist rumor setup saved")
	var at: int=s.world.position
	check(Altar.begin(s,at),"altar arrival saved")
	check(Altar.advance(s,at,0),"ritual reveal saved")
	check(Altar.advance(s,at,1),"original fight/pass screen saved")
	check(Altar.choose(s,at,2,"fight"),"fight intent saved")
	return s

func art_and_contract() -> void:
	check(Beats.SUMMON=="res://assets/map/events/cultist-altar-summon-layer.webp","original summon layer path")
	check(Beats.SUMMON_EFFECT=="당신의 개입을 알아챈 광신도들이 의식을 비틀어 마물들을 불러낸다.","original summoning narration unchanged")
	check(ResourceLoader.exists(Beats.SUMMON),"original summon layer exists")
	var spec: Dictionary=Registry.definition(Altar.EVENT_ID)
	check(Registry.valid_definition(spec),"altar story battle registered with valid outcomes")
	check(spec.encounter_type=="event-cultist-altar","original event encounter type")
	check(spec.tiles==["altar","event"],"only original altar/event tiles")
	check(spec.choice=="fight","only saved fight choice launches battle")
	check(spec.enemy_selection=="cultist_altar","dynamic four-monster selector installed")
	check(spec.outcomes.won.status=="active","win awaits follow-up rather than completing plot")
	check(spec.outcomes.lost.status=="active","loss can retry without completing plot")
	check(spec.outcomes.lost.presentation.retry==true,"loss returns to 1–4 deck selector")
	check(spec.outcomes.won.presentation.retry==false,"won combat cannot repeat")
	check(spec.outcomes.won.presentation.overlay==Beats.SUMMON,"win shows original summon layer")
	check(spec.outcomes.lost.presentation.overlay==Beats.SUMMON,"loss shows original summon layer")
	check(not spec.outcomes.won.flags.has(Altar.RITUAL_TRACKING_FLAG),"win does not grant future quest")
	check(not spec.outcomes.won.flags.has(Altar.COMPLETE_FLAG),"win does not prematurely complete altar")
	check(not spec.outcomes.lost.flags.has(Altar.RITUAL_CONFIRMED_FLAG),"loss does not confirm further plot")
	var source: String=FileAccess.get_file_as_string("res://map.gd")
	check(source.contains("CultistAltarBeats.SUMMON if fighting"),"fight scene selects summoning artwork")
	check(source.contains("CultistAltarBeats.SUMMON_EFFECT if fighting"),"fight scene displays original summoning text")
	check(source.contains("get_tree().create_timer(0.76)"),"original short summoning delay before deck")
	check(source.contains("show_story_battle_deck(CultistAltarEntry.EVENT_ID,index)"),"fight reuses standard selected-monster deck")
	check(source.contains("func show_story_battle_result(event_id: String)"),"existing generic post-fight scene used")
	check(source.contains("session.pending_story_battle_event_id()"),"battle result survives reconnect")
	check(not source.contains("complete_cultist_altar_event("),"no later event completion handler")
	check(not source.contains("pass_cultist_altar_encounter("),"pass branch remains untouched")

func enemy_selection() -> void:
	var s=fixture("enemy_random")
	var rng=RandomNumberGenerator.new()
	rng.seed=1712305
	for n in range(25):
		var slugs: Array=Enemies.select(s.world.definitions,rng)
		check(Enemies.valid(s.world.definitions,slugs),"random set %d: four unique with elite lead and no special" % n)
	var tiny: Dictionary={
		"death-knight":{"grade":"hero"},
		"plague-doctor":{"grade":"advanced"},
		"ghoul":{"grade":"normal"},
		"skeleton-spear":{"grade":"normal"}
	}
	check(Enemies.select(tiny,rng).size()==4,"valid 4-unit catalog can roll")
	check(Enemies.valid(tiny,Enemies.select(tiny,rng)),"4-unit catalog preserves elite lead")
	check(Enemies.select({"ghoul":{"grade":"normal"}},rng).is_empty(),"missing fallback catalog fails closed")
	check(not Enemies.valid(s.world.definitions,["ghoul","ghoul","ghoul","ghoul"]),"duplicates forbidden")
	check(not Enemies.valid(s.world.definitions,["ghoul","death-knight","plague-doctor","skeleton-spear"]),"first enemy must be elite")
	s.free()

func fight(winner: String,on_event_tile: bool) -> void:
	var s=fixture(winner+("_event" if on_event_tile else "_altar"),on_event_tile)
	var at: int=s.world.position
	var unit: String=str(s.world.roster[0].id)
	check(Registry.can_start(s.world,s.get_story_event(Altar.EVENT_ID),at,Registry.definition(Altar.EVENT_ID)),"registered fight gate accepts saved choice")
	check(s.start_story_encounter(Altar.EVENT_ID,at,[unit]),"actual battle starts from owned deck")
	check(s.encounter.get("event_id","")==Altar.EVENT_ID,"encounter bound to altar event")
	check(s.encounter.get("type","")=="event-cultist-altar","encounter has source event type")
	var enemy_slugs: Array=[]
	for enemy in s.encounter.enemies: enemy_slugs.append(str(enemy.slug))
	check(Enemies.valid(s.world.definitions,enemy_slugs),"combat snapshot has randomized four unique source-grade enemies")
	var snapshot: Dictionary=s.world.snapshot().duplicate(true)
	s.reload_world()
	check(s.encounter.enemies.size()==4,"reconnect resumes four-enemy fight")
	var reopened: Array=[]
	for enemy in s.encounter.enemies: reopened.append(str(enemy.slug))
	check(reopened==enemy_slugs,"reconnect cannot reroll already committed enemies")
	check(s.encounter==s.world.active_encounter,"reloaded battle matches saved in-memory encounter")
	check(not s.encounter.checkpoint.is_empty(),"real combat checkpoint remains populated")
	check(str(s.world.rng.state)==str(snapshot.rng_state),"reconnect preserves committed enemy-selection RNG state")
	var restored_rules=load("res://systems/battlefield_rules.gd").new(s.world.definitions)
	check(restored_rules.restore(s.encounter.checkpoint),"combat rules can resume persisted encounter snapshot")
	check(s.finish_encounter(BattleResult.new(winner)),"generic combat end persists outcome")
	var result: String="won" if winner=="ally" else "lost"
	check(s.get_story_event(Altar.EVENT_ID).battle_result==result,"canonical win/loss recorded")
	check(s.get_story_event(Altar.EVENT_ID).status=="active","follow-up not completed")
	check(s.event_flag_is_set("battle:cultist_altar_encounter_01:"+result),"correct battle result receipt")
	check(s.event_flag_is_set(Registry.definition(Altar.EVENT_ID).pending_flag),"result scene remains pending")
	check(s.pending_story_battle_event_id()==Altar.EVENT_ID,"generic return renderer selects altar result")
	check(s.story_battle_presentation(Altar.EVENT_ID).overlay==Beats.SUMMON,"result uses original summon art")
	check(s.encounter.is_empty() and s.world.active_encounter.is_empty(),"combat cleared after result")
	check(not s.event_flag_is_set(Altar.COMPLETE_FLAG),"fight never grants altar completion")
	check(not s.event_flag_is_set(Altar.RITUAL_CONFIRMED_FLAG),"fight never confirms ritual quest")
	check(not s.event_flag_is_set(Altar.RITUAL_TRACKING_FLAG),"fight never activates follow-up quest")
	check(not Altar.reconsider(s,at),"committed fight cannot be changed to pass")
	check(not s.start_story_encounter(Altar.EVENT_ID,at,[unit]),"unacknowledged result cannot launch duplicate")
	s.reload_world()
	check(s.pending_story_battle_event_id()==Altar.EVENT_ID,"result notification survives reconnect")
	check(s.acknowledge_story_battle_result(Altar.EVENT_ID),"player acknowledges combat result")
	check(s.pending_story_battle_event_id().is_empty(),"acknowledgement hides result exactly once")
	check(Altar.can_enter(s,at),"completed combat history still readable for later follow-up")
	check(Altar.current_beat(s)==2,"reopening keeps same ritual choice checkpoint")
	if winner=="enemy":
		check(s.start_story_encounter(Altar.EVENT_ID,at,[unit]),"loss can retry after acknowledgement")
		check(s.get_story_event(Altar.EVENT_ID).battle_result.is_empty(),"retry clears previous loss only on new committed battle")
	else:
		check(not s.start_story_encounter(Altar.EVENT_ID,at,[unit]),"win cannot duplicate battle")
	s.free()

func fail_closed() -> void:
	var s=fixture("rollback")
	var at: int=s.world.position
	var selected: Array=[s.world.roster[0].id]
	var before: Dictionary=s.world.snapshot().duplicate(true)
	var good: String=s.save_file_path
	s.save_file_path="user://cultist_battle_missing_%d/failed.json" % OS.get_process_id()
	check(not s.start_story_encounter(Altar.EVENT_ID,at,selected),"failed save blocks battle launch")
	check(s.world.snapshot()==before,"battle RNG and all state rollback on save failure")
	check(s.encounter.is_empty(),"failed save leaves no active encounter")
	s.save_file_path=good
	check(s.start_story_encounter(Altar.EVENT_ID,at,selected),"battle retry after storage recovery succeeds")
	check(not s.start_story_encounter(Altar.EVENT_ID,at,selected),"active fight blocks duplicate battle")
	s.free()
	var p=fixture("pass_guard")
	var i: int=p.world.position
	check(Altar.reconsider(p,i),"fight intent changed before any combat")
	check(Altar.choose(p,i,2,"pass"),"pass intent saved for combat guard")
	check(not p.start_story_encounter(Altar.EVENT_ID,i,[p.world.roster[0].id]),"pass choice can never launch fight")
	check(not p.event_flag_is_set(Altar.RITUAL_TRACKING_FLAG),"pass remains unresolved")
	p.free()

func _run() -> void:
	art_and_contract()
	enemy_selection()
	fight("ally",false)
	fight("enemy",true)
	fail_closed()
	for path in paths: cleanup(path)
	print("CULTIST_ALTAR_BATTLE_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
