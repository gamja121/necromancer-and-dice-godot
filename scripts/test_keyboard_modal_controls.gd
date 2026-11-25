extends "res://scripts/test_keyboard_game_controls.gd"

func settings_controls() -> void:
	await fresh_map()
	await escape()
	if not check(map.map_audio.is_open(),"Esc opens map settings"): return
	var settings: Control=map.map_audio
	navigation.refresh()
	check(navigation.scope==settings.panel,"settings own the active keyboard scope")
	check(navigation.keyboard_mode,"Esc hands focus back to keyboard mode")
	all_reachable("settings")
	await go(settings.music_toggle)
	var muted:bool=AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))
	await key(KEY_ENTER)
	await key(KEY_ENTER,true)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))!=muted,"held Enter toggles music once")
	await key(KEY_ENTER)
	await go(settings.advanced_button)
	await key(KEY_ENTER)
	check(settings.advanced_content.visible,"Enter opens advanced settings")
	await go(settings.volume_slider)
	var volume:float=settings.volume_slider.value
	await key(KEY_LEFT)
	check(settings.volume_slider.value<volume,"Left adjusts focused volume")
	await key(KEY_RIGHT)
	all_reachable("expanded settings")
	await photograph("07-settings-focus")
	await escape()
	check(not settings.is_open(),"Esc returns from settings to the board")

func lineup_information() -> void:
	map.show_battle_deck(session.world.tiles.find("monster"))
	await create_timer(0.85).timeout
	var deck: Control=map.overlay
	var card: BaseButton=owned_hand_card(deck,1)
	await go(card)
	var before: Dictionary=session.world.snapshot().duplicate(true)
	check(not card.has_node("MonsterInspectSeal") and not card.has_node("OwnedCardInfo"),"PC battle cards keep the artwork clear of inspection buttons")
	check(deck.find_child("DeckBackButton",true,false)==null and deck.close_button.get_parent()==deck.board,"the only close action sits inside the descending frame")
	all_reachable("battle deck with frame close")
	await photograph("11-battle-card-actions")
	await key(KEY_SPACE)
	await key(KEY_SPACE,true)
	if not check(await until(func():return is_instance_valid(deck.info_window)),"Space opens battle-card information"): return
	check(deck.selected_ids.is_empty() and session.world.snapshot()==before,"Space changes neither the lineup nor the board dice state")
	var info: Control=deck.info_window
	await go(info.rename_button)
	await key(KEY_ENTER)
	navigation.refresh()
	check(is_instance_valid(info.rename_dialog) and navigation.scope==info.rename_dialog,"naming editor traps focus in its own overlay")
	await escape()
	check(not is_instance_valid(info.rename_dialog) and is_instance_valid(deck.info_window),"Esc cancels naming while keeping information open")
	await escape()
	check(await until(func():return not is_instance_valid(deck.info_window)),"second Esc returns to the lineup")
	navigation.refresh()
	check(navigation.target.get_meta("keyboard_focus_key","")=="unit:"+str(deck.owned[1].id),"information closes back to the original card")
	await point(card,true,MOUSE_BUTTON_RIGHT)
	if not check(await until(func():return is_instance_valid(deck.info_window)),"right-click opens the same battle-card information"): return
	check(deck.info_window.current_name==str(deck.owned[1].name) and deck.selected_ids.is_empty(),"right-click inspects the pointed monster without selecting it")
	await escape()
	if not check(await until(func():return not is_instance_valid(deck.info_window)),"right-click information finishes closing"): return
	await point(card,true)
	check(deck.selected_ids==[deck.owned[1].id] and not is_instance_valid(deck.info_window),"left-click selects the monster without opening details")
	await escape()
	check(await until(func():return not is_instance_valid(map.overlay)),"Esc leaves ordinary lineup")
	map.show_battle_deck(session.world.tiles.find("monster"))
	await create_timer(0.85).timeout
	var reopened: Control = map.overlay
	await point(reopened.close_button,true)
	check(await until(func():return not is_instance_valid(map.overlay)),"mouse closes the deck with the in-frame ×")
	check(session.world.snapshot()==before,"both close paths return without changing the expedition")

