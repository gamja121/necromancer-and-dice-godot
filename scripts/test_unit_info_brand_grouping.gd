extends SceneTree
## UI-only regression: three marks fit inside the original small info panel,
## repeating one effect merges its dice faces, and duplicate eyes keep ×N.
const UnitInfo=preload("res://systems/unit_info.gd")
const Rules=preload("res://systems/battlefield_rules.gd")
var passed: int=0
var failed: int=0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, name: String) -> void:
	if value:
		passed+=1
		print("PASS unit-brand-stack: ",name)
	else:
		failed+=1
		printerr("FAIL unit-brand-stack: ",name)

func effect_rows(panel: Control) -> Array[String]:
	var texts: Array[String]=[]
	var queue: Array=panel.effects.get_children()
	while not queue.is_empty():
		var child: Node=queue.pop_front()
		if child is Label: texts.append(child.text)
		queue.append_array(child.get_children())
	return texts

func show_unit(unit: Dictionary, battle) -> Control:
	var panel=UnitInfo.new()
	root.add_child(panel)
	panel.setup(unit,battle)
	return panel

func _run() -> void:
	var defs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	var battle=Rules.new(defs,123)
	var ally=battle.individual("ice-lord","brand-test-ally")
	var enemy=battle.individual("skeleton-spear","brand-test-enemy")
	ally.brands=[
		{"type":"freeze","bless":[1,4],"curse":[2]},
		{"type":"freeze","bless":[3,4],"curse":[2]},
		{"type":"freeze","bless":[4,6],"curse":[5]}
	]
	battle.start([ally],[enemy])
	var unit: Dictionary=battle.find_id("brand-test-ally")
	var before: String=JSON.stringify(battle.snapshot())
	var panel: Control=show_unit(unit,battle)
	await process_frame
	var left=panel.get_node_or_null("UnitInfoPortraitPanel") as Control
	check(left!=null,"original illustrated unit information frame remains")
	if left==null:
		quit(1)
		return
	var icons: Array=[]
	var labels: Array=[]
	for node in left.get_children():
		if node is TextureRect and node.has_meta("brand_slot"): icons.append(node)
		if node is Label and str(node.name).begins_with("BrandInfoName"): labels.append(node)
	check(icons.size()==3 and labels.size()==3,"all three actual independent brand marks and names remain")
	check(icons.size()==3 and icons[0].get_meta("brand_slot",-1)==0 and icons[2].get_meta("brand_slot",-1)==2,"brand ordering is not changed")
	var all_inside: bool=true
	var no_overlap: bool=true
	for i in range(icons.size()):
		var icon: TextureRect=icons[i]
		all_inside=all_inside and icon.position.y>=352.0 and icon.position.y+icon.size.y<=510.0
		all_inside=all_inside and icon.position.y+icon.size.y <= left.size.y-52.0
		all_inside=all_inside and labels[i].position.y==icon.position.y and labels[i].position.y+labels[i].size.y<=510.0
		if i>0: no_overlap=no_overlap and icons[i-1].position.y+icons[i-1].size.y<icon.position.y
	check(all_inside,"even the third original brand icon and text fit within the printed inner frame")
	check(no_overlap,"three icons and label rows do not overlap")
	var text_rows: Array[String]=effect_rows(panel)
	check(text_rows.count("빙결")==1,"repeated identical effect appears as just one readable row")
	check(text_rows.count("1, 3, 4×3, 6")==1,"blessing faces merge into one column; face 4 remains ×3")
	check(text_rows.count("2×2, 5")==1 and text_rows.count("저주")==1,"curse is headed only once and keeps overlapping face 2")
	check(battle.resolve_brand_face(unit.brands,4).bless.get("freeze",0)==3,"combat still stacks all 3 freeze effects on the same blessed face")
	check(battle.resolve_brand_face(unit.brands,2).curse.get("freeze",0)==2,"combat still stacks overlapping cursed faces")
	check(before==JSON.stringify(battle.snapshot()),"unit information presentation leaves battle rules and saved state untouched")
	panel.queue_free()
	await process_frame
	var alternate: Dictionary=unit.duplicate(true)
	alternate.brands=[
		{"type":"freeze","bless":[1],"curse":[2]},
		{"type":"critical","bless":[6],"curse":[5]},
		{"type":"freeze","bless":[4],"curse":[3]}
	]
	var other: Control=show_unit(alternate,battle)
	await process_frame
	var other_rows: Array[String]=effect_rows(other)
	check(other_rows.count("빙결")==1,"non-adjacent repeated marks still merge into a single row")
	check(other_rows.count("1, 4")==1,"non-adjacent freeze faces also merge in numeric order")
	var effects: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/interface.json")).brands
	check(other_rows.count(str(effects.critical.name).replace("의 낙인",""))==1,"different brand types remain separately readable")
	other.queue_free()
	await process_frame
	var empty: Dictionary=unit.duplicate(true)
	empty.brands=[]
	var minimal: Control=show_unit(empty,battle)
	await process_frame
	check(effect_rows(minimal).count("낙인 없음")==0,"no-mark messages no longer take space when other active effects exist")
	minimal.queue_free()
	await process_frame
	print("UNIT_BRAND_STACK_AND_GROUP: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
