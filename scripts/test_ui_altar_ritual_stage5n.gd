extends SceneTree
## 5N: unchanged frozen-web ritual slot/info sprites connected to the
## real Godot altar while sacrificing and enhancing exactly once per visit.
const MapScene=preload("res://map.tscn")
const RunSession=preload("res://systems/run_session.gd")
const SLOTS="res://assets/map/events/altar-ritual-slots.png"
const INFO="res://assets/map/events/altar-ritual-info.png"
var passed: int=0
var failed: int=0
var save: String=""
func check(value: bool, what: String) -> void:
	if value:
		passed+=1
		print("PASS ui-altar: ",what)
	else:
		failed+=1
		printerr("FAIL ui-altar: ",what)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	save="user://ui_altar_stage5n_%d.json" % OS.get_process_id()
	var session=root.get_node_or_null("RunSession")
	var own=session==null
	if own:
		session=RunSession.new()
		session.name="RunSession"
		root.add_child(session)
	var old_path: String=session.save_file_path
	session.save_file_path=save
	session.start_new_world()
	var world=session.world
	var index: int=world.tiles.find("altar")
	check(index>=0,"generated 24-tile map includes the original ritual altar")
	check(world.roster.size()>=2,"altar fixture has two distinct units")
	if index<0 or world.roster.size()<2:
		session.save_file_path=old_path
		if own:session.queue_free()
		quit(1)
		return
	var original_donor: Dictionary=world.roster[0].duplicate(true)
	var original_target: Dictionary=world.roster[1].duplicate(true)
	var donor_id: String=str(original_donor.id)
	var target_id: String=str(original_target.id)
	world.position=index
	session.save_world()
	var slots=load(SLOTS) as Texture2D
	var info=load(INFO) as Texture2D
	check(slots!=null and info!=null,"both frozen HTML art textures import and decode in Godot")
	var map=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	map.show_place_actions(index)
	var panel=map.overlay
	check(panel!=null and panel.type=="altar","actual map opens real altar panel")
	if panel==null:
		quit(1)
		return
	check(panel.altar_slots!=null and panel.altar_info!=null,"altar has distinct original slot board and info parchment")
	check(panel.altar_slots.texture==slots and panel.altar_info.texture==info,"real altar displays unchanged original source image bytes")
	check(panel.altar_slots.name=="AltarRitualSlots" and panel.altar_info.name=="AltarRitualInfo","artwork layers are clearly named")
	check(panel.altar_slots.position.distance_to(Vector2(192,36)+Vector2(0,10))<=11.0,"source slot board starts at 15% x and 5% y")
	check(panel.altar_slots.size.distance_to(Vector2(896,403.2))<0.1,"source board covers 70% width with 520/234 aspect")
	check(panel.altar_info.size==Vector2(512,176),"source info plaque has 40%-width central footprint")
	check(panel.altar_info.position.x==384 and panel.altar_info.z_index>panel.altar_slots.z_index,"info plaque overlays 30% left of ritual board")
	check(panel.donor_art.position==Vector2(340,108) and panel.receiver_art.position==Vector2(752,108),"source material and target cards inside paired slots")
	check(panel.confirm_button.position==Vector2(746,435) and panel.confirm_button.size==Vector2(125,43),"original ritual confirm docks on right side of info plaque")
	check(panel.altar_level.text=="강화 대상 선택 전","source enhancement level starts without target")
	check(panel.altar_scroll!=null and panel.altar_scroll.position==Vector2(192,532),"source hand spans 70% board, anchored below original panel")
	check(panel.close_button.text=="닫기" and panel.close_button.position==Vector2(1114,29),"source parchment dismiss button remains usable")
	await create_timer(0.97).timeout
	check(panel.altar_slots.modulate.a>0.99 and panel.altar_info.modulate.a>0.99,"260ms panel entrance finishes without becoming invisible")
	check(panel.hand.position.length()<0.1 and panel.hand.modulate.a>0.99,"680ms roster rise finishes and is clickable")
	check(panel.unit_options.has(donor_id) and panel.unit_options.has(target_id),"real roster cards remain selectable")
	panel.unit_options[donor_id].pressed.emit()
	check(panel.donor_id==donor_id and panel.donor_art.texture!=null,"selecting donor fills material card in source left slot")
	check(panel.confirm_button.disabled,"donor alone cannot execute ritual")
	panel.unit_options[target_id].pressed.emit()
	check(panel.receiver_id==target_id and panel.receiver_art.texture!=null,"selecting second unit fills right target slot")
	check(panel.altar_level.text=="강화 단계 0/3","target level is printed on original central info plaque")
	check(not panel.confirm_button.disabled,"valid distinct pair enables exact same ritual action")
	var before_rewards: int=world.reward_receipts.size()
	var before_rng: int=world.rng.state
	panel.confirm_button.pressed.emit()
	check(panel.completed and panel.confirm_button.disabled,"real clicked button executes ritual once and locks repeats")
	check(session.owned_unit(donor_id).is_empty(),"sacrificed material is permanently gone from owned roster")
	var enhanced: Dictionary=session.owned_unit(target_id)
	check(not enhanced.is_empty() and int(enhanced.attack)==int(original_target.attack)+1,"target receives exactly +1 attack")
	check(int(enhanced.max_hp)==int(original_target.max_hp)+2 and int(enhanced.altar_enhancements)==1,"target receives exactly +2 max HP and one upgrade level")
	check(world.reward_receipts.size()==before_rewards+1,"exactly one persistent ritual receipt granted")
	check(world.rng.state==before_rng,"ritual rendering neither rolls dice nor changes RNG")
	check(not session.altar_ritual(index,donor_id,target_id).get("ok",true),"repeat ritual rejected even through direct game API")
	check(panel.status.text.contains("강화 완료"),"result text remains readable above ritual art")
	var serial: Dictionary=world.snapshot().duplicate(true)
	map.queue_free()
	await process_frame
	session.reload_world()
	var fresh: Dictionary=session.world.snapshot()
	if fresh!=serial:
		for key in serial.keys():
			if fresh.get(key)!=serial[key]:
				print("DIAG altar key=",key," before=",JSON.stringify(serial[key]).substr(0,900)," after=",JSON.stringify(fresh.get(key)).substr(0,900))
	check(fresh==serial,"ritual state and roster survive JSON reload")
	map=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	map.show_place_actions(index)
	panel=map.overlay
	check(panel.confirm_button.disabled,"used ritual cannot run after reopening saved map")
	check(session.owned_unit(donor_id).is_empty(),"removed donor never reappears on save reopen")
	check(int(session.owned_unit(target_id).altar_enhancements)==1,"restored target retains altar level")
	map.queue_free()
	await process_frame
	session.save_file_path=old_path
	if own: session.queue_free()
	if FileAccess.file_exists(save): DirAccess.remove_absolute(ProjectSettings.globalize_path(save))
	check(not FileAccess.file_exists(save),"disposable altar save deleted, user's save untouched")
	print("UI_ALTAR_RITUAL_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
