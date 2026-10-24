extends SceneTree
## Real 1280×720 Godot map + actual graveyard action; source artwork and the
## existing dice-control card are captured (no synthetic illustration).
const MapScene=preload("res://map.tscn")
const SessionScript=preload("res://systems/run_session.gd")
const Catalog=preload("res://systems/reward_catalog.gd")
var passed: int=0
var failed: int=0

func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS grave-parchment: ",label)
	else:
		failed+=1
		printerr("FAIL grave-parchment: ",label)

func _initialize() -> void:
	call_deferred("_run")

func capture(name: String) -> void:
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image=root.get_texture().get_image()
	check(not img.is_empty() and img.get_size()==Vector2i(1280,720),"actual viewport is rendered at 1280x720 "+name)
	if img.is_empty() or img.get_size()!=Vector2i(1280,720): return
	var path: String=ProjectSettings.globalize_path("res://graveyard_parchment_%s.webp" % name)
	var err: Error=img.save_webp(path,false,0.87)
	check(err==OK and FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path).size()>40000,"real screenshot saved "+name)

func _run() -> void:
	root.size=Vector2i(1280,720)
	var session=root.get_node_or_null("RunSession")
	var own: bool=session==null
	if own:
		session=SessionScript.new()
		session.name="RunSession"
		root.add_child(session)
	var original: String=session.save_file_path
	var isolated: String="user://grave_parchment_capture_%d.json" % OS.get_process_id()
	session.save_file_path=isolated
	session.start_new_world()
	session.world.lap_ready=true
	session.world.leave_home()
	var index: int=session.world.tiles.find("graveyard")
	check(index>=0,"first-lap cemetery exists")
	if index<0: quit(1); return
	session.world.position=index
	check(session.save_world(),"temporary graveyard game state saved")
	var map: Control=MapScene.instantiate()
	root.add_child(map)
	await process_frame
	map.show_place_actions(index)
	var panel: Control=map.overlay
	check(is_instance_valid(panel) and panel.type=="graveyard","live cemetery exploration actions loaded")
	check(panel.get_node_or_null("LocationSceneImage")!=null,"original cemetery painting and shared frame remain")
	check(panel.content.get_node_or_null("GraveyardDigFrame")==null,"old large rectangular box is removed")
	var scroll: TextureRect=panel.content.get_node_or_null("GraveyardNoticeStrip")
	check(scroll!=null and scroll.texture.resource_path=="res://assets/map/ui/fortune_parchment_strip.webp","actual fortune-teller hand-drawn parchment is reused")
	check(scroll!=null and scroll.mouse_filter==Control.MOUSE_FILTER_IGNORE,"parchment cannot steal clicks")
	var text: Label=panel.content.get_node_or_null("GraveyardNoticeText")
	check(text!=null and text.text=="묘지를 파헤쳐 보세요","small parchment shows simple dig guidance")
	check(panel.action_button!=null and not panel.action_button.disabled,"original dig action stays available")
	await create_timer(0.35).timeout
	await capture("01_before")
	panel.action_button.pressed.emit()
	await process_frame
	check(not panel.graveyard_result.is_empty() and panel.graveyard_result.has("image"),"digging produces a real dice-control prize")
	text=panel.content.get_node_or_null("GraveyardNoticeText")
	check(text!=null and text.text=="카드를 찾았다","exact approved message shown on parchment after discovery")
	var prize: TextureButton=panel.content.get_node_or_null("GraveyardFoundDiceCard")
	check(prize!=null and prize.texture_normal!=null,"actual saved dice-control card artwork is visible")
	var visible_caption: bool=false
	if prize!=null:
		for child in prize.get_children():
			if child is Label and child.visible: visible_caption=true
	check(prize!=null and not visible_caption,"no extra floating card caption over parchment")
	check(panel.content.get_node_or_null("GraveyardDigConfirm")==null,"no second dig button behind awarded card")
	check(session.world.dice_cards.size()==1 and session.place_visit_id("grave-extract",index) in session.world.reward_receipts,"real card acquisition and one-visit receipt persist")
	await create_timer(0.35).timeout
	await capture("02_found")
	var item_id: String=str(session.world.dice_cards[0].id)
	map.queue_free()
	await process_frame
	session.reload_world()
	check(session.world.dice_cards.size()==1 and str(session.world.dice_cards[0].id)==item_id,"found control card persists after reload")
	session.save_file_path=original
	if own: session.queue_free()
	for ext in ["",".tmp"]:
		if FileAccess.file_exists(isolated+ext):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(isolated+ext))
	check(not FileAccess.file_exists(isolated),"no preview save remains")
	print("GRAVEYARD_PARCHMENT_UI: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
