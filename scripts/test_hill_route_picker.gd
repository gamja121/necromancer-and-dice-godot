extends SceneTree
## Approved hill picker: actual UI, backend transactions and restart boundaries.
const MAP=preload("res://map.tscn")
const ACTIONS=preload("res://systems/exploration_actions.gd")
const PICKER=preload("res://systems/hill_route_picker.gd")
const STATE=preload("res://systems/map_state.gd")
var passed:int=0
var failed:int=0
var session:Node
var scratch:String
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok: passed+=1; print("PASS hill-picker: ",label)
	else: failed+=1; printerr("FAIL hill-picker: ",label)
func until(predicate:Callable,limit:int=10000) -> bool:
	var end:int=Time.get_ticks_msec()+limit
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return bool(predicate.call())
func fixture(index:int=3) -> void:
	session.start_new_world()
	var protected:Array=[0,8,STATE.HOME,index]
	for steps in range(1,7): protected.append((index+steps)%24)
	for destination in [index]+range(index+1,index+7):
		var slot:int=destination%24
		if slot in [0,8,STATE.HOME]: continue
		var kind:String="forest" if slot==index else "basic"
		if session.world.tiles[slot]==kind: continue
		if session.world.tiles[slot]!="basic":
			var replacement:int=-1
			for candidate in range(24):
				if candidate not in protected and session.world.tiles[candidate]=="basic":
					replacement=candidate
					break
			check(replacement>=0,"fixture preserves original tile types on a spare road")
			if replacement>=0: session.world.tiles[replacement]=session.world.tiles[slot]
		session.world.tiles[slot]=kind
	session.world.position=index
	check(session.save_world(),"isolated hill fixture saves")
	var restored=STATE.new(session.world.definitions,1)
	check(restored.restore(session.world.snapshot()),"fixture retains all canonical save anchors and restores")

func open(index:int) -> Control:
	var map:Control=MAP.instantiate()
	root.add_child(map)
	for frame in range(3): await process_frame
	map.show_location(index)
	check(is_instance_valid(map.overlay) and map.overlay.get_script()==ACTIONS,"real hill location opens the route UI directly")
	return map
func dispose(map:Control) -> void:
	map.queue_free()
	await process_frame
	await until(func(): return preload("res://systems/battle_resources.gd").PendingLoads.active.is_empty())
	var audio:Node=root.get_node_or_null("GameAudio")
	await until(func(): return audio==null or audio.voices.is_empty())
	await create_timer(0.10).timeout
func geometry(map:Control,panel:Control) -> void:
	var strip:TextureRect=panel.content.get_node("HillNoticeStrip")
	check(Rect2(strip.position,strip.size)==Rect2(340,423,600,150) and strip.texture.resource_path.ends_with("fortune_parchment_strip.webp"),"original prophet parchment geometry and asset are shared")
	check(Rect2(panel.hill_notice.position,panel.hill_notice.size)==Rect2(394,465,492,30) and panel.hill_notice.get_theme_font_size("font_size")==20,"shared notice placement and font remain readable")
	for pair in [[panel.action_button,map.TILE_EVENT_ACTION_RECT],[panel.close_button,map.TILE_EVENT_EXIT_RECT]]:
		var control:Button=pair[0]
		check(Rect2(control.position,control.size)==pair[1] and map.LOCATION_EVENT_SCENE_RECT.encloses(Rect2(control.position,control.size)),"ordinary action and exit slots remain inside the painting")
		var style:StyleBoxTexture=control.get_theme_stylebox("normal")
		check(style.texture.resource_path.ends_with("parchment_button_variant_04.png") and control.get_theme_font_size("font_size")==18,"original parchment button art and font are retained")
	check(panel.hill_choice_buttons.size()==6,"exactly six destination hit areas are displayed")
	for i in range(6):
		var choice:Button=panel.hill_choice_buttons[i]
		var rect:Rect2=Rect2(choice.position,choice.size)
		check(map.LOCATION_EVENT_SCENE_RECT.encloses(rect),"destination remains inside original artwork")
		if i>0: check(not rect.intersects(Rect2(panel.hill_choice_buttons[i-1].position,panel.hill_choice_buttons[i-1].size)),"neighbor destination targets do not overlap")
		var kind:String=str(session.world.tiles[(panel.index+i+1)%24])
		check(panel.hill_picker.pictures[i].texture.resource_path=="res://assets/map/tiles/%s.png"%kind,"destination uses the actual forward map tile artwork")
