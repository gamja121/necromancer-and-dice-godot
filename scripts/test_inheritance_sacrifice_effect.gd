extends SceneTree
## The sacrificial card must vanish only after the original saved
## inheritance succeeds, while the recipient, brand data and card UI survive.
const HomeInheritance=preload("res://systems/home_inheritance.gd")
const FX=preload("res://systems/inheritance_sacrifice_effect.gd")
var passed: int=0
var failed: int=0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
	else:
		failed+=1
		printerr("FAIL inheritance-ash: ",label)

func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	if session==null:
		check(false,"RunSession autoload")
		quit(1)
		return
	var original_path: String=session.save_file_path
	var test_path: String="user://inherit_ash_%d.json" % OS.get_process_id()
	session.save_file_path=test_path
	session.start_new_world()
	check(session.world.roster.size()>=2,"at least two owned units")
	if session.world.roster.size()<2:
		quit(1)
		return
	# Use guaranteed compatible blessings rather than a random starter brand.
	session.world.roster[0].brands=[{"type":"guard","bless":[2],"curse":[]}]
	session.world.roster[1].brands=[{"type":"critical","bless":[3],"curse":[]}]
	check(session.save_world(),"fixture saved")
	var donor_id: String=str(session.world.roster[0].id)
	var receiver_id: String=str(session.world.roster[1].id)
	var original_count: int=session.world.roster.size()
	var original_receiver_count: int=session.world.roster[1].brands.size()
	var scene := HomeInheritance.new()
	root.add_child(scene)
	scene.setup(session)
	await process_frame
	scene.select_unit(donor_id)
	scene.select_unit(receiver_id)
	check(not scene.confirm_button.disabled,"eligible donor and recipient are selectable")
	check(scene.unit_options.has(donor_id),"donor exists in hand before confirmation")
	var donor_card: Control=scene.unit_options.get(donor_id,null) as Control
	var before_state: Dictionary=session.world.snapshot().duplicate(true)
	# Forced disk failure: the original transaction rolls back and there must
	# be zero cosmetic consuming animation or permanent visual deletion.
	session.save_file_path="user://missing_inherit_ash_%d/invalid.json" % OS.get_process_id()
	scene.confirm()
	check(not scene.busy and not scene.completed,"save failure releases screen lock")
	check(session.world.snapshot()==before_state,"save failure preserves full world")
	check(scene.material_art.has_node("LayeredCardPreview/LayeredCardBase") and scene.material_art.modulate.a>=0.99,"failed save does not animate away donor")
	check(scene.unit_options.has(donor_id) and is_instance_valid(donor_card),"failed save leaves original donor card")
	session.save_file_path=test_path
	scene.confirm()
	check(scene.busy and scene.completed,"success locks screen during dissolve")
	check(scene.inherited_brand.get("type","")=="guard" and scene.inherited_brand.get("bless",[])==[2],"result details record the actual saved brand and die face")
	check(session.owned_unit(donor_id).is_empty(),"donor was durably removed BEFORE animation")
	check(session.world.roster.size()==original_count-1,"exactly one original owned card consumed")
	check(scene.unit_options.has(donor_id),"the old card stays displayed until dissolve finishes")
	check(scene.material_art.has_node("LayeredCardPreview/LayeredCardBase"),"live layered preview remains visible at animation start")
	await create_timer(0.41).timeout
	print("INHERITANCE_ASH_MID: scale=",scene.material_art.scale.x," alpha=",scene.material_art.modulate.a)
	check(scene.busy and scene.material_art.scale.x<0.95,"preview shrinks during ash animation")
	check(scene.material_art.modulate.a<0.99,"preview fades only after saved success")
	check(scene.unit_options.has(donor_id),"hand refresh waits for visual effect")
	check(scene.confirm_button.disabled,"duplicate inheritance cannot begin while animating")
	await create_timer(FX.DURATION+0.18).timeout
	check(not scene.busy and scene.completed,"effect has completed and unlocked the screen")
	check(not scene.material_art.has_node("LayeredCardPreview") and scene.material_hint.text=="소모 완료","sacrificial preview clears only after dissolve")
	check(not scene.unit_options.has(donor_id),"deleted donor no longer appears in the new hand")
	check(scene.receiver_art.has_node("LayeredCardPreview/LayeredCardBase"),"recipient retains live layered card")
	var result_text: String=""
	for child in scene.details.get_children():
		if child is Label: result_text += (child as Label).text + " "
		else:
			for grandchild in child.get_children():
				if grandchild is Label: result_text += (grandchild as Label).text + " "
	check(result_text.contains("획득한 낙인") and result_text.contains("수호") and result_text.contains("눈금 2"),"after save and ash, parchment shows actual inherited brand and die face without long explanations")
	check(not result_text.contains("이번 라운드") and scene.sacrifice_warning.text=="계승 완료","completed parchment stays concise and does not repeat the effect paragraph")
	check(scene.material_art.scale==Vector2.ONE and scene.material_art.modulate==Color.WHITE,"temporary dissolve transforms were reset")
	check(session.owned_unit(receiver_id).brands.size()==original_receiver_count+1,"exactly one inherited blessing is added")
	check(not session.home_action_allowed().ok,"receipt prevents second inheritance in this visit")
	session.reload_world()
	check(session.owned_unit(donor_id).is_empty(),"donor removal survives save reload")
	check(session.owned_unit(receiver_id).brands.size()==original_receiver_count+1,"receiver keeps inherited blessing after reload")
	scene.queue_free()
	await process_frame
	session.save_file_path=original_path
	for extension in ["",".tmp"]:
		if FileAccess.file_exists(test_path+extension):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path+extension))
	print("INHERITANCE_SACRIFICE_EFFECT: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
