extends SceneTree
## One-notch gear test: exact saved multiset, intact original tiles, movable
## mapping, minimum required type changes, fixed nodes, and no hidden flips.
const Gear = preload("res://systems/map_gear_shift.gd")
const State = preload("res://systems/map_state.gd")
const Session = preload("res://systems/run_session.gd")
const Layout = preload("res://systems/map_shuffle_layout.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS gear-identity: ",label)
	else:
		failed+=1
		printerr("FAIL gear-identity: ",label)

func types_count(tiles: Array) -> Dictionary:
	var count: Dictionary={}
	for kind in tiles:
		count[str(kind)]=int(count.get(str(kind),0))+1
	return count

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var moving: Array[int]=Layout.moving_indices()
	check(moving.size()==21 and Layout.FIXED_INDICES==[0,8,15],"21 movable tiles and 3 fixed source positions")
	var session: Node=root.get_node_or_null("RunSession")
	var owns: bool=session==null
	if owns:
		session=Session.new()
		session.name="RunSession"
		root.add_child(session)
	var saved_path: String=session.save_file_path
	session.save_file_path="user://map_gear_identity_%d.json" % OS.get_process_id()
	for scenario in range(9):
		# Build real original worlds with valid unit definitions and fixed tile counts.
		session.start_new_world()
		var world=session.world
		world.rng.seed=10000+scenario
		var previous: Array=world.tiles.duplicate()
		for lap in range(1,6):
			world.lap_ready=true
			world.leave_home()
			var generated: Array=world.tiles.duplicate()
			var next: Array=Gear.compose_board(previous,generated)
			check(types_count(next)==types_count(generated),"scenario %d lap %d preserves genuine counts" % [scenario,lap])
			check(next[0]=="fortune-teller-camp" and next[8]=="village" and next[15]=="home","scenario %d lap %d preserves fixed tiles" % [scenario,lap])
			if int(world.contamination)>=State.BOSS_CONTAMINATION:
				check(next[23]=="boss","scenario %d lap %d keeps boss exactly at tile 23" % [scenario,lap])
			var old_count: Dictionary=types_count(previous)
			var next_count: Dictionary=types_count(next)
			var deficit: int=0
			for kind in next_count:
				deficit+=maxi(0,int(next_count[kind])-int(old_count.get(kind,0)))
			var boss_extra: int=0
			if generated[23]=="boss" and previous[22]!="boss":
				# Boss reserve may force one additional displaced card.
				boss_extra=2
			var changed: int=Gear.changed_count(previous,next)
			check(changed>=deficit and changed<=deficit+boss_extra,"scenario %d lap %d changes only necessary types (%d, minimum %d)" % [scenario,lap,changed,deficit])
			if lap==1 and scenario==0:
				check(changed==1,"first lap changes exactly one road into required new graveyard")
			world.tiles=next
			previous=next.duplicate()
	session.save_file_path=saved_path
	if owns: session.queue_free()
	var temp_save: String="user://map_gear_identity_%d.json" % OS.get_process_id()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(temp_save+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save+suffix))
	# The rotated original tile must be the EXACT target artwork throughout.
	var image:=Image.create(4,4,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.44,0.32,0.22))
	var old_face: Texture2D=ImageTexture.create_from_image(image)
	var stage:=Control.new()
	stage.size=Vector2(1280,720)
	root.add_child(stage)
	var board: Array=[]
	var new_faces: Array=[]
	for i in range(24):
		var tile:=TextureButton.new()
		tile.ignore_texture_size=true
		tile.texture_normal=old_face
		tile.position=State.centers()[i]*Vector2(12.8,7.2)-Layout.TILE_SIZE*0.5
		tile.size=Layout.TILE_SIZE
		stage.add_child(tile)
		board.append(tile)
		var img:=Image.create(4,4,false,Image.FORMAT_RGBA8)
		img.fill(Color(float(i+1)/25.0,0.4,0.3))
		new_faces.append(old_face if i in Layout.FIXED_INDICES else ImageTexture.create_from_image(img))
	var gear:=Gear.new()
	stage.add_child(gear)
	check(gear.prepare(board,new_faces),"21 travelling tiles created with committed destination faces")
	var dest_ok: bool=true
	var original_unchanged: bool=true
	for i in range(gear.visuals.size()):
		var target: int=int(gear.target_indices[i])
		if gear.visuals[i].texture != new_faces[target]: dest_ok=false
		if board[int(gear.source_indices[i])].texture_normal!=old_face: original_unchanged=false
	check(dest_ok,"travelling faces already equal destination BEFORE rotation")
	check(original_unchanged,"old live buttons never mutated ahead of commit")
	var sampled: Dictionary={"frames":0,"face_changed":false,"progress_reverse":false,"previous":0.0}
	var monitor: Callable=func():
		if not is_instance_valid(gear) or gear.rotation_tween==null: return
		sampled["frames"]=int(sampled["frames"])+1
		if gear.last_progress<float(sampled["previous"])-0.0001: sampled["progress_reverse"]=true
		sampled["previous"]=gear.last_progress
		for i in range(gear.visuals.size()):
			if gear.visuals[i].texture!=new_faces[int(gear.target_indices[i])]: sampled["face_changed"]=true
	process_frame.connect(monitor)
	await gear.play_once()
	process_frame.disconnect(monitor)
	check(gear.finished and absf(gear.last_progress-1.0)<0.001,"exactly one completed gear notch")
	check(int(sampled["frames"])>=2 and not sampled["progress_reverse"],"slow gear moves forward once without reversing")
	check(not sampled["face_changed"],"no false face-flip while rotating")
	var positions_match: bool=true
	for i in range(gear.visuals.size()):
		if gear.visuals[i].position.distance_to(gear.destinations[i])>0.01: positions_match=false
		if gear.visuals[i].texture!=new_faces[int(gear.target_indices[i])]: dest_ok=false
	check(positions_match and dest_ok,"each arriving stone is identical to actual final board")
	gear.clean_up()
	check(board.all(func(tile): return tile.visible),"21 old map source buttons restored for safe rebuild")
	check(gear.visuals.is_empty(),"temporary tile art removed")
	stage.queue_free()
	await process_frame
	print("MAP_GEAR_IDENTITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
