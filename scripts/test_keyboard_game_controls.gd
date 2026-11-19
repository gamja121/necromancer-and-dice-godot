extends SceneTree
## Real key events and pointer events on the production map, cards, story and battle.
const MapScene=preload("res://map.tscn")
const MainBook=preload("res://systems/main_story_book.gd")
const Catalog=preload("res://systems/reward_catalog.gd")
const Child=preload("res://systems/story_event_entry.gd")
var passed:=0
var failed:=0
var session: Node
var navigation: Node
var map: Control
var save_path: String
var original_save: String
var screenshots: String
const KEYS=[KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]
const DIRECTIONS=[Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]

func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool,label: String) -> bool:
	print("PASS keyboard: " if ok else "FAIL keyboard: ",label)
	if ok: passed+=1
	else: failed+=1
	return ok
func until(predicate: Callable,limit:int=16000) -> bool:
	var deadline:=Time.get_ticks_msec()+limit
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	return bool(predicate.call())
func key(code: int,echo: bool=false) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.pressed=true
	event.echo=echo
	root.push_input(event)
	await process_frame
	event=InputEventKey.new()
	event.keycode=code
	root.push_input(event)
	await process_frame
func escape() -> void:
	var event:=InputEventKey.new()
	event.keycode=KEY_ESCAPE
	event.pressed=true
	root.window_input.emit(event)
	for i in range(3): await process_frame
	event=InputEventKey.new()
	event.keycode=KEY_ESCAPE
	root.window_input.emit(event)
	for i in range(3): await process_frame
func point_canvas(position: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=root.get_final_transform()*position
	event.relative=Vector2(15,9)
	root.push_input(event)
	await process_frame
func point(control: Control,click:bool=false,button: MouseButton=MOUSE_BUTTON_LEFT) -> void:
	var position:=control.get_global_transform_with_canvas()*(control.size*0.5)
	await point_canvas(position)
	if click:
		for down in [true,false]:
			var press:=InputEventMouseButton.new()
			press.position=root.get_final_transform()*position
			press.button_index=button
			press.pressed=down
			root.push_input(press)
			await process_frame
func go(destination: Control) -> bool:
	if not is_instance_valid(destination): return check(false,"requested focus target exists")
	# Find a route through the actual scene's direction graph, then send those keys.
	for attempt in range(32):
		navigation.refresh()
		if navigation.target==destination: return true
		if not destination in navigation.controls: return check(false,"desired action belongs to the active focus scope: "+str(destination.name))
		var start: Control=navigation.target
		if not is_instance_valid(start): return check(false,"active scene supplies an initial focus target")
		var queue:Array=[start]
		var paths:Dictionary={start.get_instance_id():[]}
		while not queue.is_empty() and not paths.has(destination.get_instance_id()):
			var from: Control=queue.pop_front()
			for i in range(4):
				var next: Control=navigation.neighbor(from,DIRECTIONS[i])
				if next==null or paths.has(next.get_instance_id()): continue
				var path: Array=paths[from.get_instance_id()].duplicate()
				path.append(KEYS[i])
				paths[next.get_instance_id()]=path
				queue.append(next)
		if not paths.has(destination.get_instance_id()):
			return check(false,"four directions reach "+str(destination.name))
		var route: Array=paths[destination.get_instance_id()]
		if route.is_empty(): return true
		await key(int(route[0]))
	return check(false,"direction navigation settles on "+str(destination.name))

func all_reachable(label: String) -> void:
	navigation.refresh()
	if navigation.controls.is_empty():
		check(false,label+": usable controls exist")
		return
	var visited:Dictionary={}
	var queue:Array=[navigation.controls[0]]
	while not queue.is_empty():
		var source: Control=queue.pop_front()
		if visited.has(source.get_instance_id()): continue
		visited[source.get_instance_id()]=true
		for direction in DIRECTIONS:
			var target: Control=navigation.neighbor(source,direction)
			if target!=null and not visited.has(target.get_instance_id()): queue.append(target)
	check(visited.size()==navigation.controls.size(),label+": every active action is reachable with four directions")

func photograph(label: String) -> void:
	if screenshots.is_empty() or DisplayServer.get_name()=="headless": return
	await create_timer(0.22).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(screenshots.path_join(label+".png"))==OK,"native screenshot "+label)

