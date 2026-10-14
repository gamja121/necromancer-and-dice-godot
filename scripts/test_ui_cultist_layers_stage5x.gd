extends SceneTree
## Stage 5X: authentic rescue→commander→hunter→cultist rumor→altar
## story flags, source art geometry, visual timing, choice/pass/fight
## and interrupted-save restoration without completing by animation.
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
const ALTAR_BEATS=preload("res://systems/cultist_altar_beats.gd")
const MOTION=preload("res://systems/cultist_story_layer_motion.gd")
var passed:int=0
var failed:int=0
var scratch:String=""

class Victory:
	extends RefCounted
	# Current RunSession.finish_encounter inspects battle.units before resolving.
	var units: Array = []
	func winner()->String: return "ally"
	func find_id(_id:String)->Dictionary: return {}

func check(ok:bool,msg:String)->void:
	if ok:
		passed+=1
		print("PASS ui-cultist-layer: ",msg)
	else:
		failed+=1
		printerr("FAIL ui-cultist-layer: ",msg)

func approximately(a:float,b:float,e:float=0.15)->bool:
	return absf(a-b)<e

func clear_save()->void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))

func layer(map:Control,key:String)->TextureRect:
	if not is_instance_valid(map.overlay): return null
	return map.overlay.get_node_or_null(key) as TextureRect

func button(map:Control,label:String)->bool:
	if not is_instance_valid(map.overlay): return false
	return map.overlay.get_children().any(func(n):return n is Button and n.visible and n.text==label)

func _initialize()->void:
	call_deferred("_run")

