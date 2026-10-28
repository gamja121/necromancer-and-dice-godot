extends SceneTree
## Fortune scene: no duplicate crystal/table overlay, real shared die,
## persistent once-only outcome and user-accessible result after reload.
const MapScene=preload("res://map.tscn")
const SessionScript=preload("res://systems/run_session.gd")
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
	map.show_location(index)
	var panel=map.overlay
	check(is_instance_valid(panel),"live map opens actual fortune action panel")
	check(panel.get_script().resource_path.ends_with("place_actions.gd"),"fortune panel uses original PlaceActions code")
	check(panel.fortune_result!=null and panel.fortune_result.visible,"fortune guidance occupies a single lower notice panel before rolling")
	check(panel.fortune_notice_strip is TextureRect and panel.fortune_notice_strip.name=="FortuneNoticeStrip","fortune painting uses the approved hand-inked parchment artwork")
	check(panel.fortune_notice_strip.position==Vector2(340,423) and panel.fortune_notice_strip.size==Vector2(600,150),"transparent parchment uses the approved bottom-center dimensions")
	var ribbon: Texture2D=panel.fortune_notice_strip.texture
	check(ribbon!=null and ribbon.get_width()==1024 and ribbon.get_height()==256,"the committed parchment WEBP decodes at full gameplay resolution")
	check(panel.fortune_notice_strip.mouse_filter==Control.MOUSE_FILTER_IGNORE and panel.status.mouse_filter==Control.MOUSE_FILTER_IGNORE,"ribbon and its labels never intercept shared die clicks")
	check(panel.get_node_or_null("FortuneNoticePanel")==null,"old rectangular result panel is not constructed")
	check(panel.get_node_or_null("FortuneProphecyCrystal")==null and panel.get_node_or_null("FortuneCrystalAura")==null,"redundant crystal/table asset and purple halo are not spawned")
	check(panel.fortune_result.position==Vector2(393,500) and panel.fortune_result.size==Vector2(494,24),"small cumulative subline stays within parchment center")
	check(panel.status.position==Vector2(394,465) and panel.status.size==Vector2(492,30),"main ink-colored text is centered on the parchment")
	check(panel.get_node_or_null("LocationSceneImage")!=null,"original fortune-teller painting remains behind the simplified UI")
	check(panel.confirm_button==null,"fortune has no separate action button")
	check(panel.status.text=="주사위를 눌러 예언을 확인하세요","main parchment identifies the single shared-die action")
	check(panel.fortune_result.text.contains("즉시 회복") and panel.fortune_result.tooltip_text.contains("회복은 즉시") and panel.fortune_result.tooltip_text.contains("다음 전투"),"lower guidance and tooltip preserve effect timing")
	var hint:String=panel.fortune_result.text.replace(" ","")
	check(hint.contains("이동없음") and hint.contains("방문당1회") and hint.contains("1저주") and hint.contains("2즉시회복") and hint.contains("3~6축복"),"idle guidance explains no movement, visit limit and possible outcomes")
	check(panel.get_node_or_null("FortuneLocationTitle")==null and panel.get_node_or_null("FortuneVisitHint")==null and Rect2(panel.fortune_result.position,panel.fortune_result.size)==Rect2(393,500,494,24),"prophecy has no upper heading and uses shared lower guidance")
	check(panel.close_button.text=="맵으로 나가기" and Rect2(panel.close_button.position,panel.close_button.size)==map.TILE_EVENT_EXIT_RECT,"fortune uses the common original exit slot")
	var redundant_action: bool=false
	for child in panel.get_children():
		if child is Button and child.text=="예언 듣기": redundant_action=true
	check(not redundant_action,"fortune has no duplicate prophecy button in the live UI")
	check(panel.dice==map.dice and map.dice.visible,"fortune uses the original map die, not a duplicate")
	check(map.dice.z_index>panel.z_index and map.dice.mouse_filter==Control.MOUSE_FILTER_STOP and not map.dice.disabled,"fortune die is visible ABOVE source art and is clickable")
	check(map.stage.get_child(map.stage.get_child_count()-1)==map.dice,"fortune die is on top for GUI hit testing, not just draw order")
	# Click the actual stage die rather than the prophecy text button.
	# This goes through Map.on_shared_die_pressed -> PlaceActions.roll_prophecy.
	map.dice.pressed.emit()
	await process_frame
	check(panel.get_node_or_null("FortuneProphecyCrystal")==null and panel.get_node_or_null("FortuneCrystalAura")==null,"prophecy roll never creates a floating crystal, table or purple halo")
	check(map.dice.disabled and panel.close_button.disabled,"fortune locks repeated rolls and exit during animation")
	check(panel.fortune_result.mouse_filter==Control.MOUSE_FILTER_IGNORE,"outcome text does not steal shared die input")
	var start=Time.get_ticks_msec()
	while panel.busy and Time.get_ticks_msec()-start<11000:
		await process_frame
	check(not panel.busy and not panel.close_button.disabled,"actual roll animation finishes and restores close button")
	check(int(world.last_prophecy.get("face",-1))==4,"live persisted prophecy uses real RNG result, not mocked UI result")
	check(panel.status.text.contains("축복") and panel.status.text.contains("아군 체력 +2"),"primary line shows the real prophecy result after the roll")
	check(panel.fortune_result.visible and panel.fortune_result.text.contains("체력 +2"),"bottom subline shows saved cumulative buff")
	check(panel.fortune_result.text.begins_with("다음 전투 합계: "),"cumulative effect appears once beneath the main outcome")
	check(not panel.status.text.contains("누적:"),"the primary outcome is not duplicated with the cumulative line")
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
	map.show_location(index)
	panel=map.overlay
	check(panel.get_script().resource_path.ends_with("place_actions.gd") and panel.status.text.contains("완료"),"completed camp directly reopens the readable result")
	check(panel.get_node_or_null("LocationAction_prophecy")==null and map.pending_location_papers.is_empty(),"reopening does not reconstruct a removed entry paper")
	check(panel.confirm_button==null and map.dice.disabled,"loaded already-used fortune disables the single shared die without adding a button")
	check(map.dice.z_index>panel.z_index and map.dice.mouse_filter==Control.MOUSE_FILTER_IGNORE,"completed foreground die cannot intercept the common exit")
	check(panel.get_node_or_null("FortuneProphecyCrystal")==null and panel.get_node_or_null("FortuneCrystalAura")==null,"reopened result never recreates old crystal/table overlay")
	check(panel.fortune_notice_strip!=null and panel.fortune_notice_strip.texture==ribbon,"reopened prophecy reuses the same transparent parchment texture")
	check(panel.status.text.contains("아군 체력 +2") and not panel.status.text.contains("누적:"),"reopened primary result is restored without a duplicate line")
	check(panel.fortune_result.visible and panel.fortune_result.text.begins_with("다음 전투 합계: ") and panel.fortune_result.text.contains("체력 +2"),"reopened result displays persisted cumulative effect under the primary outcome")
	check(panel.dice.texture_normal==map.texture("res://assets/battle/dice/result-04.png"),"result die texture restores from persisted face")
	check(session.world.reward_receipts.size()==before_receipts+1,"reopen never duplicates fortune receipt")
	panel.close_button.pressed.emit()
	var exit_start:int=Time.get_ticks_msec()
	while is_instance_valid(map.overlay) and Time.get_ticks_msec()-exit_start<6000: await process_frame
	check(not is_instance_valid(map.overlay) and map.dice.visible and not map.dice.disabled,"one exit directly returns to playable map")
	check(session.world.snapshot()==serialized,"completed exit changes no saved result or RNG")
	map.queue_free()
	await process_frame
	session.save_file_path=original_save
	if owns: session.queue_free()
	clear_save()
	check(not FileAccess.file_exists(save),"temporary fortune save removed without touching original save")
	print("UI_FORTUNE_PROPHECY_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
