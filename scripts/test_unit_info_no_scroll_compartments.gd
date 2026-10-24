extends SceneTree
## Live Godot screenshots + functional no-scroll regression for effect parchment.
const UnitInfo=preload("res://systems/unit_info.gd")
const Rules=preload("res://systems/battlefield_rules.gd")
var passed: int=0
var failed: int=0
var definitions: Dictionary

func _initialize() -> void: call_deferred("_run")

func check(ok: bool,label: String) -> void:
	if ok:
		passed+=1
		print("PASS no-scroll-info: ",label)
	else:
		failed+=1
		printerr("FAIL no-scroll-info: ",label)

func node_exists(panel: Control,name: String) -> bool:
	return panel.effects.get_node_or_null(name)!=null

func shown_rows(node: Node) -> Array[String]:
	var result: Array[String]=[]
	var queue: Array=[node]
	while not queue.is_empty():
		var n: Node=queue.pop_front()
		if n is Label: result.append(n.text)
		queue.append_array(n.get_children())
	return result

func open_panel(battle, id: String) -> Control:
	var panel: Control=UnitInfo.new()
	root.add_child(panel)
	panel.setup(battle.find_id(id),battle)
	return panel

func save_frame(tag: String,panel: Control) -> void:
	await create_timer(0.38).timeout
	await RenderingServer.frame_post_draw
	var bounds: Image=root.get_texture().get_image()
	check(not bounds.is_empty() and bounds.get_size()==Vector2i(1280,720),"real game viewport captured "+tag)
	if bounds.is_empty(): return
	var out: String=ProjectSettings.globalize_path("res://unit_info_no_scroll_%s.webp" % tag)
	var err: Error=bounds.save_webp(out,false,0.91)
	check(err==OK and FileAccess.get_file_as_bytes(out).size()>40000,"saved live Godot preview "+tag)

func verify_bounds(panel: Control,case_name: String) -> void:
	for i in range(8): await process_frame
	var container: VBoxContainer=panel.effects
	var right: Control=panel.get_node("UnitInfoEffectsPanel")
	var expected_height: float=UnitInfo.EFFECT_CONTENT_HEIGHT
	var actual_height: float=container.get_combined_minimum_size().y*container.scale.y
	check(right.position.y+right.size.y<660 and right.position.x+right.size.x<1240,case_name+" resized original paper stays inside the game surface")
	check(not right.get_children().any(func(n): return n is ScrollContainer),case_name+" has no scroll element or scrollbar")
	check(container.get_child_count()>0 and container.get_children().all(func(n): return n is HBoxContainer or n is VBoxContainer or n is GridContainer),case_name+" uses aligned label rows and major-section rules, never paper boxes")
	check(actual_height<=expected_height+1.0,case_name+" all effects fit in the painted panel without scrolling or clipping")
	check(container.size.x*container.scale.x<=UnitInfo.EFFECT_CONTENT_WIDTH+2.0,case_name+" effect columns use the parchment width without overflowing")
	check(container.scale.x>=0.55,case_name+" content remains legible within an extreme full-effects case")
	var original: NinePatchRect=right.get_node_or_null("OriginalEffectsParchment")
	check(original!=null and original.texture.resource_path=="res://assets/battle/ui/legion-info-window-hd.png",case_name+" preserves original hand-painted parchment")
	print("EFFECT_LAYOUT: ",case_name," count=",container.get_child_count()," height=",container.get_combined_minimum_size().y," scale=",container.scale.x)

func create_battle(all: bool=false) -> Dictionary:
	var rules=Rules.new(definitions,209)
	var ally=rules.individual("ice-lord","preview-ally")
	var enemy=rules.individual("skeleton-spear","preview-enemy")
	ally.passive="bone" if all else ""
	ally.brands=[
		{"type":"freeze","bless":[1,4],"curse":[2]},
		{"type":"combo","bless":[3],"curse":[5]},
		{"type":"guard","bless":[2,6],"curse":[4]}
	]
	rules.start([ally],[enemy])
	if all:
		var active: Array=definitions.get("unused_active",[])
		active=["skeleton","beast","corpse","plague","ice","summon","demon","plant","insect","element"]
		var counts: Dictionary={}
		for key in active: counts[key]=4
		rules.legions["ally"]["active"]=active
		rules.legions["ally"]["counts"]=counts
	return {"rules":rules,"ally":rules.find_id("preview-ally")}

