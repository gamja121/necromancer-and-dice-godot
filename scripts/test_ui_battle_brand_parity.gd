extends SceneTree
## Stage5A – fixed HTML brand-reference grid vs native Godot battle rules.
const BrandReference=preload("res://systems/brand_reference.gd")
const FateIcon=preload("res://systems/battle_fate_icon.gd")
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
	check(absf(panel.frame_art.position.x-116)<1 and absf(panel.frame_art.position.y-77)<=6.1 and panel.frame_art.size==Vector2(1048,506),"frame matches web size; entrance tween may temporarily offset 6px")
	check(panel.frame_art.texture.resource_path=="res://assets/map/ui/inheritance_info.webp","reference panel uses existing cleaned transparent parchment asset")
	check(panel.detail_scroll.size.y>=90 and panel.detail_popup!=null and not panel.detail_popup.visible,"effect description keeps readable multi-line space during entry tween")
	check(panel.summary.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART and panel.summary.custom_maximum_size.x==550,"description has a bounded width for reliable word wrapping")
	check(panel.reference_rows[0].get_child(0).custom_minimum_size.y==34,"compact rows preserve all eight monster rows")
	check(panel.dice_headers.size()==6 and panel.dice_headers.all(func(d): return d.texture!=null),"six actual result-dice images replace numbers")
	for i in range(6):
		check(panel.dice_headers[i].get_parent().name=="DiceFace%02d" % (i+1),"die %d keeps stable source face order" % (i+1))
	check(panel.reference_rows.size()==8 and panel.face_cells.size()==8,"four allied and four enemy units displayed simultaneously")
	check(panel.reference_rows.slice(0,4).all(func(row): return row.get_meta("team")=="ally"),"ally units in top four rows")
	check(panel.reference_rows.slice(4,8).all(func(row): return row.get_meta("team")=="enemy"),"enemy units in lower four rows")
	check(panel.face_cells.all(func(row): return row.size()==6),"all 8 rows have all six dice faces")
	check(panel.face_cells[0][1].get_meta("mode")=="blessing","2 shows blessing for selected ally")
	var blessing_icon=panel.face_cells[0][1].get_node_or_null("BrandFaceFateIcon")
	check(blessing_icon!=null and blessing_icon.get_script()==FateIcon and blessing_icon.mode=="bless","blessing cell reuses the real HP-bar three-green-star FateIcon")
	check(blessing_icon!=null and blessing_icon.visible and is_equal_approx(blessing_icon.reveal,1.0),"blessing FateIcon renders immediately without delayed animation")
	check(panel.face_cells[0][2].get_meta("mode")=="curse","3 shows base curse instead of inherited blessing")
	var curse_icon=panel.face_cells[0][2].get_node_or_null("BrandFaceFateIcon")
	check(curse_icon!=null and curse_icon.get_script()==FateIcon and curse_icon.mode=="curse","curse cell reuses the real HP-bar violet-line FateIcon")
	check(curse_icon!=null and curse_icon.visible and is_equal_approx(curse_icon.reveal,1.0),"curse FateIcon renders immediately without delayed animation")
	check(panel.face_cells.all(func(row): return row.all(func(cell): return cell.text.is_empty())),"all 48 dice face cells use images, never old letter glyphs")
	var icon_mapping_ok: bool=true
	for row in panel.face_cells:
		for cell in row:
			var symbol=cell.get_node_or_null("BrandFaceFateIcon")
			var mode: String=str(cell.get_meta("mode"))
			icon_mapping_ok=icon_mapping_ok and ((mode=="normal" and symbol==null) or
				(mode=="blessing" and symbol!=null and symbol.mode=="bless") or
				(mode=="curse" and symbol!=null and symbol.mode=="curse"))
	check(icon_mapping_ok,"all actual blessing/curse faces carry the matching HP fate artwork, inactive cells stay empty")
	var legend=panel.get_node_or_null("BrandReferenceLegend") as Label
	check(legend!=null and legend.text=="초록 별: 축복 · 보라색 선: 저주 · 마물 이름이나 눈금을 누르면 효과를 볼 수 있습니다.","legend explains HP-bar green stars and violet lines")
	check(panel.face_cells[0][3].get_meta("mode")=="blessing","4 shows inherited blessing on safe face")
	check(panel.face_cells[0][0].disabled,"inactive face cannot be mistaken for a blessing")
	panel.face_cells[0][2].pressed.emit()
	check(panel.summary.text.contains("저 ") and panel.summary.text.contains("3번"),"tapping a curse displays readable Korean and the correct face")
	panel.face_cells[0][1].pressed.emit()
	check(panel.summary.text.contains("축 ") and panel.summary.text.contains("2번"),"tapping a blessing displays readable Korean and the correct face")
	check(panel.popup_title.text.contains("2번 눈금") and panel.selected_face==2,"focused popup identifies the selected face")
	check(panel.reference_rows[0].modulate==Color.WHITE and panel.reference_rows[1].modulate.r<0.9,"selected unit remains bright while unrelated rows dim")
	panel.reference_rows[0].get_child(0).pressed.emit()
	var gameplay_src: String=FileAccess.get_file_as_string("res://battlefield.gd")
	check(gameplay_src.contains('button(layer,"낙인표",') and not gameplay_src.contains("✦☠ 낙인표"),"real battlefield opens the same board through a readable button")
	check(panel.selected_face==0 and panel.popup_title.text.contains("전체 낙인"),"tapping monster name opens its overall marks")
	check(panel.summary.text.contains("축복 [") and panel.summary.text.contains("저주 ["),"tapping unit reveals full brand list")
	check(before==JSON.stringify(rules.snapshot()),"opening and using reference never mutates RNG, roster or battle state")
	check(panel.reference_scroll.size.x>=930 and panel.reference_grid.get_child_count()==9,"source seven-column grid has room for 8 units plus dice header")
	panel.hide_detail()
	check(not panel.detail_popup.visible and panel.selected_unit_id.is_empty(),"detail close restores glanceable overview")
	check(panel.reference_rows.all(func(row): return row.modulate==Color.WHITE),"all rows return to full contrast after detail closes")
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
	check(other.face_cells[0].all(func(cell): return cell.disabled and cell.text.is_empty() and cell.get_node_or_null("BrandFaceFateIcon")==null),"empty brands produce no active icons")
	other.queue_free()
	await process_frame
	print("UI_BATTLE_BRAND_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
