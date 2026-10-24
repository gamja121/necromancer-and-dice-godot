extends SceneTree
## Read-only screenshots of the CURRENT production UnitInfo popup.
## Instantiate the real UI and battle rules. Do not alter production UI/art.
const UI=preload("res://systems/unit_info.gd")
const Rules=preload("res://systems/battlefield_rules.gd")
var passed: int=0
var failed: int=0

func verify(test: bool, label: String) -> void:
	if test:
		passed+=1
		print("PASS unit-info-capture: ",label)
	else:
		failed+=1
		printerr("FAIL unit-info-capture: ",label)

func frame(label: String, panel: Control) -> void:
	await create_timer(0.50).timeout
	await RenderingServer.frame_post_draw
	var viewport_image: Image=root.get_texture().get_image()
	verify(not viewport_image.is_empty() and viewport_image.get_size()==Vector2i(1280,720),"real 1280x720 full view "+label)
	if viewport_image.is_empty(): return
	var output: String=ProjectSettings.globalize_path("res://unit_info_actual_%s.webp" % label)
	var status: Error=viewport_image.save_webp(output,false,0.94)
	verify(status==OK and FileAccess.get_file_as_bytes(output).size()>50000,"actual image captured "+label)
	var scroll: ScrollContainer=panel.get_node("UnitInfoEffectsPanel/EffectScroll")
	var content_height: float=panel.effects.get_combined_minimum_size().y
	print("UNIT_INFO_CAPTURE_METRIC: ",label," scroll=",scroll.scroll_vertical," viewport=",scroll.size.y," content=",content_height)
	var index: int=0
	for child in panel.effects.get_children():
		if child is Label:
			print("UNIT_INFO_ROW: ",label," row=",index," y=",roundi(child.position.y)," height=",roundi(child.size.y)," text=",str(child.text))
			index+=1

func show_real_info(battle, id: String) -> Control:
	var panel: Control=UI.new()
	root.add_child(panel)
	panel.setup(battle.find_id(id),battle)
	return panel

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1280,720)
	var definitions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	var battle=Rules.new(definitions,456)
	var ally=battle.individual("ice-lord","info-preview")
	var foe=battle.individual("skeleton-spear","preview-foe")
	ally.brands=[
		{"type":"freeze","bless":[1,4],"curse":[2]},
		{"type":"freeze","bless":[3,4],"curse":[2]},
		{"type":"freeze","bless":[4,6],"curse":[5]}
	]
	battle.start([ally],[foe])
	var baseline: String=JSON.stringify(battle.snapshot())
	var same: Control=show_real_info(battle,"info-preview")
	await frame("01_same_top",same)
	var same_scroll: ScrollContainer=same.get_node("UnitInfoEffectsPanel/EffectScroll")
	same_scroll.scroll_vertical=10000
	await frame("02_same_bottom",same)
	same.queue_free()
	await process_frame
	var mixed_battle=Rules.new(definitions,457)
	var mix=mixed_battle.individual("ice-lord","mixed-preview")
	mix.brands=[
		{"type":"freeze","bless":[1,4],"curse":[2]},
		{"type":"combo","bless":[3],"curse":[5]},
		{"type":"guard","bless":[2,6],"curse":[4]}
	]
	mixed_battle.start([mix],[foe])
	var mixed_baseline: String=JSON.stringify(mixed_battle.snapshot())
	var other: Control=show_real_info(mixed_battle,"mixed-preview")
	await frame("03_mixed_top",other)
	var mixed_scroll: ScrollContainer=other.get_node("UnitInfoEffectsPanel/EffectScroll")
	mixed_scroll.scroll_vertical=10000
	await frame("04_mixed_bottom",other)
	verify(JSON.stringify(battle.snapshot())==baseline and JSON.stringify(mixed_battle.snapshot())==mixed_baseline,"UI display changes never changed battle or saved state")
	other.queue_free()
	await process_frame
	print("UNIT_INFO_REAL_CAPTURE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
