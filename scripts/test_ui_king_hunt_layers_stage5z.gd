extends SceneTree
## Stage 5Z: authentic source quest chain, both king revival outcomes,
## five hunt images, source CSS geometry/motion, restart, acknowledgement.
## World positions alone are shortened to reach valid story destinations.
const MAP=preload("res://map.tscn")
const SESSION=preload("res://systems/run_session.gd")
const CHILD=preload("res://systems/story_event_entry.gd")
const RUMOR=preload("res://systems/village_rumor_entry.gd")
const RUMOR_BEATS=preload("res://systems/village_rumor_beats.gd")
const COMMANDER=preload("res://systems/knight_commander_entry.gd")
const COMMANDER_BEATS=preload("res://systems/knight_commander_beats.gd")
const HUNTER=preload("res://systems/monster_hunter_entry.gd")
const HUNTER_BEATS=preload("res://systems/monster_hunter_beats.gd")
const CULTIST=preload("res://systems/cultist_rumor_entry.gd")
const CULTIST_BEATS=preload("res://systems/cultist_rumor_beats.gd")
const ALTAR=preload("res://systems/cultist_altar_entry.gd")
const PORTAL=preload("res://systems/ritual_portal_entry.gd")
const PORTAL_BEATS=preload("res://systems/ritual_portal_beats.gd")
const HUNT=preload("res://systems/monster_king_hunt_entry.gd")
const BEATS=preload("res://systems/monster_king_hunt_beats.gd")
const MOTION=preload("res://systems/monster_hunter_layer_motion.gd")
var passed:int=0
var failed:int=0
var scratch:String=""

class Outcome:
	extends RefCounted
	# Current RunSession.finish_encounter inspects battle.units before resolving.
	var units: Array = []
	var side:String
	func _init(result:String)->void:
		side=result
	func winner()->String:
		return side
	func find_id(_id:String)->Dictionary:
		return {}

func check(ok:bool,reason:String)->void:
	if ok:
		passed+=1
		print("PASS ui-king-hunt: ",reason)
	else:
		failed+=1
		printerr("FAIL ui-king-hunt: ",reason)

func approximately(a:float,b:float,tolerance:float=0.15)->bool:
	return absf(a-b)<tolerance

func clear_temp()->void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))

func art_layer(map:Control,name:String)->TextureRect:
	if not is_instance_valid(map.overlay):return null
	return map.overlay.get_node_or_null(name) as TextureRect

func button(map:Control,caption:String)->bool:
	if not is_instance_valid(map.overlay):return false
	return map.overlay.get_children().any(func(n):return n is Button and n.visible and n.text==caption)

func _initialize()->void:
	call_deferred("_run")

