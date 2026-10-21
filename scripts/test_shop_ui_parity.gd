extends SceneTree
const ShopUI=preload("res://systems/place_actions.gd")
const MapScene=preload("res://map.tscn")
var passed=0
var failed=0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS shop-ui-parity: ",label)
	else:
		failed+=1
		printerr("FAIL shop-ui-parity: ",label)
func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	if session==null:
		check(false,"RunSession autoload exists")
		quit(1)
		return
	var original_path: String=session.save_file_path
	var path="user://shop_ui_stage2_%d.json" % OS.get_process_id()
	session.save_file_path=path
	session.start_new_world()
	var map: Control=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	var shop=ShopUI.new()
	map.add_child(shop)
	shop.setup(map,8)
	await process_frame
	check(ResourceLoader.exists(ShopUI.SHOP_COUNTER_PATH),"original counter imported and recognized")
	check(is_instance_valid(shop.shop_counter) and shop.shop_counter.texture!=null,"original image displayed")
	check(shop.shop_counter.position.distance_to(ShopUI.SHOP_STAGE.position)<1,"counter geometry matches source")
	check(shop.donor_art.position.x>275 and shop.donor_art.position.x<500,"donor card in left trading slot")
	check(shop.offer_area is HBoxContainer and shop.shop_offer_scroll!=null,"offer horizontal scroll implemented")
	check(shop.close_button.position.x<1045 and shop.close_button.position.y<100,"original upper-right close button position")
	check(not shop.shop_cancel_button.visible,"cancel hidden before selecting donor")
	check(is_instance_valid(shop.shop_confirm_button) and shop.shop_confirm_button.disabled,"explicit trade button is initially disabled")
	var sample: Dictionary={"kind":"unit","item":session.world.roster[0]}
	for count in [3,4,5]:
		shop.offers=[]
		for i in range(count): shop.offers.append(sample.duplicate(true))
		shop.render_offers()
		await process_frame
		check(shop.offer_options.size()==count and shop.offer_area.get_child_count()==count,"offer count %d in one row" % count)
		if count==5:
			check(shop.shop_offer_scroll.get_h_scroll_bar().max_value>shop.shop_offer_scroll.size.x,"five cards scroll horizontally")
	shop.reset_shop_selection()
	check(shop.offers.is_empty() and shop.chosen==-1 and shop.shop_confirm_button.disabled,"cancel leaves no pending selection")
	var donor: String=str(session.world.roster[0].id)
	shop.select_unit(donor)
	check(shop.offers.size()>=3 and shop.shop_confirm_button.disabled,"real donor opens offers but does not enable trade")
	var before_roster: int=session.world.roster.size()
	var before_receipts: int=session.world.reward_receipts.size()
	check(shop.offers.all(func(offer): return offer.kind in ["unit","dice"]),"real shop shows no brand-card offers")
	check(shop.offers[1].kind=="unit","normal-grade merchant replaces its former brand slot with a monster")
	var offered_id: String=str(shop.offers[1].item.id)
	shop.choose_offer(1)
	check(shop.chosen==1 and not shop.shop_confirm_button.disabled,"choosing one valid monster offer enables explicit confirmation")
	shop.choose_offer(1)
	check(session.world.roster.size()==before_roster and session.world.reward_receipts.size()==before_receipts,"repeated offer tap never consumes a monster")
	shop.shop_confirm_button.pressed.emit()
	check(session.world.roster.size()==before_roster and session.world.roster.any(func(unit): return str(unit.id)==offered_id) and not session.world.roster.any(func(unit): return str(unit.id)==donor),"one explicit trade replaces donor with exactly one offered monster")
	check(session.world.reward_receipts.size()==before_receipts,"shop preserves existing exchange rules without inventing a per-visit receipt")
	check(not session.world.shop_trade.offers.has(donor),"traded donor's offers cannot be reused")
	check(shop.shop_confirm_button.disabled and shop.chosen==-1,"completed trade resets the confirmation state")
	shop.queue_free()
	await process_frame
	for kind in ["altar","fortune-teller-camp"]:
		session.world.tiles[8]=kind
		var other=ShopUI.new()
		map.add_child(other)
		other.setup(map,8)
		check(other.shop_counter==null and other.shop_offer_scroll==null,"existing %s interface untouched" % kind)
		other.queue_free()
		await process_frame
	map.queue_free()
	await process_frame
	session.save_file_path=original_path
	for suffix in ["",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("SHOP_UI_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
