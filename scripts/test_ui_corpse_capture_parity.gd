extends SceneTree
## Capture banner and border-free selection enlargement with the original arrow.
const CaptureUI=preload("res://systems/corpse_capture.gd")
var passed=0
var failed=0
class CaptureSceneStub extends RefCounted:
	var message: Label=Label.new()
	var dice: TextureButton=TextureButton.new()
	var sprites: Dictionary={}
	var layer: Control
	var paused: bool = false
	var map_dock: bool = false
	var speed_values: Array = [1.5,2.0,3.0]
	var speed_index: int = 0
	var battle_tempo: float = 2.0
	var sound_calls: Array = []
	func sound(id: String) -> void: sound_calls.append(id)
	func uses_map_tile_dock() -> bool: return map_dock
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
		var card_b=TextureButton.new()
		card_b.size=Vector2(79,115)
		panel.add_child(card_b)
		var arrow_a=TextureRect.new()
		panel.add_child(arrow_a)
		var arrow_b=TextureRect.new()
		panel.add_child(arrow_b)
		check(card_a.get_node_or_null("CaptureSelectedOutline")==null and card_b.get_node_or_null("CaptureSelectedOutline")==null,"green capture-selection borders are absent")
		panel.choices=[{"card":card_a,"target":TextureButton.new(),"arrow":arrow_a,"index":0},{"card":card_b,"target":TextureButton.new(),"arrow":arrow_b,"index":1}]
		panel.scene=CaptureSceneStub.new()
		panel.scene.layer=panel
		panel.session=session
		session.world.pending_reward={"kind":"capture","selected":0,"corpses":[{"name":"구울","target":3},{"name":"늑대","target":5}],"attempts":2,"locked":false}
		panel.refresh()
		check(near(card_a.scale.x,1.15) and near(card_b.scale.x,1.0) and card_a.z_index>card_b.z_index,"chosen corpse enlarges and rises above other cards")
		check(card_a.pivot_offset.is_equal_approx(card_a.size*0.5),"chosen corpse scales around its center")
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
		check(near(card_b.scale.x,1.15) and near(card_a.scale.x,1.0) and arrow_b.visible and not arrow_a.visible,"enlargement and arrow follow saved selected index")
		check(panel.capture_info_status.text.contains("대상 고정") and panel.capture_info_status.text.contains("늑대"),"locked selection and chosen target displayed")
		check(card_a.disabled and card_b.disabled,"locked capture candidates cannot be changed")
		# In embedded combat the choices are stage siblings of the real map
		# tile buttons. Their z-order must stay high on every refresh and after
		# saved selection changes (not fall back to standalone 6/0).
		panel.scene.map_dock=true
		panel.refresh()
		check(card_a.z_index==CaptureUI.MAP_CAPTURE_CARD_Z and card_b.z_index==CaptureUI.MAP_CAPTURE_SELECTED_CARD_Z,
			"embedded harvest selection keeps all candidate cards over bottom map tiles")
		session.world.pending_reward.selected=0
		panel.refresh()
		check(card_a.z_index==CaptureUI.MAP_CAPTURE_SELECTED_CARD_Z and card_b.z_index==CaptureUI.MAP_CAPTURE_CARD_Z,
			"embedded harvest selection changes never lower any card to standalone z-order")
		panel.scene.map_dock=false
		session.world.pending_reward.selected=1
		panel.refresh()
		# Saved success cleanup: the arrow and other candidates disappear
		# before the kept monster can begin its inventory flight.
		var world_before_visual: String=JSON.stringify(session.world.snapshot())
		await panel.clear_unclaimed_capture_cards(card_b)
		check(not card_a.visible and card_b.visible,"unused enemy disappears before selected card collection")
		check(not arrow_a.visible and not arrow_b.visible and arrow_b.modulate.a<0.01,"selector arrow shrinks and fades out")
		check(near(arrow_b.scale.x,0.68) and card_a.material is ShaderMaterial,"existing failed-capture dissolve is reused for unclaimed card")
		check(panel.scene.sound_calls.is_empty(),"quick candidate cleanup does not replay permanent-death sound")
		check(JSON.stringify(session.world.snapshot())==world_before_visual,"presentation cleanup never changes capture rewards or save")
		panel.queue_free()
		await process_frame
	session.world.pending_reward={}
	check(original_world==JSON.stringify(session.world.snapshot()),"visual capture test restores world and introduces no reward")
	session.save_file_path=prior_save
	for suffix in ["",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save+suffix))
	print("UI_CAPTURE_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
