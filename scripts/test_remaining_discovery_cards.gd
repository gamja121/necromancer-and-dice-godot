extends SceneTree
## Run: godot --headless --path . --script res://scripts/test_remaining_discovery_cards.gd
## Covers each remaining real discovery, art, click-to-dismiss, HOME, next
## shuffle, guards, saved receipts and no phantom award on failed saves.
const Session = preload("res://systems/run_session.gd")
const MapScene = preload("res://map.tscn")
const State = preload("res://systems/map_state.gd")
const Discovery = preload("res://systems/location_discoveries.gd")
const RoutePlan = preload("res://systems/route_plan.gd")
const Actions = preload("res://systems/exploration_actions.gd")
var pass_count := 0
var fail_count := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		pass_count+=1
		print("PASS remaining-discoveries: ",label)
	else:
		fail_count+=1
		printerr("FAIL remaining-discoveries: ",label)

func seed_eligibility(world,kind: String) -> void:
	world.laps=1
	match kind:
		"rest":
			world.event_flags["discovery:ever_injured"]=true
		"graveyard":
			world.story_events["graveyard_child_ambush_01"]={"status":"seen","choice":"","battle_result":""}
		"unknown":
			world.max_contamination_reached=14
		"altar":
			world.story_events["cultist_rumor_01"]={"status":"seen","choice":"","battle_result":""}