func _run()->void:
	var session=root.get_node_or_null("RunSession")
	var created:bool=session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var previous:String=session.save_file_path
	for mode in ["weakened","full"]:
		await verify_route(session,mode)
	session.save_file_path=previous
	if created:session.queue_free()
	print("UI_KING_HUNT_STAGE5Z: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)

func verify_route(session:Node,mode:String)->void:
	var tag:String=mode+": "
	scratch="user://ui_king_hunt_stage5z_%d_%s.json"%[OS.get_process_id(),mode]
	clear_temp()
	session.save_file_path=scratch
	session.start_new_world()
	# Test-only story gallery: newly gated locations do not all exist on
	# the opening board. Seed only missing places onto ordinary roads, leaving
	# production map generation, fixed anchors and story APIs untouched.
	for place in ["graveyard","unknown","altar"]:
		if not session.world.tiles.has(place):
			var ordinary: int = session.world.tiles.find("basic")
			if ordinary >= 0: session.world.tiles[ordinary] = place
	# This historical complete-chain presentation fixture is deliberately
	# evaluated after the real contamination gate has become eligible.
	session.world.contamination = 100
	# A genuine high-contamination save already contains its boss and swamp
	# transformations. Seed them now so reload_world does not change the
	# fixture at the final dialogue checkpoint (visual tests are read-only).
	session.world.reveal_boss_at_threshold()
	session.world.reveal_swamps_for_contamination()
	check(session.save_world(),"isolated visual-story fixture saved")
	var grave:int=session.world.tiles.find("graveyard")
	var village:int=session.world.tiles.find("village")
	var tree:int=session.world.tiles.find("unknown")
	var altar:int=session.world.tiles.find("altar")
	var forest:int=session.world.tiles.find("forest")
	check(grave>=0 and village>=0 and tree>=0 and altar>=0 and forest>=0,tag+"all isolated visual-story places exist")
	if grave<0 or village<0 or tree<0 or altar<0 or forest<0:
		clear_temp()
		return
	var map=MAP.instantiate()
	root.add_child(map)
	for k in range(4):await process_frame
	# No forged story completion flags or invented quest outcomes.
	session.world.position=grave
	check(CHILD.begin(session,grave),tag+"child encounter discovered in real game")
	check(CHILD.choose(session,grave,"protect_child"),tag+"child rescue selected")
	check(session.start_story_encounter(CHILD.EVENT_ID,grave,[session.world.roster[0].id]),tag+"real rescue story combat starts with owned monster")
	check(session.finish_encounter(Outcome.new("ally")),tag+"real rescue victory persisted via RunSession")
	check(session.acknowledge_graveyard_battle_result(),tag+"rescue acknowledgement persisted")
	session.world.position=village
	check(RUMOR.begin(session,village)==RUMOR.RESCUED_ID,tag+"rescued-child village rumor starts")
	for i in range(RUMOR_BEATS.count(RUMOR.RESCUED_ID)):
		check(RUMOR.advance(session,village,RUMOR.RESCUED_ID,i),tag+"rescued rumor beat %d saved"%i)
	check(COMMANDER.begin(session,village),tag+"commander starts after saved child rumor")
	for i in range(COMMANDER_BEATS.count()):
		check(COMMANDER.advance(session,village,i),tag+"commander beat %d saved"%i)
	session.world.position=tree
	check(HUNTER.begin(session,tree),tag+"monster hunter starts after genuine commander completion")
	for i in range(HUNTER_BEATS.count()):
		check(HUNTER.advance(session,tree,i),tag+"hunter beat %d saved"%i)
	session.world.position=village
	check(CULTIST.begin(session,village),tag+"cultist rumor starts after original hunter clue")
	for i in range(CULTIST_BEATS.count()):
		check(CULTIST.advance(session,village,i),tag+"cultist rumor beat %d saved"%i)
	session.world.position=altar
	check(ALTAR.begin(session,altar),tag+"altar truly opens")
	check(ALTAR.advance(session,altar,0) and ALTAR.advance(session,altar,1),tag+"two saved altar revelation beats")
	check(ALTAR.choose(session,altar,2,"pass"),tag+"altar pass chosen explicitly")
	check(ALTAR.finish(session,altar) and ALTAR.completed(session),tag+"altar finish unlocks portal quest, no false flags")
	session.world.position=forest
	check(PORTAL.begin(session,forest),tag+"actual forest portal discovered")
	for i in range(PORTAL_BEATS.count()-1):
		check(PORTAL.advance(session,forest,i),tag+"portal source beat %d saved"%i)
	check(PORTAL.choose_intervention(session,forest,4),tag+"original intervention intent saved")
	check(session.start_story_encounter(PORTAL.EVENT_ID,forest,[session.world.roster[0].id]),tag+"real portal encounter started from owned card")
	var expected_victor:String="ally" if mode=="weakened" else "enemy"
	check(session.finish_encounter(Outcome.new(expected_victor)),tag+"portal "+expected_victor+" outcome recorded through real RunSession")
	check(session.story_battle_result_pending(PORTAL.EVENT_ID),tag+"battle outcome needs explicit player confirmation")
	check(session.acknowledge_story_battle_result(PORTAL.EVENT_ID),tag+"player result confirmation saved")
	check(PORTAL.aftermath_ready(session,forest),tag+"source after-battle result eligible")
	check(PORTAL.finish(session,forest) and PORTAL.completed(session),tag+"real Finish commits canonical king revival")
	check(session.world.event_flags.get(PORTAL.WEAKENED_FLAG,false)==(mode=="weakened"),tag+"weakened revival matches encounter victory")
	check(session.world.event_flags.get(PORTAL.FULL_REVIVAL_FLAG,false)==(mode=="full"),tag+"full revival matches encounter defeat")
	check(session.world.event_flags.get(PORTAL.HUNT_FLAG,false)==true,tag+"monster king hunt quest genuinely unlocked")
	session.world.position=tree
	check(HUNT.begin(session,tree),tag+"world-tree king hunt starts only after resolved revival")
	check(HUNT.current_beat(session)==0 and HUNT.revival_mode(session)==mode,tag+"hunt starts at first beat in real saved revival mode")

	var frame:Rect2=map.TILE_EVENT_SCENE_RECT
	var scene_bounds:Rect2=MOTION.source_rect(frame,false)
	var portrait_bounds:Rect2=MOTION.source_rect(frame,true)
	check(scene_bounds.position.distance_to(frame.position+frame.size*Vector2(0.13,0.04))<0.01,tag+"world-tree corrupted beast at left 13%, bottom 2%")
	check(portrait_bounds.position.distance_to(frame.position+frame.size*Vector2(0.40,0.01))<0.01,tag+"hunter portrait right 2%, bottom 25%")
	check(scene_bounds.size.distance_to(frame.size*Vector2(0.74,0.80))<0.01,tag+"world-tree source corpse image 74%x92%")
	check(portrait_bounds.size.distance_to(frame.size*Vector2(0.58,0.74))<0.01,tag+"hunter portrait CSS size 58%x78%")
	check(approximately(MOTION.SCENE_ENTRY_SECONDS,0.52,0.001) and approximately(MOTION.PORTRAIT_ENTRY_SECONDS,0.48,0.001),tag+"source trace/revival durations are 520/480ms")
	# Tests still verify original CSS fractions; render bounds follow the new left column.
	scene_bounds=map.StorySplit.map_art_rect(scene_bounds)
	portrait_bounds=map.StorySplit.map_art_rect(portrait_bounds)
	var receipts:Array=session.world.reward_receipts.duplicate(true)
	for i in range(BEATS.count()):
		var beat:Dictionary=BEATS.beat(i,mode)
		check(not beat.is_empty(),tag+"valid canonical beat %d for revival mode"%i)
		var snapshot:Dictionary=session.world.snapshot().duplicate(true)
		check(HUNT.current_beat(session)==i,tag+"actual saved beat %d recovered"%i)
		map.show_monster_king_hunt_beat(tree)
		check(is_instance_valid(map.overlay),tag+"beat %d opens actual world-tree scene"%i)
		var scene=art_layer(map,"KingHuntSceneLayer")
		var portrait=art_layer(map,"KingHuntPortrait")
		if i==0:
			check(scene==null and portrait==null,tag+"arrival leaves unnecessary hunter art hidden")
		else:
			var is_portrait:bool=str(beat.visual)=="portrait"
			var art:TextureRect=portrait if is_portrait else scene
			var bounds:Rect2=portrait_bounds if is_portrait else scene_bounds
			var animation:bool=beat.id==("revival" if is_portrait else "trace")
			check(art!=null and (scene==null or portrait==null),tag+"beat %d has only one source character/scene layer"%i)
			if art!=null:
				var path:String=BEATS.visual_art(str(beat.visual))
				check(art.texture==map.texture(path) and art.texture.resource_path==path,tag+"beat %d reuses existing unmodified hunter source WebP"%i)
				check(art.size.distance_to(bounds.size)<0.02 and art.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,tag+"beat %d retains updated safe footprint and image aspect"%i)
				check(art.mouse_filter==Control.MOUSE_FILTER_IGNORE and art.get_meta("ui_custom_open_motion",false),tag+"beat %d ignores touch and opts out of generic panel motion"%i)
				check(art.pivot_offset.distance_to(Vector2(art.size.x/2.0,art.size.y))<0.02,tag+"beat %d bottom-middle animation pivot"%i)
				var alpha:float=MOTION.PORTRAIT_OPACITY if is_portrait else 1.0
				if animation:
					var shift:Vector2=MOTION.PORTRAIT_START_OFFSET if is_portrait else MOTION.SCENE_START_OFFSET
					var scale_at_start:float=MOTION.PORTRAIT_START_SCALE if is_portrait else MOTION.SCENE_START_SCALE
					check(art.position.distance_to(bounds.position+art.size*shift)<0.15,tag+"beat %d starts at source CSS offset"%i)
					check(approximately(art.modulate.a,0,0.01) and approximately(art.scale.x,scale_at_start,0.01),tag+"beat %d starts transparent and reduced scale"%i)
					await create_timer(0.64).timeout
				else:
					check(art.position.distance_to(bounds.position)<0.15 and approximately(art.modulate.a,alpha,0.01),tag+"beat %d is source static: no repeated reveal"%i)
				check(art.position.distance_to(bounds.position)<0.8 and approximately(art.modulate.a,alpha,0.02) and art.scale.distance_to(Vector2.ONE)<0.02,tag+"beat %d settles at source position and opacity"%i)
				check(art.position.x>=0 and art.position.y>=0 and art.position.x+art.size.x<1280 and art.position.y+art.size.y<720,tag+"beat %d artwork stays within real viewport"%i)
		check(button(map,"마치기" if i==4 else "계속"),tag+"beat %d retains genuine explicit Continue/Finish button"%i)
		check(session.world.snapshot()==snapshot,tag+"beat %d opening artwork never writes RNG, items, quests or save"%i)
		check(session.world.reward_receipts==receipts,tag+"beat %d makes no reward duplication"%i)
		map.close_overlay()
		check(not is_instance_valid(map.overlay),tag+"beat %d closes and frees image layer"%i)
		if i<3:
			check(HUNT.advance(session,tree,i),tag+"saved original Continue from beat %d"%i)
		elif i==3:
			check(HUNT.finish(session,tree),tag+"only fourth Continue reveals ruins location and fifth final scene")
			check(session.world.event_flags.get(HUNT.SEALED_RUINS_FLAG,false)==true and session.world.event_flags.get(HUNT.FINAL_BATTLE_FLAG,false)==true,tag+"last scene shows acknowledged completed-location state")

	# Last acknowledgement must survive a fresh world and Map; it cannot be
	# consumed by opening a portrait, dismissing or reloading.
	var final_state:Dictionary=session.world.snapshot().duplicate(true)
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.snapshot()==final_state and HUNT.current_beat(session)==4,tag+"fifth scene restored exactly from saved world and no invisible progression")
	map=MAP.instantiate()
	root.add_child(map)
	for k in range(4):await process_frame
	map.show_monster_king_hunt_beat(tree)
	var final_art=art_layer(map,"KingHuntSceneLayer")
	check(final_art!=null and final_art.texture.resource_path==BEATS.SCENE_ART,tag+"reopened final scene shows correct static corrupted-beast art")
	if final_art!=null:
		check(final_art.position.distance_to(scene_bounds.position)<0.15 and approximately(final_art.modulate.a,1,0.01),tag+"reopened fifth art uses fixed CSS without repeated animation")
	check(button(map,"마치기") and HUNT.can_resume_completion(session,tree),tag+"final scene still requires explicit acknowledgement")
	check(session.world.snapshot()==final_state,tag+"reopened original final scene does not mark acknowledgement")
	map.close_overlay()
	check(HUNT.acknowledge_completion(session,tree),tag+"explicit final acknowledgement saved through genuine story API")
	check(session.world.event_flags.get(HUNT.FINAL_SCENE_ACK_FLAG,false)==true and not HUNT.can_resume_completion(session,tree),tag+"acknowledged scene cannot reopen unexpectedly")
	check(session.world.reward_receipts==receipts,tag+"no story illustration grants another card/reward")
	map.queue_free()
	await process_frame
	clear_temp()
	check(not FileAccess.file_exists(scratch),tag+"isolated test save deleted, real save untouched")
