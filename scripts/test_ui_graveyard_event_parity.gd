extends SceneTree
## UI stage4: original graveyard dialogue composition and two-column extraction.
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
	return parent.get_node_or_null(label)
func has_button(parent: Control, title: String) -> bool:
	if not is_instance_valid(parent): return false
	for node in parent.get_children():
		if node is Button and node.text==title and node.visible: return true
	return false
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
	check(child_named(map.overlay,"StoryDialogueFrame") is TextureRect and child_named(map.overlay,"StoryDialogueFrame").texture.resource_path=="res://assets/map/ui/intro-dialogue-box.webp","verified source-based dialogue frame displays in graveyard scene")
	var speech=child_named(map.overlay,"StoryDialogueText")
	check(speech is Label and speech.text.contains("도와주세요"),"original child dialogue appears in speech frame")
	map.show_graveyard_child_beat(grave,3)
	check(has_button(map.overlay,"아이를 구한다") and has_button(map.overlay,"지나친다"),"all branch choices remain usable")
	check(has_button(map.overlay,"공동묘지 기능"),"graveyard location remains accessible during story")
	map.close_overlay()
	var corpse: Dictionary=session.world.roster[0].duplicate(true)
	corpse.brands=[{"type":"critical","bless":[2],"curse":[]}]
	session.world.graveyard_corpses=[corpse]
	var extraction=ExtractionUI.new()
	map.add_child(extraction)
	extraction.setup(map,grave)
	await process_frame
	check(extraction.graveyard_columns.size()==2,"separate corpse and extraction-brand columns")
	check(extraction.graveyard_corpses_grid.columns==3 and extraction.graveyard_brands_grid.columns==3,"both lists use 3-column card grids")
	check(extraction.corpse_options.size()==1,"deceased unit appears as selectable card")
	var corpse_id: String=str(corpse.id)
	extraction.corpse_options[corpse_id].pressed.emit()
	await process_frame
	check(extraction.corpse_id==corpse_id and extraction.brand_options.size()==1,"selecting corpse reveals recoverable brand")
	check(session.world.graveyard_corpses.size()==1,"viewing/examining never consumes corpse")
	var before_cards: int=session.world.brand_cards.size()
	extraction.brand_options[0].pressed.emit()
	await process_frame
	check(session.world.graveyard_corpses.is_empty(),"extracting brand permanently consumes corpse")
	check(session.world.brand_cards.size()==before_cards+1,"same action awards exactly one brand card")
	check(session.place_visit_id("grave-extract",grave) in session.world.reward_receipts,"extraction receipt committed")
	var committed: Dictionary=session.world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==committed,"graveyard extraction persists without duplicate rewards")
	extraction.queue_free()
	map.queue_free()
	await process_frame
	session.save_file_path=saved_path
	for suffix in ["",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("UI_STAGE4_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
