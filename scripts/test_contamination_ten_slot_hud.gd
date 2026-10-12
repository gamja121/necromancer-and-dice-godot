extends SceneTree
## User-selected 10-slot frame, real binary artwork, map wiring, no-save side effects.
const HUD = preload("res://systems/contamination_hud.gd")
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const ART_PATH = "res://assets/map/ui/contamination_crow_tile_10.webp"
var passed: int = 0
var failed: int = 0

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS contamination-10-slot: ",message)
	else:
		failed += 1
		printerr("FAIL contamination-10-slot: ",message)

func verify(hud: Control, value: int, full: int, part: float) -> void:
	hud.set_value(value,true)
	var fractions: PackedFloat32Array = hud.segment_fractions(hud.display_value)
	check(fractions.size() == 10,"%d: exactly 10 drawn logical cells" % value)
	check(is_equal_approx(hud.target_value,float(value)) and is_equal_approx(hud.display_value,float(value)),
		"%d: exact displayed numerical percentage" % value)
	for i in range(10):
		var expected: float = 1.0 if i < full else (part if i == full else 0.0)
		check(absf(fractions[i]-expected)<0.001,"%d: logical slot %d fill correct" % [value,i+1])

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(ResourceLoader.exists(ART_PATH),"user-selected high-resolution binary WebP exists in the shipped Godot assets")
	var image: Image = Image.load_from_file(ART_PATH)
	check(image!=null and not image.is_empty(),"actual WebP decodes as native Godot Image")
	if image!=null and not image.is_empty():
		check(image.get_width()==1152 and image.get_height()==384,"selected art imported at 1152x384, not the low-resolution old PNG")
		check(image.has_mipmaps()==false,"source UI can scale without accidental sampling of old art")
		check(image.get_pixel(371,212).a<0.1,"inner gauge window is truly transparent for animated effect underneath")
		check(image.get_pixel(371,164).a>0.75,"stone frame has opaque pixels above the window")
		check(image.get_pixel(0,0).a<0.1,"outside the painted art is transparent")
	var hud: Control = HUD.new()
	root.add_child(hud)
	await process_frame
	check(hud.uses_approved_art and hud.last_art_error.is_empty(),"production HUD actually loads new asset; fallback is not used")
	check(hud.frame!=null and hud.frame.get_width()==1152,"HUD holds exact new hi-res imported image")
	check(hud.size==Vector2(576,192) and hud.position==Vector2(352,379),
		"approved UI is naturally proportioned and centered inside the 1280x720 game board")
	check(hud.mouse_filter==Control.MOUSE_FILTER_IGNORE,"HUD decoration cannot swallow map movement or inventory clicks")
	check(hud.SLOT_X.size()==10 and hud.COLORS.size()==10,"ten measured alpha holes yield exactly 10 visual windows and 10 effect palettes")
	for i in range(10):
		check(hud.SLOT_X[i]+hud.SLOT_WIDTH<hud.SLOT_X[i+1] if i<9 else hud.SLOT_WIDTH>0,"window %d has positive usable width" % (i+1))
	verify(hud,0,0,0.0)
	verify(hud,1,0,0.1)
	verify(hud,9,0,0.9)
	verify(hud,10,1,0.0)
	verify(hud,12,1,0.2)
	verify(hud,50,5,0.0)
	verify(hud,99,9,0.9)
	verify(hud,100,10,0.0)
	hud.set_value(999,true)
	check(hud.display_value==100.0,"visual overflow clamps to 100/100")
	hud.set_value(-3,true)
	check(hud.display_value==0.0,"negative visual value clamps to 0/100")
	hud.set_value(72,true)
	hud.set_value(100,false)
	check(hud.display_value==72.0 and hud.target_value==100.0,"normal contamination rises over time, not with an instant jump")
	hud._process(0.04)
	check(hud.display_value>72.0 and hud.display_value<100.0,"partial frame of animated fill is correctly interpolated")
	hud._process(0.5)
	check(hud.display_value==100.0,"animation settles exactly at the saved target")
	hud.queue_free()
	await process_frame

	var session: Node = root.get_node_or_null("RunSession")
	var created: bool = session==null
	if created:
		session = SESSION.new()
		session.name = "RunSession"
		root.add_child(session)
	var previous_path: String = session.save_file_path
	var temp_path: String = "user://contamination_hud_%d.json" % OS.get_process_id()
	session.save_file_path = temp_path
	session.start_new_world()
	var map: Control = MAP.instantiate()
	root.add_child(map)
	await process_frame
	var gauge: Control = map.presentation.gauge
	check(gauge!=null and gauge.uses_approved_art,"live 24-tile Map uses approved image, not a test-only HUD")
	check(gauge.target_value==float(session.world.contamination),"map reads actual saved contamination value")
	var before: Dictionary = session.world.snapshot().duplicate(true)
	var rng_before: int = session.world.rng.state
	gauge.set_value(12,true)
	check(gauge.segment_fractions(12.0)[0]==1.0 and absf(gauge.segment_fractions(12.0)[1]-0.2)<0.001,
		"live map 12/100 fills one whole stage plus 20 percent of the next")
	check(session.world.snapshot()==before and session.world.rng.state==rng_before,
		"visual-only updates never change story, dice RNG, monster roster, contamination or save state")
	map.modal()
	check(not gauge.visible,"overlay and locations hide the whole new tall HUD as before")
	map.close_overlay()
	check(gauge.visible,"map HUD restores after closing location overlay")
	map.queue_free()
	await process_frame
	session.save_file_path = previous_path
	for suffix in ["",".tmp"]:
		var p: String = temp_path+suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if created: session.queue_free()
	print("CONTAMINATION_TEN_SLOT_HUD: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
