extends SceneTree
## The approved undecorated-at-center framed panel hosts up to ten REAL
## layered monster cards in a fixed five-column, two-row click grid.
## Run: godot --headless --path . --script res://scripts/test_home_inheritance_roster_grid.gd
const Scene = preload("res://systems/home_inheritance.gd")
const Session = preload("res://systems/run_session.gd")
const FRAME = "res://assets/map/ui/inheritance_roster_frame.webp"
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS inheritance-grid: ",label)
	else:
		failed += 1
		printerr("FAIL inheritance-grid: ",label)

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	var created: bool = session == null
	if created:
		session = Session.new()
		session.name = "RunSession"
		root.add_child(session)
	var previous_path: String = session.save_file_path
	var scratch: String = "user://inheritance_grid_%d.json" % OS.get_process_id()
	session.save_file_path = scratch
	session.start_new_world()
	var slugs := ["goblin-commoner","goblin-soldier","goblin-rider","corpse-slime","soul-reaper","crystal-devourer","spiderling","yeti"]
	for slug in slugs:
		check(session.world.definitions.has(slug),"fixture has the approved monster "+slug)
		if session.world.definitions.has(slug):
			session.world.roster.append(session.create_item("unit",{"slug":slug}))
	check(session.world.roster.size()==10,"fixture fills the actual ten-monster capacity")
	# Real inheritance preview, button and click behavior remain untouched.
	session.world.roster[0].brands=[{"type":"guard","bless":[2],"curse":[]}]
	session.world.roster[1].brands=[{"type":"critical","bless":[3],"curse":[]}]
	check(ResourceLoader.exists(FRAME),"approved transparent panel is packaged")
	var scene := Scene.new()
	root.add_child(scene)
	scene.setup(session)
	await create_timer(0.5).timeout
	var frame := scene.hand.get_node_or_null("InheritanceRosterFrame") as TextureRect
	check(frame!=null and frame.texture!=null,"real unlettered background renders behind selectable cards")
	if frame!=null and frame.texture!=null:
		var img := frame.texture.get_image()
		check(img!=null and not img.is_empty(),"WebP decodes through the Godot renderer")
		if img!=null and not img.is_empty():
			check(img.get_pixel(0,0).a<0.2,"background beyond decorative corners is transparent")
			check(img.get_pixel(img.get_width()/2,img.get_height()/2).a>0.9,"one continuous inside surface stays opaque")
	var label := scene.hand.get_node_or_null("InheritanceRosterCount") as Label
	check(label!=null and label.text=="보유 마물 (10/10)","capacity caption is dynamic UI text, not burned into the artwork")
	check(scene.unit_hand_scroll!=null and scene.unit_hand_scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED and scene.unit_hand_scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"neither horizontal nor vertical scrolling is required at ten")
	var grid := scene.unit_hand_scroll.get_node_or_null("InheritanceRosterGrid") as GridContainer
	check(grid!=null and grid.columns==5 and grid.get_child_count()==10,"five-by-two roster always holds ten cards without slot borders")
	check(scene.unit_options.size()==10,"every distinct monster is individually selectable")
	if grid!=null:
		var first_row_y := -1.0
		var second_row_y := -1.0
		var inside := true
		var layers := true
		for i in range(10):
			var slot := grid.get_child(i) as Control
			var option := slot.get_node_or_null("InheritanceRosterCard_%d" % i) as TextureButton
			if option==null:
				inside=false
				layers=false
				continue
			layers=layers and option.has_node("LayeredCardBase") and option.has_node("LayeredCardCharacter") and option.get_child(0) is Label and not option.get_child(0).visible
			var rect := option.get_global_rect()
			inside=inside and rect.position.x>=238 and rect.end.x<=1240 and rect.position.y>=468 and rect.end.y<=710
			if i==0: first_row_y=rect.position.y
			if i==5: second_row_y=rect.position.y
		check(inside,"all ten actual clickable card rectangles fit within the frame and 720p viewport")
		check(layers,"every thumbnail uses the approved live layered card and no duplicated caption")
		check(second_row_y>first_row_y+90,"sixth card starts the second row, not a horizontal scroller")
	var donor_id := str(session.world.roster[0].id)
	var recipient_id := str(session.world.roster[1].id)
	(scene.unit_options[donor_id] as TextureButton).pressed.emit()
	(scene.unit_options[recipient_id] as TextureButton).pressed.emit()
	check(scene.material_id==donor_id and scene.receiver_id==recipient_id and not scene.confirm_button.disabled,"real grid buttons still select donor and valid receiver")
	check(scene.material_art.has_node("LayeredCardPreview") and scene.receiver_art.has_node("LayeredCardPreview"),"donor and recipient previews stay layered")
	# A short roster (or post-sacrifice hand) must redraw its live count.
	scene.material_id=""
	scene.receiver_id=""
	session.world.roster.resize(2)
	scene.render_hand()
	var short_label := scene.hand.get_node_or_null("InheritanceRosterCount") as Label
	var short_grid := scene.unit_hand_scroll.get_node_or_null("InheritanceRosterGrid") as GridContainer
	check(short_label!=null and short_label.text=="보유 마물 (2/10)" and short_grid!=null and short_grid.get_child_count()==2,"remaining monsters and capacity count refresh after a consumed card")
	scene.queue_free()
	await process_frame
	for extension in ["",".tmp"]:
		if FileAccess.file_exists(scratch+extension):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+extension))
	session.save_file_path=previous_path
	if created: session.queue_free()
	print("INHERITANCE_ROSTER_GRID: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