func _run()->void:
	scratch="user://ui_cultist_stage5x_%d.json"%OS.get_process_id()
	clear_save()
	var session=root.get_node_or_null("RunSession")
	var created:bool=session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var former:String=session.save_file_path
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
	check(grave>=0 and village>=0 and tree>=0 and altar>=0,"real visual fixture supplies story locations")
	if grave<0 or village<0 or tree<0 or altar<0:
		session.save_file_path=former
		if created:session.queue_free()
		clear_save()
		quit(1)
		return
	var map=MAP.instantiate()
	root.add_child(map)
	for t in range(4):await process_frame

	# No injected event flags: follow original hero rescue, commander, hunter.
	session.world.position=grave
	check(CHILD.begin(session,grave),"actual child event discovered and saved")
	check(CHILD.choose(session,grave,"protect_child"),"original rescue selected")
	check(session.start_story_encounter(CHILD.EVENT_ID,grave,[session.world.roster[0].id]),"real owned monster starts rescue combat")
	check(session.finish_encounter(Victory.new()),"rescue battle resolved through real session")
	check(session.acknowledge_graveyard_battle_result(),"rescue result committed")
	session.world.position=village
	check(RUMOR.begin(session,village)==RUMOR.RESCUED_ID,"rescued-child village rumor actually opens")
	for i in range(RUMOR_BEATS.count(RUMOR.RESCUED_ID)):
		check(RUMOR.advance(session,village,RUMOR.RESCUED_ID,i),"rescue rumor beat %d saved"%i)
	check(COMMANDER.begin(session,village),"knight commander actually unlocks")
	for i in range(COMMANDER_BEATS.count()):
		check(COMMANDER.advance(session,village,i),"knight commander beat %d saved"%i)
	session.world.position=tree
	check(HUNTER.begin(session,tree),"original hunter clue story opens")
	for i in range(HUNTER_BEATS.count()):
		check(HUNTER.advance(session,tree,i),"hunter beat %d saved"%i)
	check(session.get_story_event(HUNTER.EVENT_ID).status=="complete","hunter story finished before cultist rumor")

	session.world.position=village
	check(CULTIST.begin(session,village),"cultist procession unlocked after real hunter clue")
	var scene:Rect2=map.TILE_EVENT_SCENE_RECT
	var rumor_bounds:Rect2=MOTION.source_rect(scene,false)
	var altar_bounds:Rect2=MOTION.source_rect(scene,true)
	check(rumor_bounds.position.distance_to(scene.position+scene.size*Vector2(0.10,0.09))<0.01,"web rumor left 10%, top 20%, bottom 0% geometry")
	check(rumor_bounds.size.distance_to(scene.size*Vector2(0.80,0.75))<0.01,"rumor procession width 80%, height 80%")
	check(altar_bounds.position.distance_to(scene.position+scene.size*Vector2(0.20,0.18))<0.01,"web altar left 20%, bottom 7% geometry")
	check(altar_bounds.size.distance_to(scene.size*Vector2(0.60,0.64))<0.01,"altar ritual/summon 60% of source event image")
	check(approximately(MOTION.RUMOR_SECONDS,0.50,0.001) and approximately(MOTION.ALTAR_SECONDS,0.48,0.001),"web .50s/.48s story layer reveal durations")
	var receipts:Array=session.world.reward_receipts.duplicate()

	for i in range(CULTIST_BEATS.count()):
		var beat:Dictionary=CULTIST_BEATS.beat(i)
		var expected_state:Dictionary=session.world.snapshot().duplicate(true)
		check(CULTIST.current_beat(session)==i,"rumor beat %d restored from saved event flags"%i)
		map.show_cultist_rumor_beat(village)
		var picture=layer(map,"CultistProcessionLayer")
		if i==0:
			check(picture==null,"arrival renders night village painting without the procession")
		else:
			check(picture!=null,"beat %d renders the original procession layer"%i)
			if picture!=null:
				check(picture.texture==map.texture(CULTIST_BEATS.PROCESSION) and picture.texture.resource_path==CULTIST_BEATS.PROCESSION,"beat %d unmodified source procession WebP"%i)
				check(picture.size.distance_to(rumor_bounds.size)<0.01 and picture.mouse_filter==Control.MOUSE_FILTER_IGNORE,"beat %d updated safe footprint and click-through"%i)
				check(picture.get_meta("ui_custom_open_motion",false) and picture.pivot_offset.distance_to(Vector2(picture.size.x/2,picture.size.y))<0.01,"beat %d independent image motion/pivot"%i)
				if i==1:
					check(picture.position.distance_to(rumor_bounds.position+picture.size*MOTION.START_OFFSET_FRACTION)<0.15,"only first procession reveal starts 2% lower")
					check(approximately(picture.modulate.a,0,0.01) and approximately(picture.scale.x,0.985,0.01),"first procession starts transparent at 98.5% size")
					await create_timer(0.62).timeout
				else:
					check(picture.position.distance_to(rumor_bounds.position)<0.15 and approximately(picture.modulate.a,1,0.01),"subsequent rumor beats do not reanimate")
				check(picture.position.distance_to(rumor_bounds.position)<0.8 and approximately(picture.modulate.a,1,0.02),"procession settles at source coordinates")
		check(button(map,"마치기" if CULTIST_BEATS.is_final(i) else "계속"),"rumor beat %d retains original explicit action"%i)
		check(session.world.snapshot()==expected_state,"rumor beat %d artwork makes no world/RNG changes"%i)
		map.close_overlay()
		if i<CULTIST_BEATS.count()-1:
			check(CULTIST.advance(session,village,i),"genuine rumor beat %d advances only via saved contract"%i)
	check(session.get_story_event(CULTIST.EVENT_ID).status=="seen" and session.world.event_flags.get(CULTIST.TRACKING_FLAG,false)!=true,"showing final rumor art does not unlock tracking")
	check(CULTIST.advance(session,village,CULTIST_BEATS.count()-1),"explicit final rumor confirmation commits cultist tracking")
	check(session.get_story_event(CULTIST.EVENT_ID).status=="complete","cultist rumor completion saved")

	session.world.position=altar
	check(ALTAR.begin(session,altar),"real altar is unlocked after cultist rumor completion")
	for i in range(ALTAR_BEATS.count()):
		var expected_state:Dictionary=session.world.snapshot().duplicate(true)
		var beat:Dictionary=ALTAR_BEATS.beat(i)
		check(ALTAR.current_beat(session)==i,"original altar beat %d persisted"%i)
		map.show_cultist_altar_beat(altar)
		var ritual=layer(map,"CultistRitualLayer")
		if i==0:
			check(ritual==null,"altar arrival has no falsely summoned layer")
		else:
			check(ritual!=null and layer(map,"CultistSummonLayer")==null,"altar pre-choice renders only ritual actor layer")
			if ritual!=null:
				check(ritual.texture==map.texture(ALTAR_BEATS.RITUAL),"original ritual WebP unchanged")
				check(ritual.size.distance_to(altar_bounds.size)<0.01 and ritual.get_meta("ui_custom_open_motion",false),"ritual CSS 60%-square footprint and independent modal motion")
				check(ritual.mouse_filter==Control.MOUSE_FILTER_IGNORE,"ritual decoration never captures input")
				if i==1:
					check(ritual.position.distance_to(altar_bounds.position+ritual.size*MOTION.START_OFFSET_FRACTION)<0.15 and approximately(ritual.modulate.a,0,0.01),"ritual reveal begins transparent 2% below frame")
					await create_timer(0.59).timeout
				else:
					check(ritual.position.distance_to(altar_bounds.position)<0.15 and approximately(ritual.modulate.a,1,0.01),"choice does not replay original ritual reveal")
				check(ritual.position.distance_to(altar_bounds.position)<0.8 and approximately(ritual.modulate.a,1,0.02),"ritual ends with original CSS position/opacity")
		if i<2:
			check(button(map,"계속"),"altar arrival and ritual require real Continue")
		else:
			check(button(map,"싸운다") and button(map,"지나간다"),"original fight/pass options untouched")
		check(session.world.snapshot()==expected_state,"altar beat %d artwork does not mutate encounter or save"%i)
		map.close_overlay()
		if i<2:check(ALTAR.advance(session,altar,i),"actual altar beat %d saved explicitly"%i)

	check(ALTAR.choose(session,altar,2,"fight"),"fight choice commits real intent before rendering summon")
	var fighting_snapshot:Dictionary=session.world.snapshot().duplicate(true)
	map.show_cultist_altar_beat(altar)
	var summoned=layer(map,"CultistSummonLayer")
	check(summoned!=null and layer(map,"CultistRitualLayer")==null,"fight scene swaps ritual for summon, never both")
	if summoned!=null:
		check(summoned.texture==map.texture(ALTAR_BEATS.SUMMON),"summon uses unaltered source art")
		check(summoned.position.distance_to(altar_bounds.position+summoned.size*MOTION.START_OFFSET_FRACTION)<0.15 and approximately(summoned.modulate.a,0,0.01),"fight declaration shows source .48s summon reveal")
		await create_timer(0.59).timeout
		check(summoned.position.distance_to(altar_bounds.position)<0.8 and approximately(summoned.modulate.a,1,0.02),"summon settles at correct safe event geometry")
	check(button(map,"출전 마물 선택") and button(map,"선택 변경"),"fight preserves existing deck-selection and reconsider controls")
	check(session.world.snapshot()==fighting_snapshot and session.encounter.is_empty(),"summon animation does not auto-start battle")
	map.close_overlay()
	check(ALTAR.reconsider(session,altar),"explicit user reconsider resets pending fight")
	check(ALTAR.choose(session,altar,2,"pass"),"alternate original pass intent saved")
	check(ALTAR.followup_ready(session,altar),"passing unlocks read-only followup scene")
	var saved_state:Dictionary=session.world.snapshot().duplicate(true)
	map.show_cultist_altar_followup(altar)
	var quiet_ritual=layer(map,"CultistRitualLayer")
	check(quiet_ritual!=null and layer(map,"CultistSummonLayer")==null,"pass followup displays ritual layer rather than summon")
	if quiet_ritual!=null:
		check(quiet_ritual.position.distance_to(altar_bounds.position)<0.15 and approximately(quiet_ritual.modulate.a,1,0.01),"pass followup is static original CSS composition")
	check(button(map,"선택 변경") and button(map,"마치기"),"pass followup retains original confirmation/choice controls")
	check(session.world.snapshot()==saved_state and session.world.reward_receipts==receipts,"visual-only followup never grants quest or inventory")
	map.close_overlay()
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.snapshot()==saved_state and ALTAR.followup_ready(session,altar),"saved pass choice/restored quest survives process-world reload")
	map=MAP.instantiate()
	root.add_child(map)
	for t in range(4):await process_frame
	map.show_cultist_altar_intro(altar)
	quiet_ritual=layer(map,"CultistRitualLayer")
	check(quiet_ritual!=null and layer(map,"CultistSummonLayer")==null,"reloaded altar opens the real saved pass followup")
	check(session.get_story_event(ALTAR.EVENT_ID).status=="active" and session.world.event_flags.get(ALTAR.COMPLETE_FLAG,false)!=true,"reloading artwork cannot silently mark altar event complete")
	map.close_overlay()
	map.queue_free()
	await process_frame
	session.save_file_path=former
	if created:session.queue_free()
	clear_save()
	check(not FileAccess.file_exists(scratch),"temporary test save removed; personal save preserved")
	print("UI_CULTIST_LAYERS_STAGE5X: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
