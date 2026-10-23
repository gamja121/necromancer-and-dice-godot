extends SceneTree
## Owning inventory inspection is presentation only. Never use/spend a card.
const Inventory=preload("res://systems/inventory_panel.gd")
const DiceControl=preload("res://systems/dice_control.gd")
const Catalog=preload("res://systems/reward_catalog.gd")
var passed: int=0
var failed: int=0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS inventory-inspection: ",label)
	else:
		failed+=1
		printerr("FAIL inventory-inspection: ",label)

func wait_idle(view: Control) -> bool:
	var started=Time.get_ticks_msec()
	while view.changing and Time.get_ticks_msec()-started<18000:
		await process_frame
	return not view.changing

func check_shadow_feedback(card: TextureButton, kind: String) -> void:
	var shadow=card.get_node_or_null("CardContactShadow") as TextureRect
	check(shadow!=null,kind+": contact shadow exists on the real owned card")
	if shadow==null: return
	var home: Vector2=card.position
	var angle: float=card.rotation
	var scale_before: Vector2=card.scale
	card.mouse_entered.emit()
	await create_timer(0.2).timeout
	check(shadow.position.is_equal_approx(Vector2(5,10)) and is_equal_approx(shadow.modulate.a,0.20),kind+": first pointer entry lifts the shadow")
	# Interrupt an unfinished return with another entry and a focus exit.
	card.mouse_exited.emit()
	card.mouse_entered.emit()
	card.focus_exited.emit()
	await create_timer(0.2).timeout
	check(shadow.position.is_equal_approx(Vector2(3,5)) and is_equal_approx(shadow.modulate.a,0.31),kind+": rapid pointer and focus changes settle at the latest target")
	card.focus_entered.emit()
	await create_timer(0.2).timeout
	var focus_raised: bool=shadow.position.is_equal_approx(Vector2(5,10)) and is_equal_approx(shadow.modulate.a,0.20)
	card.focus_exited.emit()
	await create_timer(0.2).timeout
	check(focus_raised and shadow.position.is_equal_approx(Vector2(3,5)) and is_equal_approx(shadow.modulate.a,0.31) and card.position.is_equal_approx(home) and is_equal_approx(card.rotation,angle) and card.scale.is_equal_approx(scale_before),kind+": keyboard focus returns shadow and card to their original pose")

func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	if session==null:
		check(false,"RunSession autoload is present")
		quit(1)
		return
	var original: String=session.save_file_path
	var disposable: String="user://inventory_inspection_%d.json" % OS.get_process_id()
	session.save_file_path=disposable
	session.start_new_world()
	var die: Dictionary=session.create_item("dice",Catalog.dice_cards()[2])
	session.world.dice_cards.append(die)
	check(session.save_world(),"disposable inventory fixture saves")
	var before: String=JSON.stringify(session.world.snapshot())
	var prior_rng: int=session.world.rng.state
	var view=Inventory.new()
	root.add_child(view)
	view.setup(session,"dice")
	check(await wait_idle(view),"inventory die card entrance finishes")
	check(view.content.get_node_or_null("InventoryInspect_dice_0")!=null,"dice card exposes a real tap target")
	var dice_button=view.content.get_node_or_null("InventoryInspect_dice_0") as TextureButton
	check(dice_button!=null and dice_button.texture_normal!=null,"same owned die card art remains visible")
	if dice_button!=null:
		await check_shadow_feedback(dice_button,"dice")
		dice_button.pressed.emit()
		check(is_instance_valid(view.info) and view.info.name=="InventoryCardDetail","tapping die opens a card detail instead of consuming it")
		if is_instance_valid(view.info):
			var detail=view.info.get_node_or_null("InventoryDetailPanel/InventoryDetailEffects") as Label
			var title=view.info.get_node_or_null("InventoryDetailPanel/InventoryDetailTitle") as Label
			var close_button=view.info.get_node_or_null("InventoryDetailPanel/InventoryDetailClose") as Button
			check(detail!=null and detail.text.contains(DiceControl.description(str(die.card_id))),"die detail reads the canonical dice effect description")
			check(title!=null and title.text.contains(str(die.label)),"die detail identifies the correct owned card")
			check(close_button!=null and close_button.size.x>=48,"mobile close control is a large real button")
			check(detail!=null and detail.text.contains("사용하거나 소모하지 않습니다"),"detail explicitly explains no card consumption")
			var was_closed: Array[bool]=[]
			view.closed.connect(func(): was_closed.append(true))
			close_button.pressed.emit()
			check(not is_instance_valid(view.info) and was_closed.is_empty(),"close detail returns to inventory without closing the book")
	check(await wait_idle(view),"inventory available after die detail")
	check(view.tab_buttons.size()==2,"only monster and dice tabs are available")
	view.show_kind("brand")
	check(view.content.get_node_or_null("InventoryInspect_brand_0")==null,"retired brand tab cannot be entered")
	view.show_kind("unit")
	check(await wait_idle(view),"original monster hand still opens")
	var roster_button=view.content.get_node_or_null("InventoryInspect_unit_0") as TextureButton
	check(roster_button!=null and roster_button.has_node("LayeredCardBase") and roster_button.texture_normal==null,"live layered inventory monster cards remain clickable")
	if roster_button!=null:
		await check_shadow_feedback(roster_button,"unit")
		roster_button.pressed.emit()
		check(is_instance_valid(view.info) and view.info.get_script().resource_path.ends_with("unit_info.gd"),"owned monsters retain original detailed unit window")
		view.info.queue_free()
		view.info=null
	check(before==JSON.stringify(session.world.snapshot()),"all inspection and navigation leave full saved world unchanged")
	check(prior_rng==session.world.rng.state,"inspection never consumes RNG or causes a card effect")
	view.queue_free()
	await process_frame
	session.reload_world()
	check(JSON.stringify(session.world.snapshot())==before,"reloaded inventory matches original unused cards")
	session.save_file_path=original
	for suffix in ["",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(disposable+suffix))
	print("INVENTORY_TOUCH_INSPECTION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