func normal_and_failure() -> void:
	fixture()
	check(session.set_event_flag("ui:unlock:forest:action_pending",true),"unread hill action marker fixture saves")
	var map:Control=await open(3)
	var panel:Control=map.overlay
	geometry(map,panel)
	check(panel.action_button.text=="여기로 이동" and panel.action_button.disabled and not panel.busy,"initial common primary waits for a destination")
	var marker:Control=panel.action_button.get_node_or_null("UnlockNewBadge")
	check(is_instance_valid(marker) and marker.visible,"unread action NEW marker remains on the actual common primary")
	var before:Dictionary=session.world.snapshot().duplicate(true)
	var rng_before:int=session.world.rng.state
	var bytes:PackedByteArray=FileAccess.get_file_as_bytes(scratch)
	panel.hill_choice_buttons[3].pressed.emit()
	check(panel.hill_selected_steps==4 and map.selected==7 and not panel.action_button.disabled,"real tile press selects four steps and highlights the actual landing")
	check(panel.hill_picker.flag.visible and panel.hill_picker.selected_steps==4 and panel.hill_picker.pictures[3].scale==Vector2.ONE*1.16,"one selected destination enlarges and receives the approved flag")
	panel.hill_choice_buttons[1].pressed.emit()
	check(panel.hill_selected_steps==2 and map.selected==5 and panel.hill_picker.pictures[3].scale==Vector2.ONE,"changing destination clears the old enlargement and moves the preview")
	check(session.world.snapshot()==before and FileAccess.get_file_as_bytes(scratch)==bytes and session.event_flag_is_set("ui:unlock:forest:action_pending"),"selection changes no save, RNG, inventory, receipt or unread state")
	panel.close_button.pressed.emit()
	check(await until(func(): return not is_instance_valid(map.overlay)),"one exit returns directly to the playable board")
	check(map.selected==3 and session.world.snapshot()==before,"cancel restores the current-tile highlight and grants no movement")
	map.show_location(3)
	panel=map.overlay
	panel.select_hill_step(4)
	session.save_file_path="user://missing_hill_picker_%d/save.json"%OS.get_process_id()
	panel.action_button.pressed.emit()
	check(map.overlay==panel and not panel.busy and not panel.action_button.disabled and not panel.close_button.disabled,"save failure preserves the chosen direct screen and allows retry or exit")
	check(not map.moving and session.world.snapshot()==before and FileAccess.get_file_as_bytes(scratch)==bytes,"failed confirmation creates no movement, consumed paper or transaction")
	check(not panel.hill_notice.text.is_empty() and panel.hill_notice.text==session.notice,"failed save reason is visible in the common notice")
	session.save_file_path=scratch
	var receipt:String=session.place_visit_id("hill-route",3)
	panel.action_button.pressed.emit()
	check(panel.busy and map.moving and session.world.pending_move.get("source","")=="hill","successful explicit confirmation saves before departure")
	check(session.world.pending_move.path==[4,5,6,7] and session.world.reward_receipts.count(receipt)==1,"saved path and exact pre-move receipt are committed once")
	check(panel.hill_choice_buttons.all(func(control): return control.disabled) and panel.close_button.disabled,"departure locks every choice and exit")
	check(not session.event_flag_is_set("ui:unlock:forest:action_pending"),"only confirmed use acknowledges the NEW action marker")
	panel.confirm_hill_route()
	check(session.world.reward_receipts.count(receipt)==1,"repeated confirm cannot duplicate the transaction")
	check(await until(func(): return not map.moving and session.world.pending_move.is_empty()),"original paper consumption and real hero travel finish")
	check(session.world.position==7 and map.selected==7 and map.hero.position.distance_to(map.hero_position(7))<0.5,"hero and destination agree after the actual path")
	check(session.world.rng.state==rng_before and session.world.last_face==int(before.last_face),"directed travel preserves the original dice state")
	var committed:Dictionary=session.world.snapshot().duplicate(true)
	await dispose(map)
	session.reload_world()
	check(session.world.snapshot()==committed,"completed directed move survives reload")
