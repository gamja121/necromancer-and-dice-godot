extends SceneTree
## UI stage4: preserve graveyard story dialogue while replacing extraction with random dice digging.
const MapScene=preload("res://map.tscn")
const ExtractionUI=preload("res://systems/exploration_actions.gd")
const Beats=preload("res://systems/graveyard_story_beats.gd")
var passed=0
var failed=0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS ui-stage4: ",label)
	else:
		failed+=1
		printerr("FAIL ui-stage4: ",label)
func child_named(parent: Node, label: String) -> Node:
	if not is_instance_valid(parent): return null
	return parent.find_child(label,true,false)
func has_button(parent: Control, title: String) -> bool:
	if not is_instance_valid(parent): return false
	for node in parent.get_children():
		if node is Button and node.text==title and node.visible: return true
	return false
func wait_for(predicate: Callable, limit: int=5000) -> bool:
	var deadline: int=Time.get_ticks_msec()+limit
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())
func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	if session==null:
		check(false,"RunSession autoload exists")
		quit(1)
		return
	var saved_path: String=session.save_file_path
	var path="user://ui_stage4_%d.json" % OS.get_process_id()
	session.save_file_path=path
	session.start_new_world()
	# Test UI on the first legitimate cemetery-bearing map (lap 1).
	session.world.lap_ready=true
	session.world.leave_home()
	var grave: int=session.world.tiles.find("graveyard")
	check(grave>=0,"graveyard tile available")
	if grave<0:
		session.save_file_path=saved_path
		quit(1)
		return
	session.world.position=grave
	var map: Control=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	map.show_graveyard_child_beat(grave,0)
	check(is_instance_valid(map.overlay),"story scene opened without changing encounter state")
	check(child_named(map.overlay,"StorySceneImage")!=null,"illustrated left-side scene rendered")
	check(child_named(map.overlay,"StoryInfoPanel")!=null,"separate parchment information column rendered")
	check(has_button(map.overlay,"계속") and has_button(map.overlay,"나가기"),"opening scene exposes original controls")
	check(not session.get_story_event("graveyard_child_ambush_01").status=="complete","visual beat alone does not complete story")
	map.show_graveyard_child_beat(grave,2)
	check(child_named(map.overlay,"StoryCharacterLayer")!=null,"ghoul visible on its own image layer")
	check(child_named(map.overlay,"StoryDialogueFrame") is TextureRect and child_named(map.overlay,"StoryDialogueFrame").texture.resource_path=="res://assets/map/ui/story_book_open.png","shared transparent high-resolution dialogue frame displays in graveyard scene")
	var speech=child_named(map.overlay,"StoryDialogueText")
	check(speech is Label and speech.text.contains("도와주세요"),"original child dialogue appears in speech frame")
	map.show_graveyard_child_beat(grave,3)
	check(has_button(map.overlay,"아이를 구한다") and has_button(map.overlay,"지나친다"),"all branch choices remain usable")
	check(has_button(map.overlay,"공동묘지 기능"),"graveyard location remains accessible during story")
	map.close_overlay()
	session.world.graveyard_corpses=[]
	map.show_location(grave)
	var extraction: Control=map.overlay
	await process_frame
	check(extraction.get_script()==ExtractionUI,"cemetery location opens the actual digging screen directly")
	check(extraction.content.get_node_or_null("GraveyardDigFrame")==null and extraction.content.get_node_or_null("GraveyardNoticeStrip")!=null,"cemetery now uses the original painting and approved hand-drawn parchment instead of the old dark panel")
	check(extraction.content.get_node_or_null("GraveyardDigConfirm")!=null,"digging has a visible explicit confirmation")
	check(extraction.action_button!=null and not extraction.action_button.disabled,"digging is available with zero allied corpses")
	var before_cards: int=session.world.dice_cards.size()
	extraction.action_button.pressed.emit()
	await process_frame
	check(session.world.dice_cards.size()==before_cards+1 and not session.world.snapshot().has("brand_cards") and not session.world.snapshot().has("legacy_brand_cards"),"digging grants one dice card and no brand cards")
	check(session.place_visit_id("grave-extract",grave) in session.world.reward_receipts,"digging receipt commits before visual reveal")
	check(extraction.busy and extraction.graveyard_phase=="revealing","actual soil and card motion locks repeat actions")
	var committed: Dictionary=session.world.snapshot().duplicate(true)
	check(await wait_for(func(): return not extraction.busy and extraction.graveyard_phase=="ready"),"saved card reveal completes before collection is offered")
	check(extraction.find_child("GraveyardFoundDiceCard",true,false)!=null,"original dice card appears inside the reveal motion")
	check(extraction.action_button!=null and extraction.action_button.name=="GraveyardCollectConfirm" and extraction.action_button.text=="챙기고 나가기","revealed card retains an explicit collect primary action")
	check(session.world.snapshot()==committed,"soil and card presentation does not change the committed reward")
	session.reload_world()
	check(session.world.snapshot()==committed,"graveyard digging persists without duplicate rewards")
	var audio: Node=root.get_node_or_null("GameAudio")
	check(await wait_for(func(): return audio==null or audio.voices.is_empty()),"graveyard presentation audio finishes before teardown")
	map.queue_free()
	await process_frame
	var loads=preload("res://systems/battle_resources.gd")
	check(await wait_for(func(): return loads.PendingLoads.active.is_empty()),"exited story and digging resources drain before shutdown")
	if audio!=null: audio.queue_free()
	await create_timer(0.10).timeout
	session.save_file_path=saved_path
	for suffix in ["",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("UI_STAGE4_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
