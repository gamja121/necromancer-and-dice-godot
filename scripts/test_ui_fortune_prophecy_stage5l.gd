extends SceneTree
## Stage 5L: original fortune crystal from the frozen web, live dice roll,
## persistent once-only outcome and user-accessible portrait after reload.
const MapScene=preload("res://map.tscn")
const SessionScript=preload("res://systems/run_session.gd")
const CRYSTAL="res://assets/map/events/fortune-prophecy-ui.png"
var passed: int=0
var failed: int=0
var save: String=""

func check(condition: bool, message: String) -> void:
	if condition:
		passed+=1
		print("PASS ui-fortune: ",message)
	else:
		failed+=1
		printerr("FAIL ui-fortune: ",message)

func _initialize() -> void:
	call_deferred("_run")

func clear_save() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save+suffix))

func _run() -> void:
	save="user://ui_fortune_stage5l_%d.json" % OS.get_process_id()
	clear_save()
	var tex: Texture2D=load(CRYSTAL)
	check(tex!=null,"recovered original fortune crystal decodes at runtime")
	if tex==null:
		print("UI_FORTUNE_PROPHECY_PARITY: %d passed, %d failed" % [passed,failed])
		quit(1)
		return
	check(tex.get_width()==96 and tex.get_height()==93,"frozen web crystal original aspect and dimensions")
	var rgba: Image=tex.get_image()
	check(rgba!=null and not rgba.is_empty(),"fortune crystal contains actual pixel data")
	if rgba!=null and not rgba.is_empty():
		var bounds: Rect2i=rgba.get_used_rect()
		check(bounds.size.x>=90 and bounds.size.y>=88,"recovered original crystal has nontrivial alpha bounds")
	var session=root.get_node_or_null("RunSession")
	var owns: bool=session==null
	if owns:
		session=SessionScript.new()
		session.name="RunSession"
		root.add_child(session)
	var original_save: String=session.save_file_path
	session.save_file_path=save
	session.start_new_world()
	var world=session.world
	var index: int=world.tiles.find("fortune-teller-camp")
	check(index>=0,"real map contains fixed fortune teller camp")
	if index<0:
		session.save_file_path=original_save
		if owns: session.queue_free()
		clear_save()
		quit(1)
		return
	world.position=index
	var seed_found: bool=false
	var preview=RandomNumberGenerator.new()
	for s in range(1,400):
		preview.seed=s
		if preview.randi_range(1,6)==4:
			world.rng.seed=s
			seed_found=true
			break
	check(seed_found,"disposable fortune dice has a reproducible blessing face")
	check(session.save_world(),"fortune fixture saved in isolated file")
	var before_receipts: int=world.reward_receipts.size()
	var before_rolls: int=world.prophecy.rolls.size()
	var map=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	map.show_place_actions(index)
	var panel=map.overlay
	check(is_instance_valid(panel),"live map opens actual fortune action panel")
	check(panel.get_script().resource_path.ends_with("place_actions.gd"),"fortune panel uses original PlaceActions code")
	check(panel.fortune_stone!=null and panel.fortune_aura!=null and panel.fortune_result!=null,"three source-specific fortune overlay nodes created")
	check(panel.fortune_stone.texture==tex,"visible crystal node references decoded web crystal")
	check(panel.fortune_stone.size==Vector2(210,204),"fortune crystal obeys original 210-pixel sizing")
	check(not panel.fortune_stone.visible and not panel.fortune_result.visible,"crystal/result hidden before pressing once-only prophecy")
	check(not panel.confirm_button.disabled,"unused fortune allows explicit user action")
	check(panel.dice!=null and panel.dice.visible,"original dice animation control remains available")
	panel.confirm_button.pressed.emit()
	await process_frame
	check(panel.fortune_stone.visible and panel.fortune_aura.visible,"crystal and purple halo appear only after user confirms")
	check(panel.confirm_button.disabled and panel.close_button.disabled,"fortune locks repeated rolls and exit during animation")
	check(panel.fortune_stone.mouse_filter==Control.MOUSE_FILTER_IGNORE and panel.fortune_aura.mouse_filter==Control.MOUSE_FILTER_IGNORE,"visual props never steal map input")
	var start=Time.get_ticks_msec()
	while panel.busy and Time.get_ticks_msec()-start<11000:
		await process_frame
	check(not panel.busy and not panel.close_button.disabled,"actual roll animation finishes and restores close button")
	check(int(world.last_prophecy.get("face",-1))==4,"live persisted prophecy uses real RNG result, not mocked UI result")
	check(panel.fortune_result.visible and panel.fortune_result.text.contains("아군 체력 +2"),"prophecy result appears in right-hand notice area")
	check(panel.fortune_result.text.contains("누적:"),"right-side result displays cumulative effect")
	check(world.reward_receipts.size()==before_receipts+1 and world.prophecy.rolls.size()==before_rolls+1,"exactly one fortune receipt and stack added")
	check(not session.fortune_prophecy(index).get("ok",true),"same visit cannot issue a second prophecy")
	var serialized: Dictionary=world.snapshot().duplicate(true)
	map.queue_free()
	await process_frame
	session.reload_world()
	var reloaded_snapshot: Dictionary=session.world.snapshot()
	if reloaded_snapshot!=serialized:
		for key in serialized.keys():
			if reloaded_snapshot.get(key)!=serialized[key]:
				print("DIAG fortune snapshot key=",key," before=",JSON.stringify(serialized[key]).substr(0,450)," after=",JSON.stringify(reloaded_snapshot.get(key)).substr(0,450))
	check(reloaded_snapshot==serialized,"full fortune result, visit receipt and stack survive reload")
	check(typeof(session.world.last_prophecy.get("face"))==TYPE_INT,"persisted fortune face reloads as an integer")
	check(typeof(session.world.prophecy.get("ally_hp"))==TYPE_INT,"persisted blessing bonus reloads as integer count")
	check(typeof(session.world.prophecy.rolls[0])==TYPE_INT,"persisted prophecy roll history reloads as integer faces")
	map=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	map.show_place_actions(index)
	panel=map.overlay
	check(panel.confirm_button.disabled,"loaded already-used fortune remains disabled")
	check(panel.fortune_stone.visible and panel.fortune_aura.visible,"reopened result restores crystal without rerolling")
	check(panel.fortune_result.visible and panel.fortune_result.text.contains("아군 체력 +2"),"reopened result displays same chosen face and effect")
	check(panel.dice.texture_normal==map.texture("res://assets/battle/dice/result-04.png"),"result die texture restores from persisted face")
	check(session.world.reward_receipts.size()==before_receipts+1,"reopen never duplicates fortune receipt")
	map.queue_free()
	await process_frame
	session.save_file_path=original_save
	if owns: session.queue_free()
	clear_save()
	check(not FileAccess.file_exists(save),"temporary fortune save removed without touching original save")
	print("UI_FORTUNE_PROPHECY_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
