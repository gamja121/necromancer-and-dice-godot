extends SceneTree
## New fifth-beat surrender and actual intervention loss turn only another
## warp painting through five user-art frames. No hero/route/game-over changes.
const SessionScript=preload("res://systems/run_session.gd")
const Rumor=preload("res://systems/cultist_rumor_entry.gd")
const Altar=preload("res://systems/cultist_altar_entry.gd")
const Portal=preload("res://systems/ritual_portal_entry.gd")
const Hunt=preload("res://systems/monster_king_hunt_entry.gd")
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
	check(s.world.tiles[23]=="boss","fixed final boss slot revealed")
	var target: int=KingTile.target(s.world)
	check(target>=0 and target!=at and s.world.tiles[target]=="warp" and target!=23,"king visual remains a different warp, never the boss stone")
	s.reload_world()
	check(s.world.boss_available() and KingTile.target(s.world)==target,"boss and separate painted warp survive save reload")
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
	battle_outcome("ally")
	battle_outcome("enemy")
	for p in paths: cleanup(p)
	print("KING_PORTAL_TILE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
