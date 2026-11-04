extends SceneTree
## Real saved sacrifice -> reveal -> target flow. All files use a disposable path.
const MapScene=preload("res://map.tscn")
const Boons=preload("res://systems/altar_boon_catalog.gd")
const Loads=preload("res://systems/battle_resources.gd")
const English=preload("res://systems/english_translation.gd")
const SLOTS="res://assets/map/events/altar-ritual-slots.png"
const INFO="res://assets/map/events/altar-ritual-info.png"
const FIRE="res://assets/map/ui/altar_fire_inkpaint_8frames.png"
var passed:int=0
var failed:int=0
var captures:int=0
var save:String=""
var session:Node
var map:Control
var locale:String="ko"
func check(value:bool, what:String) -> bool:
	if value: passed+=1; print("PASS ui-altar: ",what)
	else: failed+=1; printerr("FAIL ui-altar: ",what)
	return value
func _initialize() -> void: call_deferred("_run")
func locales() -> Array: return ["ko"]
func until(predicate:Callable, milliseconds:int=12000) -> bool:
	var deadline:int=Time.get_ticks_msec()+milliseconds
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())
func capture(_tag:String) -> void: pass
func dispose() -> void:
	if is_instance_valid(map):
		map.close_overlay()
		var ref:WeakRef=weakref(map)
		map.queue_free()
		check(await until(func():return ref.get_ref()==null),"map and overlay dispose")
	map=null
	check(await until(func():return Loads.PendingLoads.active.is_empty()),"background loads drain")
func create_map() -> void:
	map=MapScene.instantiate()
	root.add_child(map)
	if is_instance_valid(map.map_music): map.map_music.stop()
	for frame in range(5): await process_frame
func fixture(jackpot:bool=false) -> Dictionary:
	session.start_new_world()
	var world=session.world
	var index:int=world.tiles.find("basic")
	world.tiles[index]="altar"
	world.position=index
	world.conceal_boss_below_threshold()
	var chosen_seed:int=0
	var expected:Dictionary={}
	var rng=RandomNumberGenerator.new()
	for candidate in range(1,10000):
		rng.seed=candidate
		var result:Dictionary=Boons.draw(rng)
		if bool(result.jackpot)==jackpot and (jackpot or int(result.attack)==1):
			chosen_seed=candidate
			expected=result
			break
	world.rng.seed=chosen_seed
	check(chosen_seed>0 and not expected.is_empty(),"production catalog finds an actual "+("jackpot" if jackpot else "ordinary")+" seed")
	check(session.save_world(),"isolated altar fixture saves")
	return {"index":index,"donor":world.roster[0].duplicate(true),"target":world.roster[1].duplicate(true),"boon":expected}
func displayed(label:Label) -> void:
	if not is_instance_valid(label) or not label.is_visible_in_tree(): return
	check(label.get_line_count()*label.get_line_height()<=label.size.y+2,"visible flow copy fits "+locale+" "+label.name)
	if locale=="en": check(not English.has_korean(label.tr(label.text)),"flow copy translated "+label.name)
func inspect_panel() -> void:
	if not is_instance_valid(map.overlay): return
	var panel=map.overlay
	for label in [panel.status,panel.altar_level,panel.donor_hint,panel.receiver_hint,panel.boon_title,panel.boon_value]:
		if is_instance_valid(label): displayed(label)
	for action in [panel.close_button,panel.confirm_button]:
		var shown:String=action.tr(action.text)
		var width:float=action.get_theme_font("font").get_string_size(shown,HORIZONTAL_ALIGNMENT_LEFT,-1,action.get_theme_font_size("font_size")).x
		check(width<=action.size.x-18,"action text fits "+locale+" "+shown)
		if locale=="en": check(not English.has_korean(shown),"action translated")
		check(Rect2(0,0,1280,720).encloses(Rect2(action.position,action.size)),"action inside canvas")