func boundaries_and_guards() -> void:
	var hill:int=(STATE.HOME-2+24)%24
	fixture(hill)
	var map:Control=await open(hill)
	var panel:Control=map.overlay
	check(panel.hill_picker.max_steps==2 and not panel.hill_choice_buttons[1].disabled,"actual HOME at distance two is selectable")
	check(panel.hill_choice_buttons.slice(2).all(func(control): return control.disabled),"all choices beyond HOME are disabled")
	panel.hill_choice_buttons[2].pressed.emit()
	panel.select_hill_step(3)
	check(panel.hill_selected_steps==0 and panel.action_button.disabled,"disabled and direct out-of-bound selection cannot enable movement")
	panel.hill_choice_buttons[1].pressed.emit()
	check(panel.hill_selected_steps==2 and panel.hill_notice.text.contains("우리집"),"HOME itself is an explicit visible destination")
	await dispose(map)
	fixture()
	session.world.position=0
	check(session.save_world(),"non-current hill preview fixture saves")
	map=await open(3)
	panel=map.overlay
	check(panel.hill_choice_buttons.all(func(control): return control.disabled) and panel.action_button.disabled and not panel.close_button.disabled,"a remote hill preview permits exit but no free movement")
	check(panel.hill_notice.text.contains("현재 언덕"),"remote hill explains the existing location restriction")
	await dispose(map)
	fixture()
	map=await open(3)
	map.close_overlay()
	session.world.pending_reward={"kind":"treasure"}
	map.show_location(3)
	panel=map.overlay
	check(panel.hill_choice_buttons.all(func(control): return control.disabled) and panel.action_button.disabled,"a pending reward prevents new hill actions")
	check(panel.hill_notice.text.contains("보상"),"pending activity reason appears on the common parchment")
	await dispose(map)
func interrupted_departure() -> void:
	fixture()
	var map:Control=await open(3)
	var panel:Control=map.overlay
	panel.select_hill_step(2)
	panel.confirm_hill_route()
	var saved:Dictionary=session.world.snapshot().duplicate(true)
	await create_timer(0.10).timeout
	map.queue_free()
	await process_frame
	check(session.world.snapshot()==saved and not session.world.pending_move.is_empty(),"interrupting the departure paper preserves the committed pending path")
	session.reload_world()
	map=MAP.instantiate()
	root.add_child(map)
	check(await until(func(): return not map.moving and session.world.pending_move.is_empty()),"new map resumes the saved hill movement")
	check(session.world.position==5 and session.world.move_serial==1 and session.world.reward_receipts.size()==1,"restart finishes the same directed move without another receipt")
	await dispose(map)
func long_names() -> void:
	var tiles:Array=[]
	tiles.resize(24)
	tiles.fill("basic")
	tiles[1]="fortune-teller-camp"
	tiles[2]="swamp"
	tiles[6]=null
	var picker:Control=PICKER.new()
	root.add_child(picker)
	picker.setup(tiles,0,4,true)
	for frame in range(3): await process_frame
	check(picker.captions[0].text==STATE.NAMES["fortune-teller-camp"] and picker.captions[0].autowrap_mode==TextServer.AUTOWRAP_WORD_SMART,"long canonical place names retain readable wrapping")
	check(picker.captions[1].text==STATE.NAMES["swamp"] and picker.captions[1].get_minimum_size().y<=picker.captions[1].size.y,"long swamp label fits its allotted height")
	check(picker.choice_buttons[5].disabled and picker.pictures[5].texture!=null,"unavailable unknown slots have a safe thumbnail without invalid resource loads")
	picker.queue_free()
	await process_frame
func run() -> void:
	session=root.get_node("RunSession")
	var old_path:String=session.save_file_path
	scratch="user://hill_route_picker_%d.json"%OS.get_process_id()
	session.save_file_path=scratch
	await normal_and_failure()
	await boundaries_and_guards()
	await interrupted_departure()
	await long_names()
	var audio:Node=root.get_node_or_null("GameAudio")
	await until(func(): return audio==null or audio.voices.is_empty())
	if audio!=null: audio.queue_free()
	await create_timer(0.15).timeout
	session.world=null
	session.save_file_path=old_path
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("HILL_ROUTE_PICKER: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
