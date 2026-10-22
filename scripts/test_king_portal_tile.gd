extends SceneTree
## New fifth-beat surrender and actual intervention loss turn only another
## warp painting through five user-art frames. No hero/route/game-over changes.
const SessionScript=preload("res://systems/run_session.gd")
const Rumor=preload("res://systems/cultist_rumor_entry.gd")
const Altar=preload("res://systems/cultist_altar_entry.gd")
const Portal=preload("res://systems/ritual_portal_entry.gd")
const Hunt=preload("res://systems/monster_king_hunt_entry.gd")
const Encounter=preload("res://systems/king_portal_encounter.gd")
const KingTile=preload("res://systems/king_portal_tile.gd")

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
func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
	else:
		failed+=1
		printerr("FAIL king-warp: ",label)
func cleanup(p: String) -> void:
	for ext in ["",".tmp"]:
		if FileAccess.file_exists(p+ext): DirAccess.remove_absolute(ProjectSettings.globalize_path(p+ext))

func fixture(tag: String):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://king_warp_%d_%s.json" % [OS.get_process_id(),tag]
	paths.append(path)
	cleanup(path)
	s.save_file_path=path
	s.start_new_world()
	s.world.contamination=93
	s.world.lap_ready=true
	s.world.leave_home()
	var altar: int=s.world.tiles.find("basic")
	check(altar>=0,"a road exists for prior canonical altar")
	if altar<0: return s
	s.world.tiles[altar]="altar"
	s.world.story_events[Rumor.EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	s.world.event_flags[Rumor.SEEN_FLAG]=true
	s.world.event_flags[Rumor.COMPLETE_FLAG]=true
	s.world.event_flags[Rumor.TRACKING_FLAG]=true
	s.world.position=altar
	check(s.save_world(),"predecessor rumor saved")
	check(Altar.begin(s,altar),"altar begins")
	check(Altar.advance(s,altar,0),"altar beat 1")
	check(Altar.advance(s,altar,1),"altar beat 2")
	check(Altar.choose(s,altar,2,"pass"),"altar pass chosen")
	check(Altar.finish(s,altar),"altar ritual confirmed")
	var at: int=s.world.tiles.find("event")
	check(at>=0,"eligible portal event present")
	s.world.position=at
	check(s.save_world(),"portal landing saved")
	check(Portal.begin(s,at),"portal entered")
	for i in range(4): check(Portal.advance(s,at,i),"fifth scene reached through beat %d" % i)
	return s

func art_contract() -> void:
	check(KingTile.PATHS.size()==5,"exact five visual stages")
	for p in KingTile.PATHS:
		check(ResourceLoader.exists(p),"tile texture exists: "+str(p))
		var tex: Texture2D=load(p)
		check(tex!=null and tex.get_width()==120 and tex.get_height()==90,"tile is board-native 120x90")
	var src: String=FileAccess.get_file_as_string("res://map.gd")
	check(src.contains('location_button(panel,"저지하지 않는다"'),"last scene offers explicit refusal")
	check(src.contains("await animate_king_warp_tile()"),"sequence awaits the map tile")
	check(src.contains("func tile_path(index: int) -> String:"),"saved final art applies on every redraw")
	check(src.contains('session.get_story_event(RitualPortalEntry.EVENT_ID).battle_result=="lost"'),"only ritual combat loss gets game-over prelude")

func refusal() -> void:
	var s=fixture("refusal")
	var at: int=s.world.position
	check(s.world.tiles.count("warp")==2,"two warp stones retained")
	check(not KingTile.active(s.world),"preview and four Continue presses never mark warp")
	var before: Dictionary=s.world.snapshot().duplicate(true)
	var good: String=s.save_file_path
	s.save_file_path="user://king_warp_missing_%d/snapshot.json" % OS.get_process_id()
	check(not Portal.decline_intervention(s,at,4),"unwritable save rejects refusal")
	check(s.world.snapshot()==before,"failed save rolls back stage and ritual flags")
	s.save_file_path=good
	var state: int=s.world.rng.state
	var board: Array=s.world.tiles.duplicate()
	check(Portal.decline_intervention(s,at,4),"fifth-beat refusal saved")
	check(Portal.completed(s),"decline is coherent completed ritual")
	check(not s.event_flag_is_set(Portal.WEAKENED_FLAG) and s.event_flag_is_set(Portal.FULL_REVIVAL_FLAG),"refusal means full revival")
	check(not s.event_flag_is_set(Portal.INTERVENE_CHOICE_FLAG),"does not forge intervention")
	var target: int=KingTile.target(s.world)
	check(target>=0 and target!=at and s.world.tiles[target]=="warp","another warp is chosen, not hero")
	check(s.world.tiles==board and s.world.tiles.count("warp")==2,"visual change never changes topology")
	check(s.world.rng.state==state,"refusal does not consume map RNG")
	check(KingTile.texture_path(s.world,target)==KingTile.PATHS[4],"persisted final painting selected")
	check(not Portal.decline_intervention(s,at,4),"second refusal cannot replay")
	s.reload_world()
	check(Portal.completed(s) and KingTile.target(s.world)==target,"refusal and target survive restart")
	check(s.world.tiles==board,"same board after restart")
	s.world.generate()
	check(KingTile.target(s.world)>=0 and s.world.tiles[KingTile.target(s.world)]=="warp","new board shuffle rebinds artwork onto warp")
	check(s.world.tiles.count("warp")==2,"shuffle retains both ordinary warp mechanics")
	s.free()

func subsequent_hunt_after_refusal() -> void:
	var s=fixture("surrender_to_hunt")
	var at: int=s.world.position
	check(Portal.decline_intervention(s,at,4),"refusal prepares full-revival story")
	check(not s.world.boss_available(),"a surrendered ritual alone never reveals the final boss")
	check(Hunt.can_enter(s,at),"hunt can start after non-intervention without forged battle")
	check(Hunt.begin(s,at),"real hunt story begins")
	for i in range(3): check(Hunt.advance(s,at,i),"hunt beat %d saved" % i)
	check(Hunt.finish(s,at),"real fifth hunt scene persisted")
	check(not s.world.boss_available(),"final king-hunt screen still needs explicit Finish acknowledgment")
	check(Hunt.acknowledge_completion(s,at),"hunt final screen deliberately acknowledged")
	check(s.world.boss_available(),"full revival + 80 contamination + actual hunt opens boss")
	check(s.world.tiles[23]!="boss","no duplicate boss at old fixed slot")
	var target: int=KingTile.target(s.world)
	check(target>=0 and target!=at and s.world.tiles[target]=="warp" and target!=23,"king visual remains a different warp, never the boss stone")
	s.reload_world()
	check(s.world.boss_available() and KingTile.target(s.world)==target,"single warped boss destination survives save reload")
	s.free()

func final_boss_warp(side: String) -> void:
	var s=fixture("final_"+side)
	var at: int=s.world.position
	# Victory at the first ritual must also lead to a painted final warp,
	# but only after the original five-scene hunt is acknowledged.
	if side=="ally":
		check(Portal.choose_intervention(s,at,4),"original intervention chosen")
		check(s.start_story_encounter(Portal.EVENT_ID,at,[s.world.roster[0].id]),"ritual combat started")
		check(s.finish_encounter(BattleResult.new("ally")),"ritual combat won")
		check(s.acknowledge_story_battle_result(Portal.EVENT_ID),"ritual outcome acknowledged")
		check(Portal.finish(s,at),"weakened revival saved")
		check(not KingTile.active(s.world),"successful earlier defense has no premature transformed warp")
	else:
		check(Portal.decline_intervention(s,at,4),"full revival via voluntary non-intervention")
		check(KingTile.active(s.world),"declining ritual already paints a different warp")
	check(Hunt.begin(s,at),"hunt begins after valid portal ending")
	for i in range(3): check(Hunt.advance(s,at,i),"hunt stage %d" % i)
	check(Hunt.finish(s,at),"hunt fifth scene is ready")
	check(not s.world.boss_available(),"unacknowledged hunt does not open fight")
	check(Hunt.acknowledge_completion(s,at),"explicit hunt final Finish opens last encounter")
	check(s.world.boss_available(),"final king hunt and pollution 80 unlock boss")
	var target: int=KingTile.target(s.world)
	check(target>=0 and target!=at and s.world.tiles[target]=="warp","only the painted warp is the boss location")
	check(s.world.tiles[23]!="boss" and s.world.tiles.count("boss")==0,"old fixed boss slot remains inactive")
	# The shifted final boss must not consume one of the 21 movable stones
	# when HOME regenerates an entire 24-slot map.
	s.world.generate()
	check(s.world.tiles.size()==24 and s.world.tiles.all(func(tile): return tile is String and not tile.is_empty()),"full shuffled map has exactly 24 valid stones with boss on warp")
	check(s.world.tiles.count("warp")==2 and s.world.tiles.count("boss")==0,"reshuffle keeps both warps and no ghost 24th-slot boss")
	target=KingTile.target(s.world)
	check(target>=0 and s.world.tiles[target]=="warp","reshuffled king portal still targets a valid warp")
	s.world.position=target
	check(s.save_world(),"arrival at transformed warp is persisted")
	check(Encounter.can_enter(s,target),"actual current location is eligible")
	check(Encounter.begin(s,target),"first scene receipt")
	check(Encounter.beat(s.world)==0,"first encounter beat visible")
	check(not Encounter.battle_ready(s.world,target),"final boss is not automatic on arrival")
	check(Encounter.advance(s,target,0),"second scene saved")
	check(Encounter.advance(s,target,1),"third scene saved")
	check(Encounter.acknowledge(s,target),"final confrontation acknowledged")
	check(Encounter.battle_ready(s.world,target),"deck selector now allowed")
	var checkpoint: int=s.world.rng.state
	check(s.start_encounter(target,[s.world.roster[0].id]),"real encounter starts from altered warp")
	check(s.encounter.get("type","")=="boss","the warp encounter uses existing boss battle")
	check(s.encounter.get("enemies",[]).size()==1 and s.encounter.enemies[0].slug=="dragon","the actual enemy is the lone final dragon")
	check(s.encounter.enemies[0].get("boss_extra_passive","")=="undying" and s.encounter.enemies[0].passive=="bone","original two passives preserved")
	check(not s.start_encounter(target,[s.world.roster[0].id]),"boss cannot duplicate while battle is active")
	check(s.finish_encounter(BattleResult.new("ally")),"dragon victory committed")
	check(s.world.event_flags.get(Encounter.WON,false)==true,"win written as durable one-time receipt")
	check(s.world.run_result.is_empty(),"dragon win does not game-over the expedition")
	check(not s.world.boss_available(),"winning removes boss availability forever")
	check(Encounter.ending_pending(s.world),"ending awaits deliberate confirmation")
	check(s.world.tiles.count("warp")==2,"ordinary two warp types preserved after victory")
	check(not s.start_encounter(target,[s.world.roster[0].id]),"beaten final boss never respawns")
	s.reload_world()
	check(Encounter.ending_pending(s.world),"crash/reopen before ending resumes the same ending")
	check(Encounter.acknowledge_ending(s),"user confirms the ending once")
	check(not Encounter.ending_pending(s.world),"accepted ending is not replayed")
	check(s.world.run_result.is_empty(),"expedition continues after ending")
	s.reload_world()
	check(s.world.event_flags.get(Encounter.ENDING_ACK,false)==true and not Encounter.ending_pending(s.world),"final victory receipt survives reload")
	s.free()

func final_boss_defeat() -> void:
	var s=fixture("dragon_lost")
	var at: int=s.world.position
	check(Portal.decline_intervention(s,at,4),"loss fixture ritual is deliberately allowed")
	check(Hunt.begin(s,at),"loss fixture final hunt begins")
	for i in range(3): check(Hunt.advance(s,at,i),"loss fixture hunt stage")
	check(Hunt.finish(s,at),"loss fixture hunt ends")
	check(Hunt.acknowledge_completion(s,at),"loss fixture final acknowledgment")
	var target: int=KingTile.target(s.world)
	s.world.position=target
	check(s.save_world(),"loss fixture reaches painted warp")
	check(Encounter.begin(s,target),"loss fixture king face-to-face")
	check(Encounter.advance(s,target,0),"loss fixture second beat")
	check(Encounter.advance(s,target,1),"loss fixture third beat")
	check(Encounter.acknowledge(s,target),"loss fixture combat enabled")
	check(s.start_encounter(target,[s.world.roster[0].id]),"loss fixture real dragon combat")
	check(s.finish_encounter(BattleResult.new("enemy")),"actual final boss combat lost")
	check(not s.world.run_result.is_empty(),"dragon loss still permanently ends expedition")
	check(not Encounter.ending_pending(s.world) and s.world.event_flags.get(Encounter.WON,false)!=true,"defeat does not forge victory/ending")
	s.reload_world()
	check(not s.world.run_result.is_empty(),"dragon defeat persists after restart")
	s.free()

func legacy_fixed_boss_upgrade() -> void:
	var s=fixture("legacy_slot")
	var at: int=s.world.position
	check(Portal.decline_intervention(s,at,4),"old slot fixture has a complete ritual")
	check(Hunt.begin(s,at),"old slot fixture enters hunt")
	for i in range(3): check(Hunt.advance(s,at,i),"old slot fixture hunt beat")
	check(Hunt.finish(s,at),"old slot fixture completes hunt")
	check(Hunt.acknowledge_completion(s,at),"old slot fixture has complete final quest")
	for key in s.world.event_flags.keys():
		if str(key)=="visual:ritual_portal:king_warp_active" or str(key).begins_with("visual:ritual_portal:king_warp_index:"):
			s.world.event_flags.erase(key)
	# Simulate a genuine v1 pre-migration board: last boss in stone 23.
	s.world.generate()
	check(s.world.tiles[23]=="boss" and s.world.tiles.count("warp")==2,"historical saved board has a fixed boss plus two valid warps")
	var old_position: int=s.world.position
	var old_state: int=s.world.rng.state
	check(s.save_world(),"old v1 boss board persisted")
	s.reload_world()
	check(KingTile.target(s.world)>=0 and s.world.tiles[23]!="boss","old unlocked boss relocates to a different warp")
	check(s.world.position==old_position and s.world.rng.state==old_state,"old save upgrade preserves hero/RNG")
	check(s.world.tiles.count("warp")==2 and s.world.tiles.size()==24,"old save retains 24 slots and both warps")
	s.free()

func battle_outcome(side: String) -> void:
	var s=fixture(side)
	var at: int=s.world.position
	check(Portal.choose_intervention(s,at,4),"player actually chooses to block")
	check(not KingTile.active(s.world),"choosing battle is not a loss")
	check(s.start_story_encounter(Portal.EVENT_ID,at,[s.world.roster[0].id]),"ritual fight really starts")
	check(not KingTile.active(s.world),"battle start does not animate")
	check(s.finish_encounter(BattleResult.new(side)),"real recorded battle outcome")
	var failed_battle: bool=side=="enemy"
	check(KingTile.active(s.world)==failed_battle,"only actual defeat activates remote tile")
	check((not s.world.run_result.is_empty())==failed_battle,"real defeat preserves immediate game-over rule")
	if failed_battle:
		var target: int=KingTile.target(s.world)
		check(target>=0 and target!=at and s.world.tiles[target]=="warp","defeat targets another warp")
		s.reload_world()
		check(KingTile.target(s.world)==target and not s.world.run_result.is_empty(),"defeat and visual state survive reload")
	else:
		check(s.story_battle_result_pending(Portal.EVENT_ID),"victory still requires outcome acknowledgment")
	s.free()

func _run() -> void:
	art_contract()
	refusal()
	subsequent_hunt_after_refusal()
	final_boss_warp("ally")
	final_boss_warp("allow")
	final_boss_defeat()
	legacy_fixed_boss_upgrade()
	battle_outcome("ally")
	battle_outcome("enemy")
	for p in paths: cleanup(p)
	print("KING_PORTAL_TILE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
