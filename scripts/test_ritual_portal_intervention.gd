extends SceneTree
## P1-05J-5: canonical intervention, hero-first enemies, real combat and no early revival.
const SessionScript=preload("res://systems/run_session.gd")
const Rumor=preload("res://systems/cultist_rumor_entry.gd")
const Altar=preload("res://systems/cultist_altar_entry.gd")
const Portal=preload("res://systems/ritual_portal_entry.gd")
const Beats=preload("res://systems/ritual_portal_beats.gd")
const Registry=preload("res://systems/story_battle_registry.gd")
const Enemies=preload("res://systems/ritual_portal_enemies.gd")

class BattleResult:
	extends RefCounted
	var outcome: String
	var units: Array=[]
	func _init(who: String) -> void: outcome=who
	func winner() -> String: return outcome
	func find_id(_id: String) -> Dictionary: return {}

var passed: int=0
var failed: int=0
var paths: Array[String]=[]

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, reason: String) -> void:
	if ok:
		passed+=1
		print("PASS ritual-portal-intervention: ",reason)
	else:
		failed+=1
		printerr("FAIL ritual-portal-intervention: ",reason)

func cleanup(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func fixture(tag: String, tile: String="forest"):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://ritual_portal_intervention_%d_%s.json" % [OS.get_process_id(),tag]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	s.world.story_events[Rumor.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	s.world.event_flags[Rumor.SEEN_FLAG]=true
	s.world.event_flags[Rumor.COMPLETE_FLAG]=true
	s.world.event_flags[Rumor.TRACKING_FLAG]=true
	s.world.position=s.world.tiles.find("altar")
	check(s.save_world(),"previous cultist chain established")
	var altar_index: int=s.world.position
	check(Altar.begin(s,altar_index),"altar first visit saved")
	check(Altar.advance(s,altar_index,0),"altar ritual scene saved")
	check(Altar.advance(s,altar_index,1),"altar choice saved")
	check(Altar.choose(s,altar_index,2,"pass"),"altar pass saved")
	check(Altar.finish(s,altar_index),"tracking quest legitimately activated")
	s.world.position=s.world.tiles.find(tile)
	check(s.world.position>=0,"source forest/event tile exists")
	check(s.save_world(),"portal landing stored")
	var at: int=s.world.position
	check(Portal.begin(s,at),"portal first arrival saved")
	for beat in [0,1,2,3]:
		check(Portal.advance(s,at,beat),"portal beat %d saved" % (beat+1))
	check(Portal.current_beat(s)==4,"fifth scene opened without choosing battle")
	return s

func source_contract() -> void:
	check(Beats.count()==5,"all five original beats, no extra scenes")
	check(Beats.beat(4).id=="intervene","canonical fifth beat id")
	check(Beats.beat(4).effect=="의식은 마지막 단계다. 지금 광신도들을 쓰러뜨리면 완전한 부활만큼은 막을 수 있다.","original fifth narration exact")
	check(Beats.beat(4).dialogue=="[마물의 왕 부활 의식을 저지합니다.]","original system dialogue exact")
	check(Beats.beat(4).speaker=="시스템","original dialogue speaker")
	check(Beats.beat(4).visual=="omen","intervention retains the original omen")
	check(Beats.beat(4).battleReady==true,"only fifth beat indicates combat available")
	check(Beats.beat(3).get("battleReady",false)!=true,"fourth omen alone cannot start battle")
	check(Beats.beat(5).is_empty(),"no invented sixth scene")
	check(Beats.INTERVENTION_EFFECT=="광신도들이 남은 힘을 전이문에 쏟아붓는다. 완전한 부활을 막기 위한 마지막 저지전이 시작된다.","original transition narration exact")
	check(Beats.layer_for("omen")==Beats.OMEN_ART,"omen art retained")
	check(Portal.progress_flag(4)=="event:ritual_portal_trace_01:beat:4","fifth scene has a distinct saved checkpoint")
	check(Portal.progress_flag(5).is_empty(),"later outcomes cannot be written as a visual beat")
	var spec: Dictionary=Registry.definition(Portal.EVENT_ID)
	check(Registry.valid_definition(spec),"real portal story battle definition registered")
	check(spec.encounter_type=="event-ritual-portal","source encounter type")
	check(spec.tiles==["forest","event"],"original eligible tiles")
	check(spec.choice=="intervene","battle requires saved intervention choice")
	check(spec.enemy_selection=="ritual_portal","hero-first four enemy selection policy")
	check(spec.retry_after_loss==false,"original loss is final rather than retryable")
	check(spec.enemies==["death-knight","doom-executor","plague-doctor","hydra"],"source fallback roster retained")
	check(spec.outcomes.won.status=="active" and spec.outcomes.lost.status=="active","both results defer actual king revival")
	check(not spec.outcomes.won.presentation.retry and not spec.outcomes.lost.presentation.retry,"win and loss are irreversible source outcomes")
	for result in ["won","lost"]:
		check(not spec.outcomes[result].flags.has(Portal.REVIVED_FLAG),"outcome does not prematurely revive king")
		check(not spec.outcomes[result].flags.has(Portal.TRACKING_COMPLETE_FLAG),"outcome does not prematurely complete quest")
		check(not spec.outcomes[result].flags.has(Portal.HUNT_FLAG),"outcome does not activate king hunt")
	check(ResourceLoader.exists(Beats.OMEN_ART),"original omen art still exists")
	var src: String=FileAccess.get_file_as_string("res://map.gd")
	check(src.contains('if beat_index<4:'),"Continue only on first four scenes")
	check(src.contains('location_button(panel,"저지한다"'),"fifth scene offers explicit intervention")
	check(src.contains("RitualPortalEntry.choose_intervention(session,index,shown_beat)"),"choice saved before deck picker")
	check(src.contains("get_tree().create_timer(0.76)"),"original brief omen-to-battle transition preserved")
	check(src.contains("show_story_battle_deck(RitualPortalEntry.EVENT_ID,index)"),"existing 1–4 owned-monster deck reused")
	check(src.contains('location_button(panel,"출전 마물 선택"'),"reconnect can reopen deck selection")
	check(src.contains('session.get_story_event(RitualPortalEntry.EVENT_ID).status in ["seen","active"]'),"saved chosen scene resumes")
	check(not src.contains("complete_ritual_portal("),"no premature revival scene resolver")

func selector_contract() -> void:
	var s=fixture("enemy", "forest")
	var rng=RandomNumberGenerator.new()
	rng.seed=60125
	for i in range(16):
		var slugs: Array=Enemies.select(s.world.definitions,rng)
		check(Enemies.valid(s.world.definitions,slugs),"random enemies %d: four unique; hero first if possible" % i)
	var tiny: Dictionary={"hero-a":{"grade":"hero"},"hero-b":{"grade":"hero"},"elite":{"grade":"advanced"},"common":{"grade":"normal"}}
	check(Enemies.valid(tiny,Enemies.select(tiny,rng)),"test catalog chooses a hero first")
	check(not Enemies.valid(tiny,["common","hero-a","elite","hero-b"]),"nonhero first is forbidden when heroes exist")
	var fallback: Dictionary={"elite":{"grade":"advanced"},"common1":{"grade":"normal"},"common2":{"grade":"normal"},"common3":{"grade":"normal"}}
	check(Enemies.valid(fallback,Enemies.select(fallback,rng)),"advanced anchor used if heroes unavailable")
	check(Enemies.select({"single":{"grade":"normal"}},rng).is_empty(),"incomplete catalog fails closed")
	s.free()

func real_battle(winner: String, tile: String) -> void:
	var s=fixture(winner+"_"+tile,tile)
	var at: int=s.world.position
	var unit: String=str(s.world.roster[0].id)
	check(not s.start_story_encounter(Portal.EVENT_ID,at,[unit]),"fifth beat alone cannot launch combat")
	check(not Portal.choose_intervention(s,at,3),"earlier beat index cannot select fight")
	check(Portal.choose_intervention(s,at,4),"intervention intent saved by deliberate click")
	check(s.get_story_event(Portal.EVENT_ID).status=="active" and s.get_story_event(Portal.EVENT_ID).choice=="intervene","source choice and status persisted")
	check(s.event_flag_is_set(Portal.INTERVENE_CHOICE_FLAG),"choice receipt persisted")
	check(s.encounter.is_empty(),"selecting intervention does not auto-start fight")
	s.reload_world()
	check(Portal.can_enter(s,at) and Portal.current_beat(s)==4,"saved declaration reopens fifth scene")
	check(s.get_story_event(Portal.EVENT_ID).choice=="intervene","saved declaration survives restart")
	check(not Portal.choose_intervention(s,at,4),"repeating choice not permitted")
	check(s.start_story_encounter(Portal.EVENT_ID,at,[unit]),"owned-monster deck starts real portal fight")
	var enemy_slugs: Array=[]
	for unit_data in s.encounter.enemies: enemy_slugs.append(str(unit_data.slug))
	check(Enemies.valid(s.world.definitions,enemy_slugs),"combat snapshot has four source-grade unique enemies with hero anchor")
	check(s.encounter.event_id==Portal.EVENT_ID and s.encounter.type=="event-ritual-portal","battle tagged with canonical portal identity")
	var rng_state: String=str(s.world.rng.state)
	s.reload_world()
	var persisted: Array=[]
	for unit_data in s.encounter.enemies: persisted.append(str(unit_data.slug))
	check(persisted==enemy_slugs,"reconnect restores exact committed enemy draw")
	check(str(s.world.rng.state)==rng_state,"reconnect preserves enemy-roll RNG")
	check(s.finish_encounter(BattleResult.new(winner)),"real battle result saved")
	var result: String="won" if winner=="ally" else "lost"
	check(s.get_story_event(Portal.EVENT_ID).battle_result==result,"correct battle result recorded")
	check(s.get_story_event(Portal.EVENT_ID).status=="active","battle result does not complete the portal story")
	check(s.event_flag_is_set("battle:ritual_portal_trace_01:"+result),"corresponding win/loss receipt")
	check(s.story_battle_result_pending(Portal.EVENT_ID),"result presentation pending after battle")
	check(s.pending_story_battle_event_id()==Portal.EVENT_ID,"reconnect uses existing result dispatcher")
	check(s.story_battle_presentation(Portal.EVENT_ID).overlay==Beats.OMEN_ART,"result screen uses existing omen layer")
	check(not s.event_flag_is_set(Portal.COMPLETE_FLAG),"battle alone does not finish event")
	check(not s.event_flag_is_set(Portal.PORTAL_FOUND_FLAG),"portal clue is later")
	check(not s.event_flag_is_set(Portal.TRACKING_COMPLETE_FLAG),"ritual quest still unfinished")
	check(not s.event_flag_is_set(Portal.REVIVED_FLAG),"king has not revived")
	check(not s.event_flag_is_set(Portal.HUNT_FLAG),"hunt remains locked")
	check(not s.start_story_encounter(Portal.EVENT_ID,at,[unit]),"pending result cannot be bypassed")
	s.reload_world()
	check(s.pending_story_battle_event_id()==Portal.EVENT_ID,"result pending survives reload")
	check(s.acknowledge_story_battle_result(Portal.EVENT_ID),"player can close the result scene")
	check(not s.story_battle_result_pending(Portal.EVENT_ID),"result notice acknowledged once")
	check(Portal.can_enter(s,at),"fifth story remains resumable for future revival consequence")
	check(not s.start_story_encounter(Portal.EVENT_ID,at,[unit]),"irreversible win/loss cannot repeat battle")
	s.free()

func fail_closed() -> void:
	var s=fixture("guards","event")
	var at: int=s.world.position
	var base: Dictionary=s.world.snapshot().duplicate(true)
	var real_path: String=s.save_file_path
	s.save_file_path="user://ritual_intervention_missing_%d/failed.json" % OS.get_process_id()
	check(not Portal.choose_intervention(s,at,4),"save failure blocks declaration")
	check(s.world.snapshot()==base,"declaration state and receipt rollback")
	check(not s.event_flag_is_set(Portal.INTERVENE_CHOICE_FLAG),"no phantom choice on failed save")
	s.save_file_path=real_path
	s.world.pending_reward={"kind":"test"}
	check(not Portal.choose_intervention(s,at,4),"pending reward blocks intervention")
	s.world.restore(base)
	s.world.pending_move={"test":true}
	check(not Portal.choose_intervention(s,at,4),"pending movement blocks intervention")
	s.world.restore(base)
	s.world.story_events[Portal.EVENT_ID].choice="intervene"
	check(not Portal.choose_intervention(s,at,4),"fabricated fifth choice blocked")
	s.world.restore(base)
	check(Portal.choose_intervention(s,at,4),"retry after storage recovery can commit choice")
	s.free()

func _run() -> void:
	source_contract()
	selector_contract()
	real_battle("ally","forest")
	real_battle("enemy","event")
	fail_closed()
	for path in paths: cleanup(path)
	print("RITUAL_PORTAL_INTERVENTION_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