func _run() -> void:
	root.size=Vector2i(1280,720)
	definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	var state: Dictionary=create_battle()
	var battle=state.rules
	var original: String=JSON.stringify(battle.snapshot())
	var panel: Control=open_panel(battle,"preview-ally")
	await verify_bounds(panel,"three different brands, no active legion/passive")
	check(not node_exists(panel,"ActiveLegionEffects"),"inactive legion and even its heading are absent")
	check(not node_exists(panel,"PassiveEffects"),"missing passive and its heading are absent")
	var left: Control=panel.get_node("UnitInfoPortraitPanel")
	check(not left.get_children().any(func(n): return n is Label and n.text=="패시브 없음"),"empty passive label also vanishes from the left portrait panel")
	check(node_exists(panel,"Brand_freeze") and node_exists(panel,"Brand_combo") and node_exists(panel,"Brand_guard"),"all three different brands have distinct aligned text rows")
	check(not panel.effects.get_children().any(func(c): return c is PanelContainer),"no boxed cards divide each mark")
	check(not shown_rows(panel.effects).any(func(v): return v=="낙인 없음"),"no unnecessary empty section")
	check(shown_rows(panel.effects).count("활성 군단 없음")==0,"old inactive-legion filler is removed")
	check(shown_rows(panel.effects).count("군단 활성은 전투 시작 시 고정")==0,"unnecessary repeated fixed-activation notice removed")
	await save_frame("01_marks_only",panel)
	check(JSON.stringify(battle.snapshot())==original,"opening the panel leaves battle state unchanged")
	panel.queue_free()
	await process_frame
	var second: Dictionary=create_battle(true)
	var all_rules=second.rules
	var state_before: String=JSON.stringify(all_rules.snapshot())
	var full: Control=UnitInfo.new()
	root.add_child(full)
	full.setup(all_rules.find_id("preview-ally"),all_rules,{"ally_hp":2,"ally_attack":1,"ally_speed":1})
	await verify_bounds(full,"ten activated legions + three brands + passive + prophecy")
	check(node_exists(full,"Passive_0") and node_exists(full,"ActiveLegionEffects") and node_exists(full,"ProphecyEffects"),"when present passive, active legion and prophecy stay in distinct readable sections")
	check(full.effects.get_child_count()>=6,"all different marks, bonuses and group headings remain visible")
	check(JSON.stringify(all_rules.snapshot())==state_before,"maximal screen does not modify combat mechanics")
	await save_frame("02_all_effects",full)
	full.queue_free()
	await process_frame
	var same: Dictionary=create_battle()
	var same_rules=same.rules
	var marks: Dictionary=same_rules.find_id("preview-ally")
	marks.brands=[
		{"type":"freeze","bless":[1,4],"curse":[2]},
		{"type":"freeze","bless":[3,4],"curse":[2]},
		{"type":"freeze","bless":[4,6],"curse":[5]}
	]
	var same_panel: Control=open_panel(same_rules,"preview-ally")
	await verify_bounds(same_panel,"three same brands grouped")
	check(node_exists(same_panel,"Brand_freeze") and not node_exists(same_panel,"Brand_combo"),"identical marks consolidate to one ledger row")
	check(shown_rows(same_panel.effects).any(func(v): return v=="1, 3, 4×3, 6"),"combined blessing face stacks are shown once in the aligned face column")
	await save_frame("03_same_mark",same_panel)
	same_panel.queue_free()
	await process_frame
	print("NO_SCROLL_EFFECT_COMPARTMENTS: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
