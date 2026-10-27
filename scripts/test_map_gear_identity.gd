extends SceneTree
## Saved manifest and original stone identity regression: two gathered
## rings, exactly one tooth, two *real* disjoint pair exchanges, rule-only
## count conversions and NO post-landing face substitutions.
const Gear = preload("res://systems/map_gear_shift.gd")
const State = preload("res://systems/map_state.gd")
const Session = preload("res://systems/run_session.gd")
const Layout = preload("res://systems/map_shuffle_layout.gd")
var passed: int=0
var failed: int=0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS gear-identity: ",label)
	else:
		failed+=1
		printerr("FAIL gear-identity: ",label)

func kind_counts(tiles: Array) -> Dictionary:
	var counts: Dictionary={}
	for kind in tiles:
		counts[str(kind)]=int(counts.get(str(kind),0))+1
	return counts

func check_manifest(previous: Array, generated: Array, serial: int) -> Array:
	var plan: Dictionary=Gear.route_plan(previous,generated,serial)
	check(not plan.is_empty(),"serial %d has usable deterministic manifest" % serial)
	if plan.is_empty(): return []
	var targets: Dictionary=plan["targets"]
	var pairs: Array=plan["pairs"]
	var unique_dest: Dictionary={}
	for source in targets:
		unique_dest[int(targets[source])]=true
	check(targets.size()==21 and unique_dest.size()==21,"serial %d permutes exactly 21 unique moveable destinations" % serial)
	var fixed: bool=true
	for index in Layout.FIXED_INDICES:
		if targets.has(index) or unique_dest.has(index): fixed=false
	check(fixed,"serial %d never shifts fortune, village or home" % serial)
	check(pairs.size()==Gear.SWAP_PAIR_COUNT,"serial %d has precisely two real exchange pairs" % serial)
	var used: Dictionary={}
	var cross_ring: bool=true
	for pair in pairs:
		var a: int=int(pair["a"])
		var b: int=int(pair["b"])
		if used.has(a) or used.has(b): cross_ring=false
		used[a]=true
		used[b]=true
		if not (a in Layout.INNER_ORIGIN_ORDER and b in Layout.OUTER_ORIGIN_ORDER): cross_ring=false
	check(cross_ring,"serial %d swaps four distinct stones between two rings" % serial)
	if generated[23]=="boss":
		check(int(targets[23])==23,"serial %d reserves old or newly formed boss at cell 23" % serial)
	# The saved kind at every slot must equal its real moved source except
	# when exact generated type counts force a conversion.
	var result: Array=Gear.compose_board(previous,generated,serial)
	check(kind_counts(result)==kind_counts(generated),"serial %d conserves gameplay generation counts" % serial)
	check(result[0]=="fortune-teller-camp" and result[8]=="village" and result[15]=="home","serial %d keeps original fixed identities" % serial)
	if generated[23]=="boss":
		check(result[23]=="boss" and result.count("boss")==1,"serial %d keeps unique canonical boss" % serial)
	var old_counts: Dictionary=kind_counts(previous)
	var new_counts: Dictionary=kind_counts(generated)
	var additions: int=0
	for kind in new_counts:
		additions+=maxi(0,int(new_counts[kind])-int(old_counts.get(kind,0)))
	var converted: int=Gear.changed_count(previous,result,serial)
	check(converted>=additions and converted<=additions+2,"serial %d only necessary rules change face (actual %d minimum %d)" % [serial,converted,additions])
	return result