func flow(jackpot:bool) -> void:
	var fixture_data:Dictionary=fixture(jackpot)
	var index:int=int(fixture_data.index)
	var donor:Dictionary=fixture_data.donor
	var target:Dictionary=fixture_data.target
	var expected:Dictionary=fixture_data.boon
	var prefix:String=("jackpot" if jackpot else "normal")+"_"+locale
	await create_map()
	map.show_place_actions(index)
	await create_timer(0.5).timeout
	var panel=map.overlay
	check(panel.get_script().resource_path=="res://systems/altar_ritual_panel.gd","actual map routes to production sacrifice-first panel")
	check(panel.altar_slots.texture is AtlasTexture and panel.altar_slots.texture.atlas==load(SLOTS),"source slot art reused with an atlas crop")
	check(panel.altar_info.texture==load(INFO),"source information art reused")
	check(load(FIRE).get_size()==Vector2(1774,887),"approved painted fire atlas imported unchanged")
	check(panel.donor_art.position==Vector2(553,136) and panel.donor_art.size==Vector2(174,231),"approved single donor composition")
	check(panel.receiver_art==null,"target cannot be chosen before boon reveal")
	check(panel.confirm_button.disabled,"no donor disables sacrifice")
	var before:Dictionary=session.world.snapshot().duplicate(true)
	var bytes:PackedByteArray=FileAccess.get_file_as_bytes(save)
	panel.unit_options[str(donor.id)].pressed.emit()
	panel=map.overlay
	check(panel.donor_id==str(donor.id) and panel.receiver_id.is_empty(),"card click selects only a donor before sacrifice")
	check(not panel.confirm_button.disabled,"valid donor with a remaining target enables sacrifice")
	check(session.world.snapshot()==before and FileAccess.get_file_as_bytes(save)==bytes,"donor preview is read-only")
	inspect_panel()
	await capture(prefix+"_01_select")
	session.save_file_path=save+"/blocked.json"
	panel.confirm_button.pressed.emit()
	check(session.world.snapshot()==before and not panel.busy,"failed sacrifice restores exact state and RNG")
	check(not session.owned_unit(str(donor.id)).is_empty() and session.altar_boon(index).is_empty(),"failed sacrifice consumes nothing")
	check(FileAccess.get_file_as_bytes(save)==bytes,"failed sacrifice preserves original save bytes")
	session.save_file_path=save
	var receipts:int=session.world.reward_receipts.size()
	panel.confirm_button.pressed.emit()
	check(panel.busy and panel.confirm_button.disabled and panel.close_button.disabled,"burn blocks duplicate ritual, close and hand input")
	check(session.owned_unit(str(donor.id)).is_empty(),"donor removed before visual effect")
	var pending:Dictionary=session.altar_boon(index)
	check(not pending.is_empty() and pending.boon==expected,"same production draw is stored before fire")
	check(FileAccess.get_file_as_string(save).contains("altar_boon"),"pending boon is already on disk during fire")
	var drawn_rng:int=session.world.rng.state
	panel.select_unit(str(target.id))
	panel.perform_ritual()
	check(panel.receiver_id.is_empty() and session.world.rng.state==drawn_rng,"busy direct callbacks cannot select target or reroll")
	await create_timer(0.27).timeout
	await capture(prefix+"_02_fire")
	if not check(await until(func():return not is_instance_valid(panel) or not panel.busy),"painted fire finishes"): return
	if not check(is_instance_valid(panel),"burn retains owner panel"): return
	check(panel.boon_value.text==panel.boon_text(expected),"revealed text equals saved boon")
	check(panel.donor_art==null and not panel.unit_options.has(str(donor.id)),"spent donor disappears from preview and hand")
	check(panel.receiver_id.is_empty() and panel.confirm_button.disabled,"revealed boon waits for a new target selection")
	inspect_panel()
	await capture(prefix+"_03_reveal")
	before=session.world.snapshot().duplicate(true)
	bytes=FileAccess.get_file_as_bytes(save)
	await dispose()
	session.reload_world()
	check(session.world.snapshot()==before,"pending boon and consumed donor survive JSON reload")
	await create_map()
	check(await until(func():return is_instance_valid(map.overlay)),"startup automatically resumes pending altar")
	panel=map.overlay
	check(panel.get_script().resource_path=="res://systems/altar_ritual_panel.gd" and panel.boon_value.text==panel.boon_text(expected),"startup restores exact revealed boon")
	check(session.world.rng.state==drawn_rng and session.owned_unit(str(donor.id)).is_empty(),"resume cannot restore donor or reroll")
	var remote:int=session.world.tiles.find("village")
	map.show_tile(remote)
	panel=map.overlay
	check(panel.index==index and session.world.snapshot()==before,"remote tile click resumes altar without mutating state")
	panel.unit_options[str(target.id)].pressed.emit()
	panel=map.overlay
	check(panel.receiver_id==str(target.id) and not panel.confirm_button.disabled,"actual target card enables application")
	check(panel.receiver_art.position==Vector2(860,142) and panel.receiver_art.has_node("LayeredCardPreview/LayeredCardBase"),"target uses approved original preview composition and live layers")
	check(session.world.snapshot()==before and FileAccess.get_file_as_bytes(save)==bytes,"target preview preserves pending boon, RNG and file")
	await process_frame
	inspect_panel()
	await capture(prefix+"_04_target")
	session.save_file_path=save+"/blocked.json"
	panel.confirm_button.pressed.emit()
	check(session.world.snapshot()==before and not panel.completed,"failed application retains pending boon and original stats")
	check(panel.receiver_id==str(target.id) and FileAccess.get_file_as_bytes(save)==bytes,"failed application remains retryable without file mutation")
	session.save_file_path=save
	panel.confirm_button.pressed.emit()
	check(panel.completed and panel.confirm_button.disabled,"successful application completes once")
	var receiver:Dictionary=session.owned_unit(str(target.id))
	check(int(receiver.attack)==int(target.attack)+int(expected.attack),"attack matches saved boon")
	check(int(receiver.max_hp)==int(target.max_hp)+int(expected.hp) and int(receiver.current_hp)==int(target.current_hp)+int(expected.hp),"maximum and current HP match saved boon")
	check(int(receiver.speed)==int(target.speed)+int(expected.speed),"speed matches saved boon")
	check(int(receiver.altar_enhancements)==1 and session.world.reward_receipts.size()==receipts+1,"one enhancement and exactly one visit receipt")
	check(session.world.pending_reward.is_empty() and session.world.rng.state==drawn_rng,"apply clears pending without a second random draw")
	check(not session.altar_apply_boon(index,str(target.id)).get("ok",true),"duplicate direct apply rejected")
	check(not session.altar_ritual(index,str(donor.id),str(target.id)).get("ok",true),"legacy ritual cannot bypass completed visit")
	await process_frame
	inspect_panel()
	await capture(prefix+"_05_complete")
	before=session.world.snapshot().duplicate(true)
	await dispose()
	session.reload_world()
	check(session.world.snapshot()==before and typeof(session.owned_unit(str(target.id)).altar_enhancements)==TYPE_INT,"completed enhancement survives restart with integer level")
	await create_map()
	map.show_place_actions(index)
	panel=map.overlay
	check(panel.completed and panel.confirm_button.disabled,"completed visit reopens without another sacrifice")
	check(session.owned_unit(str(donor.id)).is_empty(),"completed visit never restores donor")
	await dispose()
