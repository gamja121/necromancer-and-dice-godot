extends SceneTree
## Controlled integration simulation of ALL five discoveries in ONE expedition.
## Prerequisites and event arrivals are seeded fixture state, not claims that a
## random unassisted playthrough naturally reaches every condition in 5 visits.
## Production map.show_tile(index,true) owns actual story-priority dispatch,
## the 40-percent discovery roll, card display, current map and HOME rewards.
const Session = preload("res://systems/run_session.gd")
const MapScene = preload("res://map.tscn")
const Discovery = preload("res://systems/location_discoveries.gd")
const State = preload("res://systems/map_state.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, msg: String) -> void:
	if ok:
		passed += 1
		print("PASS five-discovery: ",msg)
	else:
		failed += 1
		printerr("FAIL five-discovery: ",msg)

func wait_for(predicate: Callable, limit: int=5000) -> bool:
	var deadline: int=Time.get_ticks_msec()+limit
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())

func discovery_seed() -> int:
	var probe := RandomNumberGenerator.new()
	for seed in range(1,700):
		probe.seed=seed
		if probe.randf()>=0.60: return seed
	return -1

func supply_documented_history(w, kind: String) -> void:
	# Only seed the *already required* history; the discovery itself always
	# goes through the production map UI and the original RNG transaction.
	match kind:
		"forest":
			w.laps=1
		"rest":
			w.event_flags["discovery:ever_injured"]=true
		"graveyard":
			w.story_events["graveyard_child_ambush_01"]={"status":"complete","choice":"leave","battle_result":""}
			w.event_flags["event:graveyard_child_ambush_01:complete"]=true
			w.event_flags["event:graveyard_child_ambush_01:abandoned"]=true
		"unknown":
			# Current corruption may be purified; the peak is durable.
			w.max_contamination_reached=14
		"altar":
			w.story_events["cultist_rumor_01"]={"status":"seen","choice":"","battle_result":""}
			w.event_flags["event:cultist_rumor_01:seen"]=true

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	var own: bool=session==null
	if own:
		session=Session.new()
		session.name="RunSession"
		root.add_child(session)
	var old_path: String=session.save_file_path
	var path: String="user://five_discovery_arrival_%d.json" % OS.get_process_id()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	session.save_file_path=path
	session.start_new_world()
	var w = session.world
	var index: int = w.tiles.find("event")
	var order: Array=["forest","rest","graveyard","unknown","altar"]
	check(index>=0 and w.tiles.size()==24,"original 24-tile map contains a real event tile")
	check(Discovery.ORDER==order,"all 5 cards retain their registry and map-generation order")
	var seed: int=discovery_seed()
	check(seed>0,"genuine production 40-percent discovery RNG branch is reachable")
	for kind in order:
		# The next location MUST be locked and ineligible before its
		# prerequisite is earned, not just unlocked by landing anywhere.
		check(not Discovery.eligible(w,kind),kind+": not discoverable before its documented condition")
		supply_documented_history(w,kind)
		check(Discovery.eligible(w,kind),kind+": documented history makes discovery eligible")
		check(Discovery.next_eligible(w)==kind,kind+": correct priority among undiscovered locations")
		# A fresh simulated dice arrival. Same event index is revisited
		# after a different move serial; no movement/quest shortcuts exist
		# in the production dispatcher that follows.
		w.position=index
		w.move_serial+=1
		w.rng.seed=seed
		check(session.save_world(),kind+": saved before production event dispatch")
		var base: Dictionary=w.snapshot().duplicate(true)
		var total_before: int=w.tiles.count(kind)
		var roads_before: int=w.tiles.count("basic")
		var visit: String="routine-visit:%d:%d:%d" % [w.map_serial,w.move_serial,index]
		var scene = MapScene.instantiate()
		root.add_child(scene)
		await process_frame
		scene.show_tile(index,true)
		check(w.reward_receipts.has(visit),kind+": real event dispatcher saves unique visit receipt")
		check(Discovery.is_unlocked(w,kind),kind+": real 40-percent event draw unlocks location")
		check(w.tiles.count(kind)==total_before+1 and w.tiles.count("basic")==roads_before-1,kind+": exactly 1 vacant road changes to actual location")
		check(w.tiles[0]=="fortune-teller-camp" and w.tiles[8]=="village" and w.tiles[15]=="home" and w.tiles[index]=="event",
			kind+": real map protects fixed and story positions")
		check(w.event_flags.get(Discovery.home_flag(kind),false)==true,kind+": permanent HOME NEW saved")
		var converted: int=-1
		for tile_index in range(24):
			if base.tiles[tile_index]=="basic" and w.tiles[tile_index]==kind: converted=tile_index
		check(converted>=0 and converted!=23 and converted!=index,kind+": actual tile placed only on a safe road")
		var reveal: Control=scene.find_child("EventDiscoveryCard",true,false) as Control
		check(reveal!=null,kind+": genuine event opens the ordinary discovery card")
		if reveal!=null:
			var details: Dictionary=Discovery.details(kind)
			check(reveal.get_node("EventDiscoveryTile").texture==scene.texture("res://assets/map/tiles/%s.png" % kind),kind+": actual discovered tile is shown")
			check(reveal.get_node("EventDiscoveryTitle").text==str(details.title) and reveal.get_node("EventDiscoveryDescription").text==str(details.description),kind+": discovery has the actual title and explanation")
			check(scene.overlay.get_child(0) is ColorRect,kind+": ordinary event retains its dark backdrop")
			reveal.dismiss()
			check(await wait_for(func(): return not is_instance_valid(scene.overlay)),kind+": one tap returns to the changed board")
		if converted>=0:
			check(scene.buttons[converted].texture_normal==scene.texture(scene.tile_path(converted)),kind+": board displays transformed terrain")
		scene.show_home(true)
		var home_icon=scene.overlay.find_child("HomeUnlocked_%s" % kind,true,false) if is_instance_valid(scene.overlay) else null
		check(home_icon!=null,kind+": HOME interior displays newly unlocked tile")
		check(scene.overlay.find_child("UnlockNewBadge",true,false)!=null,kind+": HOME NEW badge actually visible")
		scene.queue_free()
		await process_frame
		var persisted: Dictionary=w.snapshot().duplicate(true)
		session.reload_world()
		w=session.world
		check(w.tiles.count(kind)==total_before+1 and Discovery.is_unlocked(w,kind),kind+": unlocked tile persists after disk reload")
		check(w.event_flags.get(Discovery.home_flag(kind),false)==true and w.reward_receipts.has(visit),kind+": HOME badge and visit receipt persist")
		# Do not allow repeat awards for the SAME visit or the same place.
		var snapshot: Dictionary=w.snapshot().duplicate(true)
		check(not bool(session.begin_story_free_event(index).get("ok",false)),kind+": same event landing cannot redraw or repeat")
		check(w.snapshot()==snapshot,kind+": ignored duplicate causes no RNG, tile or reward change")
		print("DISCOVERY_SIM_RESULT: ",kind," condition=yes card=yes location_on_board=yes home=yes saved=yes")
	# Every map shuffle must still carry the five actual permanent places.
	var before_serial: int=w.map_serial
	w.generate()
	check(w.map_serial==before_serial+1 and w.tiles.size()==24,"next HOME board remains 24 tiles")
	for kind in order:
		var expected: int=2 if kind=="graveyard" else 1
		check(w.tiles.count(kind)==expected,kind+": map reshuffle retains expected permanent discovered terrain count")
	check(w.tiles.count("basic")>=2,"at least two protected swamp roads survive five unlocks")
	# Detached reveal/book cues must finish cleanup before the audio driver exits.
	var cues:Node=root.get_node_or_null("GameAudio")
	if cues!=null: cues.queue_free()
	var cleanup_deadline:int=Time.get_ticks_msec()+10000
	while (is_instance_valid(cues) or not preload("res://systems/battle_resources.gd").PendingLoads.active.is_empty()) and Time.get_ticks_msec()<cleanup_deadline:
		await process_frame
	await process_frame
	session.save_file_path=old_path
	if own: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("FIVE_DISCOVERY_ACTUAL_ARRIVAL: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
