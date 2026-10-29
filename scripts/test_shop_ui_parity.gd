extends "res://scripts/test_fortune_direct_flow.gd"
const ShopUI=preload("res://systems/place_actions.gd")
const Visual=preload("res://systems/shop_window_visual.gd")

func inside(control:Control,rect:Rect2) -> bool:
	return rect.encloses(Rect2(control.global_position,control.size))

func run() -> void:
	session=root.get_node("RunSession")
	var original_path:String=session.save_file_path
	save="user://shop_window_ui_%d.json" % OS.get_process_id()
	paths.append(save)
	session.save_file_path=save
	session.start_new_world()
	var index:int=session.world.tiles.find("village")
	session.world.position=index
	var map:Control=await new_map()
	var shop=ShopUI.new()
	map.add_child(shop)
	shop.setup(map,index)
	for frame in range(4): await process_frame
	check(shop.shop_window.texture!=null and shop.shop_window.texture is AtlasTexture,"painted blank window frame renders through native texture")
	var window:Rect2=Visual.FRAME_RECT
	for control in [shop.donor_art,shop.shop_offer_scroll,shop.shop_summary,shop.shop_remaining,shop.status,shop.close_button,shop.shop_confirm_button]:
		check(inside(control,window),"shop content stays inside frame: "+str(control.name))
	check(shop.offer_area is HBoxContainer and shop.shop_offer_scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"three offers have a complete visible row without horizontal scrolling")
	check(shop.close_button.position.y==shop.shop_confirm_button.position.y and shop.close_button.position.y>620,"exit and confirmation share fixed bottom row")
	check(not shop.shop_cancel_button.visible and shop.shop_confirm_button.disabled and shop.shop_empty_hint.visible,"initial selection instructions and disabled confirmation")
	check(shop.shop_remaining.text=="남은 거래 3 / 3","initial counter uses live allowance")
	var donor:String=str(session.world.roster[0].id)
	shop.select_unit(donor)
	for frame in range(4): await process_frame
	check(shop.offers.size()==3 and shop.offer_options.size()==3,"real donor reveals exactly three proposals")
	check(not shop.shop_empty_hint.visible and shop.shop_cancel_button.visible and shop.shop_confirm_button.disabled,"donor selection waits for product choice")
	for option in shop.offer_options:
		check(inside(option,Rect2(shop.shop_offer_scroll.global_position,shop.shop_offer_scroll.size)),"each complete card fits the visible offer area")
		check(option.modulate==Color.WHITE,"valid unselected card keeps its original color")
	var cached:Array=shop.offers.duplicate(true)
	shop.reset_shop_selection()
	shop.select_unit(donor)
	check(shop.offers==cached and session.shop_trades_remaining(index)==3,"reset/reselect never rerolls or spends allowance")
	shop.choose_offer(1)
	var before:Dictionary=session.world.snapshot().duplicate(true)
	shop.choose_offer(1)
	check(session.world.snapshot()==before and not shop.shop_confirm_button.disabled,"repeated offer tap does not trade")
	check(shop.shop_summary.text.contains("→") and not shop.shop_summary.text.contains("\n"),"pending exchange has a compact single-line summary")
	var offered_id:String=str(shop.offers[1].item.id)
	shop.shop_confirm_button.pressed.emit()
	check(session.owned_unit(donor).is_empty() and not session.owned_unit(offered_id).is_empty(),"explicit confirmation exchanges exactly the offered monster")
	check(session.shop_trades_remaining(index)==2 and shop.shop_remaining.text=="남은 거래 2 / 3","successful trade updates saved and visible allowance")
	check(shop.shop_confirm_button.disabled and shop.chosen==-1 and shop.shop_empty_hint.visible,"successful trade clears pending state")
	shop.queue_free()
	await process_frame
	shop=ShopUI.new()
	map.add_child(shop)
	shop.setup(map,index)
	check(shop.shop_remaining.text=="남은 거래 2 / 3","reopening preserves allowance")
	shop.queue_free()
	await process_frame
	for kind in ["altar","fortune-teller-camp"]:
		session.world.tiles[index]=kind
		var other=ShopUI.new()
		map.add_child(other)
		other.setup(map,index)
		check(other.shop_window==null and other.shop_offer_scroll==null,"existing %s interface does not receive shop window" % kind)
		other.queue_free()
		await process_frame
	await dispose(map)
	var audio:Node=root.get_node_or_null("GameAudio")
	var audio_ref:WeakRef=weakref(audio) if audio!=null else null
	if audio!=null: audio.queue_free()
	check(await until(func(): return audio_ref==null or audio_ref.get_ref()==null),"audio decoder drains")
	session.world=null
	session.save_file_path=original_path
	for path in paths:
		for suffix in ["",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("SHOP_UI_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