func pointer_stacking() -> void:
	await fresh_map()
	await go(map.book_button)
	await key(KEY_ENTER)
	if not check(await until(func():return is_instance_valid(map.overlay) and not map.overlay.changing),"pointer stacking opens the real monster hand"): return
	var book: Control=map.overlay
	var first: Control=book.find_child("InventoryInspect_unit_0",true,false)
	var second: Control=book.find_child("InventoryInspect_unit_1",true,false)
	await point(first)
	check(navigation.target==first,"mouse enters the visible first card")
	var overlap: Vector2=first.get_global_transform_with_canvas()*Vector2(first.size.x-22,115)
	await point_canvas(overlap)
	check(navigation.target==first,"overlap keeps the visible front card instead of raising a card behind it")
	await photograph("10-overlap-focus")
	await point(second)
	await point_canvas(Vector2(640,320))
	check(navigation.target==second,"blank-space mouse movement retains the last valid card for keyboard resumption")
	await key(KEY_SPACE)
	check(await until(func():return is_instance_valid(book.info)),"Space resumes inspection after the mouse leaves the cards")
	await escape()
	await until(func():return not is_instance_valid(book.info))
	root.size=Vector2i(1600,900)
	for i in range(3): await process_frame
	await point(first)
	check(navigation.target==first,"mouse handoff works at the desktop window size")
	overlap=first.get_global_transform_with_canvas()*Vector2(first.size.x-22,115)
	await point_canvas(overlap)
	check(navigation.target==first,"front-card picking stays correct after window scaling")
	root.size=Vector2i(1280,720)
	for i in range(3): await process_frame
	await escape()
	check(await until(func():return not is_instance_valid(map.overlay)),"mixed pointer inspection returns to board")

func full_book_reward() -> void:
	await fresh_map()
	var original: Dictionary=session.world.roster[0].duplicate(true)
	while session.world.roster.size()<Catalog.UNIT_CAPACITY:
		session.world.roster.append(session.create_item("unit",{"slug":original.slug,"name":original.name}))
	var index:int=session.world.tiles.find("gem")
	session.world.position=index
	var preview:=RandomNumberGenerator.new()
	for seed in range(1,100):
		preview.seed=seed
		if preview.randf()>=0.10:
			session.world.rng.seed=seed
			break
	session.save_world()
	map.render()
	await process_frame
	await go(map.buttons[index])
	await key(KEY_ENTER)
	check(map.tile_info_panel.visible and session.world.pending_reward.is_empty(),"chest tile Enter does not open or draw the chest")
	map.close_tile_info()
	map.show_tile(index,true)
	if not check(await until(func():return is_instance_valid(map.overlay) and map.overlay.get_script()==preload("res://systems/treasure_reward.gd") and not map.overlay.busy),"treasure tile arrival opens a real ordinary treasure chest"): return
	var chest: Control=map.overlay
	all_reachable("treasure cards")
	var offer_index:int=-1
	for i in range(session.world.pending_reward.offers.size()):
		if session.world.pending_reward.offers[i].kind=="unit": offer_index=i
	if not check(offer_index>=0,"chest contains the actual monster offer"): return
	await go(chest.options[offer_index])
	await key(KEY_ENTER)
	await go(chest.confirm_button)
	await key(KEY_ENTER)
	if not check(await until(func():return not get_nodes_in_group("keyboard_modal_scope").is_empty()),"full monster book opens its exchange window"): return
	var overflow: Control=get_nodes_in_group("keyboard_modal_scope")[0]
	navigation.refresh()
	check(navigation.scope==overflow and not chest.confirm_button in navigation.controls,"exchange window owns keys over its parent chest")
	all_reachable("full-book exchange")
	var prior_roster: Array=session.world.roster.duplicate(true)
	await go(overflow.decline_button)
	await photograph("08-overflow-focus")
	await key(KEY_ENTER)
	await key(KEY_ENTER,true)
	check(overflow.selected=="__new__" and not overflow.monster_commit_pending,"first decline arms confirmation and held Enter cannot discard")
	await key(KEY_ENTER)
	check(await until(func():return not is_instance_valid(map.overlay) and session.world.pending_reward.is_empty(),10000),"keyboard decline resolves the actual reward receipt and closes the chest")
	check(session.world.roster==prior_roster,"declining the new monster preserves all ten owned monsters")

