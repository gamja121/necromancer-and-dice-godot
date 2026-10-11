extends SceneTree
## 5D – original 16dvh battle-dock cards, selection, action tuck, death art.
const BattleScene=preload("res://battlefield.tscn")
var passed: int=0
var failed: int=0
func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS ui-battle-dock: ",label)
	else:
		failed+=1
		printerr("FAIL ui-battle-dock: ",label)

func near(a: float,b: float,epsilon: float=0.3) -> bool:
	return absf(a-b)<=epsilon

func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	if session==null:
		check(false,"RunSession autoload")
		quit(1)
		return
	var old_save: String=session.save_file_path
	var temp_save: String="user://ui_battle_dock_%d.json" % OS.get_process_id()
	session.save_file_path=temp_save
	session.start_new_world()
	var battle=BattleScene.instantiate()
	root.add_child(battle)
	await process_frame
	check(not battle.embedded and battle.surface_size.y==720,"standalone battle builds at original 720px")
	check(battle.cards.size()==8,"all four allied and four enemy cards created")
	check(near(battle.dock_card_height(),115.2) and near(battle.dock_card_size().x,78.93),"720px original 16dvh card dimensions")
	check(near(battle.card_rest_y(),612.8),"standalone bottom 8 plus 16px CSS translate")
	check(near(battle.card_action_y(),700.0),"acting phase leaves original 20px outside dock")
	check(battle.card_death_shader!=null,"single death shader shared by all card textures")
	var unit: Dictionary=battle.rules.units[0]
	var card: TextureButton=battle.cards[unit.id]
	check(near(card.position.x,battle.unit_x(unit)-card.size.x*0.5),"card aligns with its battlefield unit position")
	check(near(card.position.y,battle.card_rest_y()),"unselected card starts in dock")
	check(card.material is ShaderMaterial and near(float(card.material.get_shader_parameter("death_factor")),0.0),"living card uses original colored artwork")
	check(card.rotation_degrees in [-3.0,2.0,-1.0,3.0,-2.0],"original irregular card rotation retained")
	check(not card.disabled and card.visible,"alive card opens battle unit information")
	var before: String=JSON.stringify(battle.rules.snapshot())
	battle.show_detail(unit)
	await create_timer(0.3).timeout
	check(battle.selected_card==unit.id and card.z_index==46,"selected card rises above other cards")
	check(near(card.position.y,battle.card_rest_y()-24.0),"selection rises 24px matching source")
	battle.close_detail()
	await create_timer(0.24).timeout
	check(near(card.position.y,battle.card_rest_y()),"closing unit info restores lower dock")
	battle.set_card_phase(true)
	await create_timer(0.26).timeout
	check(card.disabled and near(card.position.y,battle.card_action_y()),"acting phase tucks card and disables interaction")
	check(battle.selected_card.is_empty(),"starting action clears old card selection")
	battle.set_card_phase(false)
	await create_timer(0.27).timeout
	check(not card.disabled and near(card.position.y,battle.card_rest_y()),"return to ready restores visible clickable card")
	var dead_view: Array=battle.rules.units.duplicate(true)
	for i in range(dead_view.size()):
		if dead_view[i].id==unit.id:
			dead_view[i].alive=false
			dead_view[i].hp=0
	battle.render_units(dead_view)
	check(card.get_meta("dead",false)==true and near(float(card.material.get_shader_parameter("death_factor")),1.0),"dead artwork uses full desaturation and 60 percent opacity")
	check(card.visible and not card.disabled,"dead but not harvested card stays inspectable")
	battle.visuals.removed[unit.id]=true
	battle.render_units(dead_view)
	battle.set_card_phase(false)
	check(not card.visible and card.disabled,"harvested/permanently removed card is hidden and disabled")
	battle.visuals.removed.erase(unit.id)
	battle.render_units(battle.rules.units)
	battle.set_card_phase(false)
	check(card.visible and near(float(card.material.get_shader_parameter("death_factor")),0.0),"live visual refresh restores full color")
	check(before==JSON.stringify(battle.rules.snapshot()),"presentation never mutates saved battle state")
	battle.queue_free()
	await process_frame
	var embedded=BattleScene.instantiate()
	embedded.embedded=true
	root.add_child(embedded)
	await process_frame
	check(embedded.surface_size.y==530 and embedded.cards.size()==8,"map-embedded battlefield remains 530px with 8 cards")
	check(near(embedded.dock_card_height(),84.8) and near(embedded.dock_card_size().x,84.8*370.0/540.0),"embedded 16dvh cards shrink proportionally")
	check(near(embedded.card_rest_y(),453.2),"embedded ready cards fit inside lower 530px strip")
	check(near(embedded.card_action_y(),510.0),"embedded acting cards tuck to 20px")
	check(embedded.cards.values().all(func(item): return near(item.size.y,84.8) and near(item.position.y,453.2)),"all embedded cards follow responsive dimensions")
	for entry in embedded.rules.units:
		var element: TextureButton=embedded.cards[entry.id]
		check(near(element.position.x,embedded.unit_x(entry)-element.size.x/2.0),"slot %s stays centered after resize" % entry.id)
	embedded.queue_free()
	await process_frame
	session.save_file_path=old_save
	for suffix in ["",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save+suffix))
	print("UI_BATTLE_CARD_DOCK_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