func fresh_map() -> void:
	if is_instance_valid(map):
		map.queue_free()
		await process_frame
	session.save_file_path=save_path
	check(session.start_new_world(),"isolated fresh expedition")
	map=MapScene.instantiate()
	root.add_child(map)
	current_scene=map
	for i in range(5): await process_frame
	navigation.refresh()

func board_and_inventory() -> void:
	await fresh_map()
	all_reachable("board")
	var before: Dictionary=session.world.snapshot().duplicate(true)
	check(await go(map.book_button),"keyboard reaches the monster book")
	await photograph("01-book-focus")
	await key(KEY_ENTER)
	check(await until(func(): return is_instance_valid(map.overlay) and not map.overlay.changing),"Enter opens the actual monster book")
	if not is_instance_valid(map.overlay): return
	var inventory: Control=map.overlay
	var card: BaseButton=inventory.find_child("InventoryInspect_unit_0",true,false)
	if not check(card!=null,"owned monster is present"): return
	all_reachable("monster book")
	await go(card)
	await key(KEY_ENTER)
	check(not is_instance_valid(inventory.info) and navigation.target==card,"Enter focuses the book monster without opening details")
	await photograph("01b-book-monster-actions")
	await key(KEY_SPACE)
	if not check(await until(func(): return is_instance_valid(inventory.info)),"Space opens information for the focused book monster"): return
	navigation.refresh()
	check(inventory.info.is_ancestor_of(navigation.target),"focus stays inside the information window")
	await escape()
	check(await until(func(): return not is_instance_valid(inventory.info)),"Esc closes only the information window")
	check(map.overlay==inventory,"monster book remains after closing information")
	await point(card)
	check(not navigation.keyboard_mode and navigation.target==card,"pointer hover takes over from keyboard focus")
	await point(card,true)
	check(not is_instance_valid(inventory.info) and navigation.target==card,"left-click only focuses the book monster")
	await point(card,true,MOUSE_BUTTON_RIGHT)
	if not check(await until(func(): return is_instance_valid(inventory.info)),"right-click opens book monster information"): return
	var close: BaseButton=inventory.info.find_child("InfoClose",true,false)
	await point(close,true)
	check(await until(func(): return not is_instance_valid(inventory.info)),"mouse closes the information window")
	await point(card)
	await point(card.get_node("MonsterInspectSeal"),true)
	check(await until(func(): return is_instance_valid(inventory.info)),"clicking the decorative seal opens information")
	await escape()
	if not check(await until(func():return not is_instance_valid(inventory.info)),"seal opens the same closable information window"): return
	await escape()
	check(await until(func():return not is_instance_valid(map.overlay)),"Esc returns from the book to the board")
	check(session.world.snapshot()==before,"mixed inspection preserves the entire save and RNG")

func dice_card_and_space() -> void:
	var fixed: Dictionary=Catalog.dice_cards().filter(func(c):return c.card_id=="fixed-1")[0]
	var item: Dictionary=session.create_item("dice",fixed)
	session.world.dice_cards.append(item)
	# Test-only safe one-step destination, retaining the normal board multiset.
	var destination:int=(session.world.position+1)%session.world.tiles.size()
	var road:int=session.world.tiles.find("basic")
	var original:String=session.world.tiles[destination]
	session.world.tiles[destination]="basic"
	session.world.tiles[road]=original
	session.save_world()
	map.close_overlay(false)
	map.render()
	await process_frame
	await go(map.deck_button)
	await key(KEY_ENTER)
	check(await until(func():return is_instance_valid(map.overlay) and not map.overlay.opening),"keyboard opens the actual dice-card fan")
	if not is_instance_valid(map.overlay): return
	var hand: Control=map.overlay
	var card: BaseButton=hand.options[0]
	all_reachable("dice-card fan")
	await go(card)
	await photograph("02-dice-card-focus")
	var before_serial:int=session.world.move_serial
	await key(KEY_ENTER)
	await key(KEY_ENTER,true)
	check(await until(func():return not map.moving and session.world.pending_move.is_empty() and not is_instance_valid(map.overlay),18000),"Enter uses a dice card and completes its actual map move")
	check(session.world.previous_map_roll==1 and session.world.move_serial==before_serial+1,"card Enter produces exactly one controlled roll")
	check(not session.world.dice_cards.any(func(c):return c.id==item.id),"used dice card is consumed exactly once")
	var next_serial:int=session.world.move_serial
	await key(KEY_SPACE)
	await key(KEY_SPACE,true)
	check(await until(func():return not map.moving and session.world.pending_move.is_empty(),18000),"Space completes an ordinary map roll")
	check(session.world.move_serial==next_serial+1,"holding Space cannot duplicate a movement")

