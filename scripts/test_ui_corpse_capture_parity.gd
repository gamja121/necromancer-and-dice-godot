extends SceneTree
## Source capture banner, green selected-outline and existing capture status.
const CaptureUI=preload("res://systems/corpse_capture.gd")
var passed=0
var failed=0
class CaptureSceneStub extends RefCounted:
	var message: Label=Label.new()
	var dice: TextureButton=TextureButton.new()
	var sprites: Dictionary={}
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS ui-capture: ",label)
	else:
		failed+=1
		printerr("FAIL ui-capture: ",label)
func near(a: float,b: float) -> bool:
	return absf(a-b)<0.5
func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	if session==null:
		check(false,"RunSession autoload")
		quit(1)
		return
	var prior_save:String=session.save_file_path
	var temp_save:String="user://ui_capture_stage5e_%d.json" % OS.get_process_id()
	session.save_file_path=temp_save
	session.start_new_world()
	var original_world:String=JSON.stringify(session.world.snapshot())
	for surface in [720,530]:
		var panel=CaptureUI.new()
		root.add_child(panel)
		panel.size=Vector2(1280,surface)
		panel.build_capture_header()
		await process_frame
		check(panel.capture_info_panel!=null and panel.capture_info_status!=null and panel.capture_info_title!=null,"capture top banner and labels exist at height %d" % surface)
		check(near(panel.capture_info_panel.position.x,425.0) and near(panel.capture_info_panel.position.y,surface*0.07),"capture banner centered at original 7 percent top for %d" % surface)
		check(panel.capture_info_panel.size==Vector2(430,142) and panel.capture_info_panel.mouse_filter==Control.MOUSE_FILTER_IGNORE,"capture banner preserves source size and does not eat inputs")
		check(panel.capture_info_title.text=="영혼 수확","victory-capture title visible")
		var card_a=TextureButton.new()
		card_a.size=Vector2(79,115)
		panel.add_child(card_a)
		panel.add_selection_outline(card_a)
		var card_b=TextureButton.new()
		card_b.size=Vector2(79,115)
		panel.add_child(card_b)
		panel.add_selection_outline(card_b)
		var arrow_a=TextureRect.new()
		panel.add_child(arrow_a)
		var arrow_b=TextureRect.new()
		panel.add_child(arrow_b)
		check(card_a.get_node_or_null("CaptureSelectedOutline") is Panel and card_b.get_node_or_null("CaptureSelectedOutline") is Panel,"each candidate has independent outline")
		check(card_a.get_node("CaptureSelectedOutline").mouse_filter==Control.MOUSE_FILTER_IGNORE,"outlines do not intercept taps")
		panel.choices=[{"card":card_a,"target":TextureButton.new(),"arrow":arrow_a,"index":0},{"card":card_b,"target":TextureButton.new(),"arrow":arrow_b,"index":1}]
		panel.scene=CaptureSceneStub.new()
		panel.session=session
		session.world.pending_reward={"kind":"capture","selected":0,"corpses":[{"name":"구울","target":3},{"name":"늑대","target":5}],"attempts":2,"locked":false}
		panel.refresh()
		check(card_a.get_node("CaptureSelectedOutline").visible and not card_b.get_node("CaptureSelectedOutline").visible,"chosen corpse highlighted green, other corpse not")
		check(arrow_a.visible and not arrow_b.visible,"selected corpse alone has source arrow")
		check(absf(card_b.modulate.a-0.97)<0.015 and absf(card_a.modulate.a-1.0)<0.015,"unselected corpse stays legible at 97% opacity")
		# A defeated body was previously RGB 0.4 / alpha 0.35. Its actual
		# battlefield TextureRect and battle focus shader must be restored
		# ONLY on entering capture, without changing the gameplay record.
		var dead_sprite=TextureRect.new()
		dead_sprite.modulate=Color(0.4,0.4,0.4,0.35)
		dead_sprite.visible=false
		var focus_shader=Shader.new()
		focus_shader.code="shader_type canvas_item; uniform float dim = 1.0;"
		var focus_material=ShaderMaterial.new()
		focus_material.shader=focus_shader
		focus_material.set_shader_parameter("dim",1.0)
		dead_sprite.material=focus_material
		panel.scene.sprites={"enemy-corpse":dead_sprite}
		panel.improve_corpse_visibility({"id":"enemy-corpse"})
		check(dead_sprite.visible and absf(dead_sprite.modulate.a-1.0)<0.015 and dead_sprite.modulate.r>0.9,"capture-only corpse restores recognizable full-opacity art")
		check(absf(float(focus_material.get_shader_parameter("dim")))<0.015,"capture clears leftover cinematic dim shader")
		check(panel.capture_info_status.text.contains("구울") and panel.capture_info_status.text.contains("남은 시도 2"),"banner includes actual corpse and remaining rolls")
		session.world.pending_reward.selected=1
		session.world.pending_reward.locked=true
		panel.refresh()
		check(card_b.get_node("CaptureSelectedOutline").visible and not card_a.get_node("CaptureSelectedOutline").visible,"selection outline follows saved selected index")
		check(panel.capture_info_status.text.contains("대상 고정") and panel.capture_info_status.text.contains("늑대"),"locked selection and chosen target displayed")
		check(card_a.disabled and card_b.disabled,"locked capture candidates cannot be changed")
		panel.queue_free()
		await process_frame
	session.world.pending_reward={}
	check(original_world==JSON.stringify(session.world.snapshot()),"visual capture test restores world and introduces no reward")
	session.save_file_path=prior_save
	for suffix in ["",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save+suffix))
	print("UI_CAPTURE_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