func scrolling_collections() -> void:
	await fresh_map()
	# Read-only legacy collections may exceed today's capacity; keep every card accessible.
	var original: Dictionary=session.world.roster[0].duplicate(true)
	while session.world.roster.size()<15:
		session.world.roster.append(session.create_item("unit",{"slug":original.slug,"name":original.name}))
	while session.world.dice_cards.size()<13:
		session.world.dice_cards.append(session.create_item("dice",Catalog.dice_cards()[0]))
	map.show_inventory("unit")
	if not check(await until(func():return is_instance_valid(map.overlay) and not map.overlay.changing),"oversized legacy book opens"): return
	var book: Control=map.overlay
	all_reachable("scrolling monster book")
	var last: Control=book.find_child("InventoryInspect_unit_14",true,false)
	if not check(await go(last),"arrows reach the last legacy monster"): return
	await create_timer(0.3).timeout
	var scroll: ScrollContainer=book.find_child("RosterHandScroll",true,false)
	var center: Vector2=scroll.get_global_transform_with_canvas().affine_inverse()*(last.get_global_transform_with_canvas()*(last.size*0.5))
	check(scroll.follow_focus and scroll.scroll_horizontal>0 and center.x>0 and center.x<scroll.size.x,"selected monster automatically scrolls into view")
	await point_canvas(book.close_button.get_global_transform_with_canvas()*Vector2(4,20))
	check(root.gui_get_hovered_control()==book.close_button,"native pointer sees the visible close action above clipped cards")
	check(navigation.target==book.close_button,"clipped cards cannot steal mouse focus from the visible close action")
	# The map intentionally hides tabs on its monster-only hand. Exercise the legacy dice inspection surface directly.
	book.show_kind("dice")
	if not check(await until(func():return not book.changing),"legacy dice inventory opens"): return
	all_reachable("scrolling dice inventory")
	last=book.find_child("InventoryInspect_dice_12",true,false)
	if not check(await go(last),"arrows reach the last legacy dice card"): return
	await create_timer(0.3).timeout
	scroll=last.get_parent().get_parent().get_parent()
	center=scroll.get_global_transform_with_canvas().affine_inverse()*(last.get_global_transform_with_canvas()*(last.size*0.5))
	check(scroll.follow_focus and scroll.scroll_horizontal>0 and center.x>0 and center.x<scroll.size.x,"selected dice card automatically scrolls into view")
	await photograph("09-scroll-focus")
	await escape()
	check(await until(func():return not is_instance_valid(map.overlay)),"Esc returns from the scrolling book")

func _run() -> void:
	screenshots=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else ""
	session=root.get_node("RunSession")
	navigation=root.get_node("KeyboardNavigation")
	root.get_node("GameLanguage").set_language("ko",false)
	original_save=session.save_file_path
	save_path="user://keyboard_modal_controls_%d.json"%OS.get_process_id()
	root.size=Vector2i(1280,720)
	await settings_controls()
	await lineup_information()
	await pointer_stacking()
	await full_book_reward()
	await scrolling_collections()
	if is_instance_valid(map): map.queue_free()
	await process_frame
	session.save_file_path=original_save
	for suffix in ["",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path+suffix))
	print("KEYBOARD_MODAL_CONTROLS: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