func story_and_location() -> void:
	await fresh_map()
	map.close_overlay(false)
	session.world.contamination=93
	session.world.lap_ready=true
	session.world.leave_home()
	var index:int=session.world.tiles.find("graveyard")
	session.world.position=index
	session.save_world()
	map.render()
	await process_frame
	await go(map.buttons[index])
	await key(KEY_ENTER)
	check(map.overlay is MainBook,"keyboard opens the actual eligible main event")
	if not map.overlay is MainBook: return
	var panel: Control=map.overlay
	var before: Dictionary=session.world.snapshot().duplicate(true)
	await escape()
	check(map.overlay==panel and session.world.snapshot()==before,"Esc keeps the mandatory event and save unchanged")
	var deadline:=Time.get_ticks_msec()+12000
	while Child.current_beat(session)<3 and Time.get_ticks_msec()<deadline:
		await key(KEY_ENTER)
	check(Child.current_beat(session)==3,"Enter reveals and advances the real narrative to its branch")
	panel=map.overlay
	if panel.opening: await key(KEY_ENTER)
	if panel.typewriter.is_revealing(): await key(KEY_ENTER)
	var leave: BaseButton
	for button in panel.get_children():
		if button is Button and button.text=="지나친다": leave=button
	if not check(leave!=null,"the original story branch remains available"): return
	all_reachable("main event choices")
	await go(leave)
	await photograph("03-story-choice")
	await key(KEY_ENTER)
	await key(KEY_ENTER,true)
	check(session.get_story_event(Child.EVENT_ID).choice=="leave","Enter commits the focused story decision")
	check(await until(func():return is_instance_valid(map.overlay) and map.overlay.get_script()==preload("res://systems/exploration_actions.gd"),7000),"completed book opens the graveyard function")
	navigation.refresh()
	all_reachable("graveyard")
	await photograph("04-graveyard-action")
	await escape()
	check(await until(func():return not is_instance_valid(map.overlay)),"Esc leaves the ordinary tile function")

func tile_and_event_navigation() -> void:
	await fresh_map()
	var index:int=session.world.tiles.find("basic")
	for kind in ["village","altar","rest","forest","unknown","fortune-teller-camp","home"]:
		map.close_overlay(false)
		session.world.position=index
		session.world.tiles[index]=kind
		if kind=="home": map.show_home()
		else: map.show_location(index)
		await create_timer(0.4).timeout
		navigation.refresh()
		all_reachable(kind+" location")
		check(not map.book_button in navigation.controls,kind+": background book cannot receive modal focus")
		if kind=="village":
			var store: BaseButton
			for node in navigation.controls:
				if node is Button and node.text.contains("상점"): store=node
			if check(store!=null,"village exposes its shop action"):
				await go(store)
				await key(KEY_ENTER)
				await create_timer(0.4).timeout
				all_reachable("shop")
		elif kind=="altar":
			var ritual: BaseButton
			for node in navigation.controls:
				if node is Button and (node.text.contains("강화") or node.text.contains("의식")): ritual=node
			if check(ritual!=null,"altar exposes its ritual action"):
				await go(ritual)
				await key(KEY_ENTER)
				await create_timer(0.4).timeout
				all_reachable("altar sacrifice")
	map.close_overlay(false)
	map.show_discovery_card("forest")
	await create_timer(0.4).timeout
	navigation.refresh()
	var discovery: Control=map.overlay.find_child("EventDiscoveryCard",true,false)
	check(is_instance_valid(discovery) and navigation.scope==discovery,"discovery card captures keyboard input")
	await key(KEY_ENTER)
	check(await until(func():return not is_instance_valid(map.overlay)),"Enter acknowledges the ordinary discovery surface")
	map.show_ordinary_event_preview()
	await create_timer(0.4).timeout
	await escape()
	check(await until(func():return not is_instance_valid(map.overlay)),"Esc closes an ordinary event preview")