func _run() -> void:
	var session: Node=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=Session.new()
		session.name="RunSession"
		root.add_child(session)
	var prev_path: String=session.save_file_path
	var path: String="user://gathered_swap_manifest_%d.json" % OS.get_process_id()
	session.save_file_path=path
	for scenario in range(7):
		session.start_new_world()
		var world=session.world
		world.rng.seed=10000+scenario
		var previous: Array=world.tiles.duplicate()
		for lap in range(1,7):
			world.lap_ready=true
			world.leave_home()
			var generated: Array=world.tiles.duplicate()
			var serial: int=world.map_serial
			var actual: Array=check_manifest(previous,generated,serial)
			if actual.is_empty(): continue
			if lap==1:
				check(Gear.changed_count(previous,actual,serial)==2,"first completed lap reveals cemetery and upgrades one normal monster to a rare stone")
			world.tiles=actual
			previous=actual.duplicate()
	session.save_file_path=prev_path
	if created: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	# Construct real UI mock stones and observe all four phases through
	# Godot's running Tween, including crossing swaps and landing identities.
	var img:=Image.create(4,4,false,Image.FORMAT_RGBA8)
	img.fill(Color(0.35,0.31,0.28))
	var common_face: Texture2D=ImageTexture.create_from_image(img)
	var stage:=Control.new()
	stage.size=Vector2(1280,720)
	root.add_child(stage)
	var buttons: Array=[]
	var new_faces: Array=[]
	var old_kinds: Array=[]
	var new_kinds: Array=[]
	for i in range(24):
		var button:=TextureButton.new()
		button.ignore_texture_size=true
		button.texture_normal=common_face
		button.size=Layout.TILE_SIZE
		button.position=State.centers()[i]*Vector2(12.8,7.2)-button.size*0.5
		stage.add_child(button)
		buttons.append(button)
		var art:=Image.create(4,4,false,Image.FORMAT_RGBA8)
		art.fill(Color(float(i+1)/25.0,0.4,0.4))
		new_faces.append(common_face if i in Layout.FIXED_INDICES else ImageTexture.create_from_image(art))
		old_kinds.append("village" if i==8 else ("fortune-teller-camp" if i==0 else ("home" if i==15 else "basic")))
		new_kinds.append(old_kinds[i])
	# Simulate one genuine new cemetery conversion, with every other kind
	# unchanged; the route and animation must reveal it BEFORE the gear.
	new_kinds[7]="graveyard"
	var planned: Array=Gear.compose_board(old_kinds,new_kinds,17)
	# In the real game all basic tiles share the SAME source texture.
	# A different colour per destination would misrepresent a nonexistent
	# face replacement in this synthetic test. Only the newly spawned
	# cemetery has a genuinely different image.
	var visuals_by_dest: Array=[]
	for i in range(24):
		visuals_by_dest.append(new_faces[i] if planned[i]=="graveyard" else common_face)
	var gear:=Gear.new()
	stage.add_child(gear)
	check(gear.prepare(buttons,visuals_by_dest,old_kinds,planned,17),"21 original stone actors gather from 24-tile board")
	check(gear.swap_pairs.size()==2 and gear.conversions.size()==1,"two actual pair swaps and one rule-only cemetery conversion")
	var front_before: bool=true
	for i in range(gear.visuals.size()):
		if gear.visuals[i].texture!=buttons[gear.source_indices[i]].texture_normal: front_before=false
	check(front_before,"all starting stone images equal authentic source before gathering")
	var observed: Dictionary={"gather":false,"rotate":false,"swap":false,"scatter":false,"reverse":false,"last":0.0,"faces_ok":true,"swap_move":false,"frames":0}
	var monitor: Callable=func():
		if not is_instance_valid(gear): return
		var current: String=gear.phase
		if current in ["gather","rotate","swap","scatter"]:
			observed[current]=true
			observed["frames"]=int(observed["frames"])+1
		if current=="rotate":
			if gear.last_progress<float(observed["last"])-0.0001: observed["reverse"]=true
			observed["last"]=gear.last_progress
		if current=="swap" and gear.swap_tween!=null and not gear.swap_pairs.is_empty():
			var pair: Dictionary=gear.swap_pairs[0]
			var ia: int=gear.source_indices.find(int(pair["a"]))
			if ia>=0 and gear.visuals[ia].position.distance_to(gear.rotated_centers[ia]-gear.visuals[ia].size*0.5)>0.01:
				observed["swap_move"]=true
		if current in ["rotate","swap","scatter"]:
			for i in range(gear.visuals.size()):
				if gear.visuals[i].texture!=visuals_by_dest[gear.target_indices[i]]:
					observed["faces_ok"]=false
	process_frame.connect(monitor)
	await gear.play_once(visuals_by_dest)
	process_frame.disconnect(monitor)
	check(gear.finished and gear.gathered and gear.rotated and gear.swapped,"gather/one-notch/two-exchanges/scatter fully complete")
	check(bool(observed["gather"]) and bool(observed["rotate"]) and bool(observed["swap"]) and bool(observed["scatter"]),"all four phases visibly displayed")
	check(not observed["reverse"] and is_equal_approx(gear.last_progress,1.0),"rings advance one tooth without reversal or repeated spins")
	check(bool(observed["swap_move"]) and gear.swap_pairs.size()==2,"paired stones visibly cross actual ring positions")
	check(bool(observed["faces_ok"]),"all arrived types known during rotation; no post-swap surprises")
	check(gear.played_audio_cues==["gather","rotate","land"],"three weighted sound phases still play on shared SFX bus")
	var landed: bool=true
	for i in range(gear.visuals.size()):
		if gear.visuals[i].position.distance_to(gear.destination_centers[i]-gear.visuals[i].size*0.5)>0.02: landed=false
		if gear.visuals[i].texture!=visuals_by_dest[gear.target_indices[i]]: landed=false
	check(landed,"all 21 visible stones match real saved destination faces and positions")
	gear.clean_up()
	check(gear.visuals.is_empty() and buttons.all(func(button): return button.visible),"all temporary rings cleaned and underlying board safely restored")
	stage.queue_free()
	await process_frame
	print("MAP_GEAR_IDENTITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