func cancellation() -> void:
	var data:Dictionary=fixture(false)
	var index:int=int(data.index)
	await create_map()
	map.show_place_actions(index)
	var panel=map.overlay
	panel.unit_options[str(data.donor.id)].pressed.emit()
	panel.confirm_button.pressed.emit()
	var before:Dictionary=session.world.snapshot().duplicate(true)
	await dispose()
	session.reload_world()
	check(session.world.snapshot()==before,"closing during burn preserves the committed pending boon")
	await create_map()
	check(await until(func():return is_instance_valid(map.overlay)),"interrupted fire resumes as saved boon")
	check(not map.overlay.busy and not session.altar_boon(index).is_empty(),"restored boon does not repeat fire or consume another donor")
	await dispose()
func constraints() -> void:
	var data:Dictionary=fixture(false)
	var index:int=int(data.index)
	session.world.position=15
	check(session.save_world(),"remote preview fixture saves")
	await create_map()
	map.show_place_actions(index)
	var panel=map.overlay
	check(panel.confirm_button.disabled,"remote altar preview cannot sacrifice")
	for option in panel.unit_options.values(): check(option.disabled,"remote roster input disabled")
	await dispose()
	data=fixture(false)
	index=int(data.index)
	for unit in session.world.roster: unit.altar_enhancements=3
	check(session.save_world(),"maximum enhancement fixture saves")
	await create_map()
	map.show_place_actions(index)
	panel=map.overlay
	for option in panel.unit_options.values(): check(option.disabled,"no valid remaining receiver blocks sacrifice before consumption")
	check(panel.confirm_button.disabled and session.world.roster.size()==2,"all-capped hand preserves both cards")
	await dispose()
func _run() -> void:
	root.size=Vector2i(1280,720)
	session=root.get_node("RunSession")
	var original:String=session.save_file_path
	save="user://ui_altar_random_%d.json"%OS.get_process_id()
	session.save_file_path=save
	for value in locales():
		locale=str(value)
		root.get_node("GameLanguage").set_language(locale,false)
		for jackpot in [false,true]: await flow(jackpot)
	await cancellation()
	await constraints()
	await dispose()
	session.save_file_path=original
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save+suffix))
	check(not FileAccess.file_exists(save),"temporary altar save removed; personal save untouched")
	for frame in range(10): await process_frame
	print("UI_ALTAR_RITUAL_PARITY: %d passed, %d failed"%[passed,failed])
	if DisplayServer.get_name()!="headless": print("ALTAR_RANDOM_CAPTURE: %d passed, %d failed; %d captures"%[passed,failed,captures])
	quit(0 if failed==0 else 1)