func owned_hand_card(deck: Control, roster_index: int) -> Control:
	var expected_key := "unit:"+str(deck.owned[roster_index].id)
	for candidate in deck.hand.get_children():
		if candidate.get_meta("keyboard_focus_key","")==expected_key: return candidate
	return null

func battle_and_capture() -> void:
	await fresh_map()
	map.close_overlay(false)
	session.world.laps=2
	session.world.contamination=20
	var index:int=session.world.tiles.find("monster")
	session.world.position=index
	session.world.rng.seed=1803
	session.save_world()
	map.render()
	await process_frame
	await go(map.buttons[index])
	await key(KEY_ENTER)
	if not check(is_instance_valid(map.overlay) and map.overlay.get_script()==preload("res://systems/battle_deck.gd"),"Enter opens the normal battle lineup"): return
	var deck: Control=map.overlay
	await create_timer(0.5).timeout
	all_reachable("battle lineup")
	var owned_buttons: Array=deck.hand.find_children("*","TextureButton",true,false)
	if not check(owned_buttons.size()>=2,"two genuine owned battle cards"): return
	await go(owned_hand_card(deck,0))
	await key(KEY_ENTER)
	await process_frame
	check(deck.selected_ids.size()==1,"Enter selects one owned combatant")
	await go(owned_hand_card(deck,1))
	await key(KEY_ENTER)
	await process_frame
	check(deck.selected_ids.size()==2,"Enter selects a second owned combatant")
	await go(deck.confirm_button)
	await photograph("05-battle-lineup")
	await key(KEY_ENTER)
	if not check(await until(func():return is_instance_valid(map.embedded_battle) and not map.embedded_battle.entry_summon_active and not map.embedded_battle.busy,16000),"keyboard starts the real embedded battle"): return
	var battle: Control=map.embedded_battle
	if is_instance_valid(battle.brand_reference): await escape()
	for unit: Dictionary in battle.rules.units:
		unit.passive=""
		unit.brands=[]
		unit.attack=999 if unit.team=="ally" else 0
		unit.base_attack=unit.attack
		unit.speed=999 if unit.team=="ally" else 0
		unit.base_speed=unit.speed
		if unit.team=="enemy": unit.hp=1
	battle.rules.refresh()
	session.encounter.checkpoint=battle.rules.snapshot()
	session.world.active_encounter=session.encounter.duplicate(true)
	session.save_world()
	await key(KEY_SPACE)
	await key(KEY_SPACE,true)
	if not check(await until(func():return is_instance_valid(map.embedded_battle) and is_instance_valid(map.embedded_battle.capture_panel),22000),"Space resolves combat into soul harvest"): return
	var capture: Control=map.embedded_battle.capture_panel
	navigation.refresh()
	check(navigation.scope==capture,"reward navigation uses the capture scope")
	check(not map.buttons[index] in navigation.controls and not map.book_button in navigation.controls,"reward keys cannot activate the underlying board")
	all_reachable("soul harvest")
	if not check(capture.choices.size()==2,"two actual defeated monsters available"): return
	await go(capture.choices[1].card)
	await key(KEY_ENTER)
	check(session.world.pending_reward.selected==1,"Enter selects the focused reward monster")
	session.world.pending_reward.corpses[1].target=1
	session.save_world()
	await photograph("06-soul-harvest")
	var roster_before:int=session.world.roster.size()
	await key(KEY_SPACE)
	await key(KEY_SPACE,true)
	check(await until(func():return not is_instance_valid(map.embedded_battle) and not map.battle_returning,20000),"Space harvest completes and returns to board")
	check(session.world.roster.size()==roster_before+1 and session.world.pending_reward.is_empty(),"keyboard harvest grants one saved monster")

func _run() -> void:
	screenshots=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else ""
	session=root.get_node("RunSession")
	navigation=root.get_node("KeyboardNavigation")
	root.get_node("GameLanguage").set_language("ko",false)
	original_save=session.save_file_path
	save_path="user://keyboard_game_controls_%d.json"%OS.get_process_id()
	root.size=Vector2i(1280,720)
	await board_and_inventory()
	await dice_card_and_space()
	await story_and_location()
	await tile_and_event_navigation()
	await battle_and_capture()
	if is_instance_valid(map): map.queue_free()
	await process_frame
	session.save_file_path=original_save
	for suffix in ["",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path+suffix))
	print("KEYBOARD_GAME_CONTROLS: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
