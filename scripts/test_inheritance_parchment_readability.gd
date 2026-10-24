extends SceneTree
## The live inheritance parchment must communicate die FACES, not attack bonuses;
## keep the permanent-sacrifice warning readable inside its own visual bounds.
const Scene = preload("res://systems/home_inheritance.gd")

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS inheritance-readability: ",label)
	else:
		failed += 1
		printerr("FAIL inheritance-readability: ",label)

func all_copy(node: Node) -> String:
	var combined := ""
	if node is Label: combined += (node as Label).text + " | "
	for child in node.get_children():
		combined += all_copy(child)
	return combined

func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	if session==null:
		check(false,"RunSession autoload available")
		quit(1)
		return
	var previous_path: String=session.save_file_path
	var scratch: String="user://inheritance_readability_%d.json" % OS.get_process_id()
	session.save_file_path=scratch
	session.start_new_world()
	var donor_id: String=str(session.world.roster[0].id)
	var receiver_id: String=str(session.world.roster[1].id)
	# The two blessing faces are actual die outcomes. Multiple donor brands
	# remain RANDOM candidates until the transaction commits.
	session.world.roster[0].brands=[
		{"type":"guard","bless":[2],"curse":[]},
		{"type":"poison","bless":[5],"curse":[]},
	]
	session.world.roster[1].brands=[{"type":"critical","bless":[3],"curse":[]}]
	var scene := Scene.new()
	root.add_child(scene)
	scene.setup(session)
	await process_frame
	var viewport:=scene.get_node_or_null("InheritanceDetailsScroll") as ScrollContainer
	var warning:=scene.get_node_or_null("InheritanceSacrificeWarning") as Label
	var status:=scene.get_node_or_null("InheritanceStepStatus") as Label
	check(viewport!=null and scene.details!=null,"scrollable content region is present inside original parchment")
	check(warning!=null and status!=null,"permanent-sacrifice warning and selection status have independent labels")
	if viewport!=null and warning!=null and status!=null:
		var paper: Rect2=scene.inheritance_frame.get_global_rect()
		check(paper.encloses(viewport.get_global_rect()),"information viewport stays within parchment")
		check(paper.encloses(warning.get_global_rect()),"warning stays within parchment, not over donor or receiver cards")
		check(paper.encloses(status.get_global_rect()),"progress status stays within parchment, not over the neighbor cards")
		check(viewport.get_global_rect().end.y<=warning.get_global_rect().position.y,"scrollable descriptions never overlap fixed warning")
		check(warning.get_global_rect().end.y<=status.get_global_rect().position.y,"warning and status have separate vertical space")
		check(status.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART,"long action warning wraps without horizontal overflow")
	var initial: String=all_copy(scene.details)
	check(initial.contains("①") and initial.contains("②"),"before selection, show two clearly ordered steps")
	scene.select_unit(donor_id)
	var donor_copy: String=all_copy(scene.details)
	check(donor_copy.contains("재료 낙인") and donor_copy.contains("수호") and donor_copy.contains("독"),"material shows only the relevant brand names")
	check(donor_copy.contains("축복 2") and donor_copy.contains("축복 5"),"material shows real die faces, not +2 and +5 attributes")
	check(not donor_copy.contains("이번 라운드") and not donor_copy.contains("중독 +1"),"repeated full effect prose is removed from the compact parchment")
	check(warning!=null and warning.text.contains("영구 소멸"),"donor selection gives permanent death warning")
	scene.select_unit(receiver_id)
	var full_copy: String=all_copy(scene.details)
	check(full_copy.contains("기존 낙인") and full_copy.contains("1/3칸"),"existing recipient brands and capacity stay visible without duplicate monster name")
	check(full_copy.contains("치명타") and full_copy.contains("축복 3"),"recipient existing die faces stay distinct from material candidates")
	check(scene.confirm_button!=null and not scene.confirm_button.disabled,"valid selection still enables existing confirmed inheritance action")
	check(status!=null and status.text=="낙인 1개 무작위 계승" and warning!=null and warning.text=="재료 마물 영구 소멸","random choice and permanent sacrifice each appear once, without duplicated sentences")
	check(scene.confirm_button.text=="계승 확정","confirmation button has concise copy instead of repeating warning")
	check(not full_copy.contains("재료 · 해골") and not full_copy.contains("받는 마물 ·"),"monster names already displayed on side cards are not repeated inside parchment")
	check(scene.inherited_brand.is_empty(),"no specific brand is falsely presented as already awarded before confirmation")
	scene.select_unit(donor_id)
	check(scene.material_id.is_empty() and scene.confirm_button.disabled,"deselecting donor still blocks incomplete sacrifice")
	# Use REAL base curse brands from the starting skeleton definitions,
	# not arbitrary curses that normalize() legitimately discards.
	session.world.roster[0].brands=[{"type":"vampire","bless":[2],"curse":[4]}]
	session.world.roster[1].brands=[{"type":"combo","bless":[3],"curse":[6]}]
	scene.select_unit(donor_id)
	scene.select_unit(receiver_id)
	var cursed_copy: String=all_copy(scene.details)
	check(cursed_copy.contains("흡혈") and cursed_copy.contains("축복 2") and cursed_copy.contains("저주 4"),"donor brand displays both blessing and actual base curse faces in one compact row")
	check(cursed_copy.contains("연격") and cursed_copy.contains("축복 3") and cursed_copy.contains("저주 6"),"recipient existing brand displays its persistent curse without losing die faces")
	var inline_curse: bool=true
	for node in scene.details.get_children():
		if node is HBoxContainer:
			var tags: int=0
			for child in node.get_children():
				if child is Label and child.name=="InheritanceCurseFaces":
					tags+=1
			inline_curse=inline_curse and tags==1
	check(inline_curse,"red curse face is part of the same brand line, not a small separate paragraph")
	check(scene.status.text=="축복만 무작위 계승","only blessing transfers; donor curses cannot be mistaken for inherited curses")
	var source: Dictionary=session.world.roster[0].brands[0]
	var awarded: Dictionary=preload("res://systems/brand_inheritance.gd").blessing(session.world.roster[1],source,session.world.definitions)
	check(awarded.get("bless",[])==[2] and awarded.get("curse",[99]).is_empty(),"original inheritance rule transfers blessing and does not copy source curse")
	scene.queue_free()
	await process_frame
	session.save_file_path=previous_path
	for extension in ["",".tmp"]:
		if FileAccess.file_exists(scratch+extension):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+extension))
	print("INHERITANCE_READABILITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
