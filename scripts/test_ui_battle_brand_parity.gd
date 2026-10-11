extends SceneTree
## Stage5A – fixed HTML brand-reference grid vs native Godot battle rules.
const BrandReference=preload("res://systems/brand_reference.gd")
const Rules=preload("res://systems/battlefield_rules.gd")
var passed=0
var failed=0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS ui-brand-reference: ",label)
	else:
		failed+=1
		printerr("FAIL ui-brand-reference: ",label)

func _run() -> void:
	var definitions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	var rules=Rules.new(definitions,101)
	var allies: Array=[]
	var enemies: Array=[]
	for i in range(4):
		allies.append(rules.individual("skeleton-spear","ally-%d" % i))
		enemies.append(rules.individual("goblin-rider","enemy-%d" % i))
	# Curse 3 on base brand must cancel any inherited blessing on 3.
	var innate: String=str(definitions["skeleton-spear"].brands[0])
	allies[0].brands=[{"type":innate,"bless":[2],"curse":[3]},{"type":"guard","bless":[3,4],"curse":[]}]
	rules.start(allies,enemies)
	var before: String=JSON.stringify(rules.snapshot())
	var panel=BrandReference.new()
	root.add_child(panel)
	panel.setup(rules)
	await process_frame
	check(panel.frame_art!=null and panel.frame_art.texture!=null,"original parchment-frame art remains rendered")
	check(panel.frame_art.position==Vector2(116,77) and panel.frame_art.size==Vector2(1048,566),"frame is centered at fixed web proportions")
	check(panel.dice_headers.size()==6 and panel.dice_headers.all(func(d): return d.texture!=null),"six actual result-dice images replace numbers")
	for i in range(6):
		check(panel.dice_headers[i].get_parent().name=="DiceFace%02d" % (i+1),"die %d keeps stable source face order" % (i+1))
	check(panel.reference_rows.size()==8 and panel.face_cells.size()==8,"four allied and four enemy units displayed simultaneously")
	check(panel.reference_rows.slice(0,4).all(func(row): return row.get_meta("team")=="ally"),"ally units in top four rows")
	check(panel.reference_rows.slice(4,8).all(func(row): return row.get_meta("team")=="enemy"),"enemy units in lower four rows")
	check(panel.face_cells.all(func(row): return row.size()==6),"all 8 rows have all six dice faces")
	check(panel.face_cells[0][1].get_meta("mode")=="blessing","2 shows blessing for selected ally")
	check(panel.face_cells[0][2].get_meta("mode")=="curse","3 shows base curse instead of inherited blessing")
	check(panel.face_cells[0][3].get_meta("mode")=="blessing","4 shows inherited blessing on safe face")
	check(panel.face_cells[0][0].disabled,"inactive face cannot be mistaken for a blessing")
	panel.face_cells[0][2].pressed.emit()
	check(panel.summary.text.contains("☠") and panel.summary.text.contains("3번"),"tapping a curse displays real penalty and selected face")
	panel.reference_rows[0].get_child(0).pressed.emit()
	check(panel.summary.text.contains("축복 [") and panel.summary.text.contains("저주 ["),"tapping unit reveals full brand list")
	check(before==JSON.stringify(rules.snapshot()),"opening and using reference never mutates RNG, roster or battle state")
	check(panel.reference_scroll.size.x>=930 and panel.reference_grid.get_child_count()==9,"source seven-column grid has room for 8 units plus dice header")
	panel.queue_free()
	await process_frame
	# Empty brand slots and living/summoned filtering should never invent icons.
	var minimal=Rules.new(definitions,102)
	var no_marks=minimal.individual("skeleton-spear","blank-ally")
	no_marks.brands=[]
	var only_enemy=minimal.individual("goblin-rider","blank-enemy")
	only_enemy.brands=[]
	minimal.start([no_marks],[only_enemy])
	var other=BrandReference.new()
	root.add_child(other)
	other.setup(minimal)
	await process_frame
	check(other.reference_rows.size()==2 and other.face_cells.size()==2,"small party scales to actual living roster")
	check(other.face_cells[0].all(func(cell): return cell.disabled and cell.text.is_empty()),"empty brands produce no active icons")
	other.queue_free()
	await process_frame
	print("UI_BATTLE_BRAND_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
