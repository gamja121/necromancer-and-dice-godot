extends SceneTree
## Stage 5Y frozen CSS portal layout/500ms motion and real
## child→rumor→commander→hunter→cultists→altar→portal 5-beat chain.
## Verify authentic boss revival choice and read-only ending UI.
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
const BEATS=preload("res://systems/ritual_portal_beats.gd")
const MOTION=preload("res://systems/ritual_portal_layer_motion.gd")
var passed:int=0
var failed:int=0
var scratch:String=""

class Victory:
	extends RefCounted
	func winner()->String: return "ally"
	func find_id(_id:String)->Dictionary: return {}

func check(ok:bool,message:String)->void:
	if ok:
		passed+=1
		print("PASS ui-portal-layer: ",message)
	else:
		failed+=1
		printerr("FAIL ui-portal-layer: ",message)

func approximately(a:float,b:float,tolerance:float=0.15)->bool:
	return absf(a-b)<tolerance

func cleanup()->void:
	for ext in ["",".tmp"]:
		if FileAccess.file_exists(scratch+ext):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+ext))

func art_layer(map:Control,name:String)->TextureRect:
	if not is_instance_valid(map.overlay): return null
	return map.overlay.get_node_or_null(name) as TextureRect

func has_button(map:Control,caption:String)->bool:
	if not is_instance_valid(map.overlay): return false
	return map.overlay.get_children().any(func(n):return n is Button and n.visible and n.text==caption)

func _initialize()->void:
	call_deferred("_run")