func case_for(session: Node,kind: String) -> void:
	var path: String="user://test_new_discovery_%s_%d.json" % [kind,OS.get_process_id()]
	session.save_file_path=path
	session.start_new_world()
	var w = session.world
	var event_index: int=w.tiles.find("event")
	seed_eligibility(w,kind)
	w.position=event_index
	check(Discovery.eligible(w,kind),kind+": verified unique narrative/history prerequisite")
	check(session.save_world(),kind+": fixture stored before genuine discovery transaction")
	var before: Dictionary=w.snapshot().duplicate(true)
	var old_rng: int=w.rng.state
	var old_roads: int=w.tiles.count("basic")
	var old_count: int=w.tiles.count(kind)
	var result: Dictionary=session.discover_location_on_event(event_index,kind)
	check(bool(result.get("ok",false)),kind+": discovery granted through real RunSession")
	check(w.tiles.count(kind)==old_count+1 and w.tiles.count("basic")==old_roads-1,kind+": one road converted to precisely one new "+kind)
	check(w.tiles[0]=="fortune-teller-camp" and w.tiles[8]=="village" and w.tiles[15]=="home" and w.tiles[event_index]=="event",kind+": event and fixed story anchors protected")
	check(w.rng.state==old_rng and w.map_serial==before.map_serial,kind+": real board conversion does not reroll")
	check(Discovery.is_unlocked(w,kind) and session.event_flag_is_set(Discovery.receipt_flag(kind)) and session.event_flag_is_set(Discovery.home_flag(kind)),kind+": three permanent receipt/HOME state flags saved")
	check(session.event_flag_is_set("ui:unlock:%s:tile_pending" % kind) and session.event_flag_is_set("ui:unlock:%s:action_pending" % kind),kind+": unread tile and action NEW markers saved")
	if kind=="rest":
		check(bool(w.patrol_plan.get("rest_unlocked",false)) and bool(w.patrol_plan.get("rest_discovered",false)), "camp unlock enables existing route editor")
		var plan: Dictionary=w.patrol_plan.duplicate(true)
		plan.selection.rest=2
		check(RoutePlan.valid(plan),"discovered camp and two optional camps total three")
		plan.selection.rest=3
		check(not RoutePlan.valid(plan),"discovered camp plus three optional camps rejected")
	var transformed: int=-1
	for i in range(24):
		if before.tiles[i]=="basic" and w.tiles[i]==kind: transformed=i
	check(transformed>=0 and transformed!=23 and transformed!=w.position,kind+": only safe free road is used")
	var ui=MapScene.instantiate()
	root.add_child(ui)
	await process_frame
	ui.show_discovery_card(kind)
	var card: Control=ui.overlay.get_node_or_null("EventDiscoveryCard") if is_instance_valid(ui.overlay) else null
	check(card!=null,kind+": original real map overlay displays a unique card")
	if card!=null:
		check(card.get_node_or_null("EventDiscoveryClose")==null,kind+": no confirm button")
		check(card.get_node("EventDiscoveryTitle").text==str(Discovery.details(kind).title),kind+": correct location-specific title")
		check(card.get_node("EventDiscoveryTile").texture!=null,kind+": correct actual tile artwork loaded")
		check(card.get_node("EventDiscoveryIllustration").texture!=null,kind+": original game location illustration loaded")
		var tap:=InputEventMouseButton.new()
		tap.button_index=MOUSE_BUTTON_LEFT
		tap.pressed=true
		card._gui_input(tap)
		await process_frame
		await process_frame
		check(not is_instance_valid(ui.overlay),kind+": one click dismisses without new reward")
	check(ui.buttons[transformed].texture_normal==ui.texture(ui.tile_path(transformed)),kind+": actual transformed location visible on board")
	var badge = ui.buttons[transformed].get_node_or_null("UnlockNewBadge")
	check(badge!=null,kind+": transformed tile has NEW badge")
	ui.show_location(transformed)
	await process_frame
	check(not session.event_flag_is_set("ui:unlock:%s:tile_pending" % kind),kind+": first location view clears board NEW")
	var action = ui.overlay.find_child("RestHealAction",true,false) if kind=="rest" else null
	if kind!="rest":
		action = ui.overlay.find_child("UnlockNewBadge",true,false)
	check(action!=null,kind+": location action has NEW marker")
	ui.close_overlay()
	ui.show_home(true)
	check(ui.overlay.find_child("HomeUnlocked_%s" % kind,true,false)!=null,kind+": HOME interior lists unlocked tile")
	ui.close_overlay()
	var route=Actions.new()
	ui.stage.add_child(route)
	route.setup(ui,State.HOME)
	var slot: String="HomeUnlockedForestTile" if kind=="forest" else "HomeUnlockedTile_%s" % kind
	check(route.find_child(slot,true,false)!=null,kind+": actual HOME route editor shows unlocked tile")
	route.queue_free()
	await process_frame
	ui.queue_free()
	await process_frame
	session.reload_world()
	w=session.world
	check(session.event_flag_is_set(Discovery.unlock_flag(kind)) and session.event_flag_is_set(Discovery.receipt_flag(kind)),kind+": save and reload preserve discovery receipt")
	check(w.tiles.count(kind)==old_count+1,kind+": transformed tile survives reload")
	check(not bool(session.discover_location_on_event(event_index,kind).get("ok",false)),kind+": duplicate card/extra tile never granted")
	w.generate()
	var expected_after_shuffle: int=2 if kind=="graveyard" else 1
	check(w.tiles.count(kind)==expected_after_shuffle,kind+": HOME reshuffle preserves auto place plus any preexisting legacy slot")
	if kind=="rest":
		check(w.tiles.count("rest")<=RoutePlan.REST_LIMIT,"discovered rest still respects total 3 tiles")
	var last: Dictionary=w.snapshot().duplicate(true)
	session.save_file_path="user://impossible_discovery_dir/test.json"
	check(not bool(session.discover_location_on_event(event_index,kind).get("ok",false)) and w.snapshot()==last,kind+": no duplicate unlock on save-failure path")
	session.save_file_path=path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func verify_earlier_world_tree(session: Node) -> void:
	var path: String="user://test_early_world_tree_%d.json" % OS.get_process_id()
	session.save_file_path=path
	session.start_new_world()
	var w=session.world
	w.laps=1
	w.event_flags["discovery:ever_injured"]=true
	w.story_events["graveyard_child_ambush_01"]={"status":"seen","choice":"","battle_result":""}
	w.max_contamination_reached=7
	check(not Discovery.eligible(w,"unknown"),"world tree is not added in the opening corruption band")
	w.max_contamination_reached=13
	check(not Discovery.eligible(w,"unknown"),"world-tree discovery stays locked just below peak corruption 14")
	check(Discovery.next_eligible(w)=="forest","below the tree threshold other locations retain their original order")
	w.max_contamination_reached=14
	w.contamination=0
	check(Discovery.eligible(w,"unknown"),"peak corruption 14 enables the world tree one basic lap before the old 20 gate")
	check(Discovery.eligible(w,"forest") and Discovery.eligible(w,"rest") and Discovery.eligible(w,"graveyard"),"priority fixture has all earlier optional places eligible together")
	var before: Dictionary=w.snapshot().duplicate(true)
	check(Discovery.next_eligible(w)=="unknown","world tree wins a discovery selection even with all optional places still waiting")
	check(w.snapshot()==before,"eligibility and priority checks do not consume RNG, rewards or change the board")
	check(session.save_world(),"earlier threshold history saves through the existing world format")
	session.reload_world()
	w=session.world
	check(w.contamination==0 and w.max_contamination_reached==14 and Discovery.eligible(w,"unknown"),"purification and restart keep the earned world-tree eligibility")
	w.event_flags[Discovery.unlock_flag("unknown")]=true
	check(not Discovery.eligible(w,"unknown"),"an existing world-tree unlock is never awarded twice")
	check(Discovery.next_eligible(w)=="forest","after the world tree the original remaining discovery order resumes")
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	var own: bool=session==null
	if own:
		session=Session.new()
		session.name="RunSession"
		root.add_child(session)
	var old_path: String=session.save_file_path
	verify_earlier_world_tree(session)
	for kind in ["rest","graveyard","unknown","altar"]:
		await case_for(session,kind)
	session.save_file_path=old_path
	session.world=null
	if own: session.queue_free()
	print("REMAINING_DISCOVERY_CARDS: %d passed, %d failed" % [pass_count,fail_count])
	quit(0 if fail_count==0 else 1)