func _run()->void:
	scratch="user://ui_portal_stage5y_%d.json"%OS.get_process_id()
	cleanup()
	var session=root.get_node_or_null("RunSession")
	var created:bool=session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var former:String=session.save_file_path
	session.save_file_path=scratch
	session.start_new_world()
	var grave:int=session.world.tiles.find("graveyard")
	var village:int=session.world.tiles.find("village")
	var tree:int=session.world.tiles.find("unknown")
	var altar:int=session.world.tiles.find("altar")
	var forest:int=session.world.tiles.find("forest")
	check(grave>=0 and village>=0 and tree>=0 and altar>=0 and forest>=0,"canonical map contains all source story destinations")
	if grave<0 or village<0 or tree<0 or altar<0 or forest<0:
		session.save_file_path=former
		if created:session.queue_free()
		cleanup()
		quit(1)
		return
	var map=MAP.instantiate()
	root.add_child(map)
	for i in range(4):await process_frame
	# Exercise every actual entry and save transaction. Only tile approach
	# is shortened by setting position in this isolated regression fixture.
	session.world.position=grave
	check(CHILD.begin(session,grave),"real graveyard encounter discovered")
	check(CHILD.choose(session,grave,"protect_child"),"player child rescue choice saved")
	check(session.start_story_encounter(CHILD.EVENT_ID,grave,[session.world.roster[0].id]),"real rescue battle started with owned card")
	check(session.finish_encounter(Victory.new()),"battle outcome resolved using actual RunSession")
	check(session.acknowledge_graveyard_battle_result(),"real rescue outcome confirmed")
	session.world.position=village
	check(RUMOR.begin(session,village)==RUMOR.RESCUED_ID,"genuine rescued-child village rumor opened")
	for beat in range(RUMOR_BEATS.count(RUMOR.RESCUED_ID)):
		check(RUMOR.advance(session,village,RUMOR.RESCUED_ID,beat),"rescued-child rumor beat %d saved"%beat)
	check(COMMANDER.begin(session,village),"original commander quest begins")
	for beat in range(COMMANDER_BEATS.count()):
		check(COMMANDER.advance(session,village,beat),"commander beat %d saved"%beat)
	session.world.position=tree
	check(HUNTER.begin(session,tree),"monster hunter clue event starts")
	for beat in range(HUNTER_BEATS.count()):
		check(HUNTER.advance(session,tree,beat),"hunter beat %d saved"%beat)
	session.world.position=village
	check(CULTIST.begin(session,village),"original cultist rumor begins after hunter clue")
	for beat in range(CULTIST_BEATS.count()):
		check(CULTIST.advance(session,village,beat),"cultist rumor beat %d saved"%beat)
	session.world.position=altar
	check(ALTAR.begin(session,altar),"altar begins after actual cultist tracking")
	check(ALTAR.advance(session,altar,0) and ALTAR.advance(session,altar,1),"altar ritual two original Continue checkpoints persisted")
	check(ALTAR.choose(session,altar,2,"pass"),"player chooses source altar pass")
	check(ALTAR.finish(session,altar) and ALTAR.completed(session),"explicit altar Finish commits genuine forest quest")
	session.world.position=forest
	check(PORTAL.begin(session,forest),"forest portal truly discovered and saved")
	check(PORTAL.current_beat(session)==0,"five-scene portal starts at arrival")
	var frame:Rect2=map.TILE_EVENT_SCENE_RECT
	var expected:Rect2=MOTION.source_rect(frame)
	check(expected.position.distance_to(frame.position+frame.size*Vector2(0.02,0.03))<0.01,"CSS portal art left 2% top 3% (bottom 22%)")
	check(expected.size.distance_to(frame.size*Vector2(0.75,0.75))<0.01,"CSS 75% width / 75% height image")
	check(approximately(MOTION.ENTRY_SECONDS,0.5,0.001) and approximately(MOTION.ENTRY_SCALE,0.985,0.001),"500ms 98.5% scale source reveal")
	check(MOTION.ENTRY_OFFSET_FRACTION.distance_to(Vector2(0.0,0.02))<0.001,"CSS reveal starts 2% below resting image")
	var receipts:Array=session.world.reward_receipts.duplicate(true)
	for beat_idx in range(BEATS.count()):
		var beat:Dictionary=BEATS.beat(beat_idx)
		var snapshot:Dictionary=session.world.snapshot().duplicate(true)
		check(PORTAL.current_beat(session)==beat_idx,"portal beat %d is the saved exact source index"%beat_idx)
		map.show_ritual_portal_beat(forest)
		check(is_instance_valid(map.overlay),"portal beat %d opens real scene overlay"%beat_idx)
		var energy=art_layer(map,"PortalEnergyLayer")
		var cultists=art_layer(map,"PortalCultistsLayer")
		var omen=art_layer(map,"PortalOmenLayer")
		var displayed:TextureRect=null
		match str(beat.visual):
			"energy": displayed=energy
			"cultists": displayed=cultists
			"omen": displayed=omen
		if beat_idx==0:
			check(energy==null and cultists==null and omen==null,"arrival shows only original ruins background")
		else:
			check(displayed!=null and [energy,cultists,omen].filter(func(n):return n!=null).size()==1,"beat %d shows exactly one appropriate portal layer"%beat_idx)
			if displayed!=null:
				var target:String=BEATS.layer_for(str(beat.visual))
				check(displayed.texture==map.texture(target) and displayed.texture.resource_path==target,"beat %d uses source original image bytes"%beat_idx)
				check(displayed.size.distance_to(expected.size)<0.02 and displayed.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"beat %d correct 75% footprint and aspect"%beat_idx)
				check(displayed.mouse_filter==Control.MOUSE_FILTER_IGNORE and displayed.get_meta("ui_custom_open_motion",false),"beat %d layer ignores touch, avoids generic modal movement"%beat_idx)
				check(displayed.pivot_offset.distance_to(Vector2(displayed.size.x/2,displayed.size.y))<0.01,"beat %d bottom-center transform pivot"%beat_idx)
				var animated:bool=beat.id in ["portal_reveal","omen"]
				if animated:
					check(displayed.position.distance_to(expected.position+displayed.size*MOTION.ENTRY_OFFSET_FRACTION)<0.15,"beat %d source animation begins 2% down"%beat_idx)
					check(approximately(displayed.scale.x,MOTION.ENTRY_SCALE,0.01) and approximately(displayed.modulate.a,0,0.01),"beat %d source animation starts transparent at 98.5% size"%beat_idx)
					await create_timer(0.62).timeout
				else:
					check(displayed.position.distance_to(expected.position)<0.15 and approximately(displayed.modulate.a,1,0.01),"beat %d correctly stays static: no fictitious crossing animation"%beat_idx)
				check(displayed.position.distance_to(expected.position)<0.8 and displayed.scale.distance_to(Vector2.ONE)<0.02 and approximately(displayed.modulate.a,1,0.02),"beat %d settles at canonical source geometry"%beat_idx)
				check(displayed.position.x>0 and displayed.position.y>0 and displayed.position.x+displayed.size.x<1280 and displayed.position.y+displayed.size.y<720,"beat %d stays in map viewport"%beat_idx)
		check(has_button(map,"저지한다" if beat_idx==4 else "계속"),"beat %d shows original explicit Continue/Intervene"%beat_idx)
		check(session.world.snapshot()==snapshot,"beat %d visual layer does not mutate save, RNG, quests or rewards"%beat_idx)
		check(not session.event_flag_is_set(PORTAL.REVIVED_FLAG) and session.encounter.is_empty(),"beat %d cannot revive king or start fight by itself"%beat_idx)
		map.close_overlay()
		check(not is_instance_valid(map.overlay),"beat %d cleans up its visual scene and tween"%beat_idx)
		if beat_idx<4:
			check(PORTAL.advance(session,forest,beat_idx),"real explicit Continue saves beat %d"%beat_idx)

	# A new map instance after a disk reload must resume fifth-verse omen
	# statically; it must never reanimate an earlier portal reveal or fight.
	var before_reload:Dictionary=session.world.snapshot().duplicate(true)
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.snapshot()==before_reload and PORTAL.current_beat(session)==4,"full persisted portal checkpoint survives reload")
	map=MAP.instantiate()
	root.add_child(map)
	for k in range(5):await process_frame
	map.show_ritual_portal_beat(forest)
	var saved_omen=art_layer(map,"PortalOmenLayer")
	check(saved_omen!=null and saved_omen.position.distance_to(expected.position)<0.15 and approximately(saved_omen.modulate.a,1,0.01),"reloaded fifth beat uses static saved omen at same 75% frame")
	check(has_button(map,"저지한다") and not has_button(map,"출전 마물 선택"),"reopened scene still awaits explicit intervention")
	map.close_overlay()
	check(PORTAL.choose_intervention(session,forest,4),"player intervention genuinely saved separately from visual animation")
	var intervention_snapshot:Dictionary=session.world.snapshot().duplicate(true)
	map.show_ritual_portal_beat(forest)
	check(art_layer(map,"PortalOmenLayer")!=null and has_button(map,"출전 마물 선택"),"chosen intervention shows same omen and real deck action")
	check(session.world.snapshot()==intervention_snapshot and session.encounter.is_empty(),"intervention picture never starts combat automatically")
	map.close_overlay()
	check(session.start_story_encounter(PORTAL.EVENT_ID,forest,[session.world.roster[0].id]),"real original portal battle starts via owned card")
	check(session.finish_encounter(Victory.new()),"actual RunSession records portal battle victory")
	check(session.story_battle_result_pending(PORTAL.EVENT_ID),"victory result awaits player's explicit acknowledgement")
	check(not PORTAL.aftermath_ready(session,forest) and not session.event_flag_is_set(PORTAL.REVIVED_FLAG),"pending result cannot trigger king revival")
	check(session.acknowledge_story_battle_result(PORTAL.EVENT_ID),"player result confirmation acknowledged through session API")
	check(PORTAL.aftermath_ready(session,forest),"authentic weakened-revival aftermath becomes eligible")
	var outcome_snapshot:Dictionary=session.world.snapshot().duplicate(true)
	map.show_ritual_portal_aftermath(forest)
	var ending=art_layer(map,"PortalOmenLayer")
	check(ending!=null and ending.texture.resource_path==BEATS.OMEN_ART,"battle aftermath reuses original omen WebP")
	if ending!=null:
		check(ending.position.distance_to(expected.position)<0.15 and ending.size.distance_to(expected.size)<0.02,"aftermath omen uses same 75% source placement")
		check(approximately(ending.modulate.a,1,0.01) and ending.get_meta("ui_custom_open_motion",false),"result presentation stays static, no new omen reveal")
	check(has_button(map,"마치기"),"epilogue still requires genuine player Finish")
	check(session.world.snapshot()==outcome_snapshot and session.world.reward_receipts==receipts,"simply displaying ending never finishes revival or grants item")
	check(not session.event_flag_is_set(PORTAL.REVIVED_FLAG),"omen animation cannot set king-revived flag")
	map.close_overlay()
	map.show_ritual_portal_aftermath(forest)
	map.close_overlay()
	await create_timer(0.57).timeout
	check(not is_instance_valid(map.overlay),"closing a portal scene cancels only node-bound visual tweens")
	map.queue_free()
	await process_frame
	session.save_file_path=former
	if created:session.queue_free()
	cleanup()
	check(not FileAccess.file_exists(scratch),"temporary save removed without touching player data")
	print("UI_PORTAL_LAYERS_STAGE5Y: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
