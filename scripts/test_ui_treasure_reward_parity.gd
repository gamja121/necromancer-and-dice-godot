extends SceneTree
## Source HTML treasure selection visual plus live saved three-offer reward.
const MapScene=preload("res://map.tscn")
const TreasureReward=preload("res://systems/treasure_reward.gd")
var passed: int=0
var failed: int=0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool,label: String) -> void:
	if ok:
		passed+=1
		print("PASS ui-treasure: ",label)
	else:
		failed+=1
		printerr("FAIL ui-treasure: ",label)
func near(a: float,b: float,epsilon: float=0.2) -> bool:
	return absf(a-b)<=epsilon
func await_ready(condition: Callable,limit: int=25000) -> bool:
	var start=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<limit:
		if condition.call(): return true
		await process_frame
	return bool(condition.call())
func is_treasure(map) -> bool:
	return is_instance_valid(map.overlay) and map.overlay is TreasureReward and map.overlay.options.size()==3 and not map.overlay.busy

func _run() -> void:
	var session=root.get_node_or_null("RunSession")
	if session==null:
		check(false,"RunSession autoload")
		quit(1)
		return
	var former_save: String=session.save_file_path
	var scratch="user://ui_treasure_stage5f_%d.json" % OS.get_process_id()
	session.save_file_path=scratch
	session.start_new_world()
	var world=session.world
	var gem: int=world.tiles.find("gem")
	check(gem>=0,"generated map has original treasure tile")
	if gem<0:
		quit(1)
		return
	# Use original treasure RNG. Search only for a normal, not a mimic, chest.
	var preview=RandomNumberGenerator.new()
	for value in range(1,120):
		preview.seed=value
		if preview.randf()>=0.10:
			world.rng.seed=value
			break
	world.position=gem
	check(session.open_treasure(gem) and world.pending_reward.kind=="treasure","real three-offer transaction created and saved")
	var map: Control=MapScene.instantiate()
	root.add_child(map)
	var ready: bool=await await_ready(func(): return is_treasure(map))
	check(ready,"three reward cards complete original staggered entrance")
	if ready:
		var panel=map.overlay
		check(panel.reward_origins.size()==3 and panel.reward_outlines.size()==3 and panel.reward_materials.size()==3,"each offer has an independent visual highlight")
		check(panel.options.size()==3 and panel.options.all(func(o): return o.texture_normal!=null or o.has_node("LayeredCardBase")),"three rewards show live monster cards or regular dice art")
		for i in range(3):
			check(near(panel.options[i].rotation_degrees,[-7.0,0.0,7.0][i]),"source reward-card tilt %d" % i)
			check(panel.options[i].position.distance_to(Vector2(314+i*216,245))<1.0 and panel.options[i].size.distance_to(Vector2(170,254))<0.3,"reward card %d preserves source layout" % i)
			check(not panel.reward_outlines[i].visible and near(panel.options[i].modulate.a,1.0),"unselected card %d stays fully visible" % i)
		check(is_instance_valid(panel.confirm_button) and panel.confirm_button.disabled,"separate reward claim starts disabled")
		panel.options[1].pressed.emit()
		check(world.pending_reward.selected==1 and not world.pending_reward.has("reward"),"first click saves choice but awards nothing")
		check(not panel.confirm_button.disabled,"selection enables the single reward claim button")
		panel.options[1].pressed.emit()
		check(world.pending_reward.selected==1 and not world.pending_reward.has("reward"),"repeated card tap never claims or awards")
		check(panel.reward_outlines[1].visible and panel.options[1].z_index==12,"chosen card has frontmost gold border")
		check(near(panel.options[1].position.y,245.0-254.0*0.08) and near(panel.options[1].scale.x,1.08),"chosen card rises 8 percent and grows to 108 percent")
		check(near(panel.options[0].modulate.a,0.48) and near(panel.options[2].modulate.a,0.48),"nonchosen cards dim to source opacity 48 percent")
		check(near(float(panel.reward_materials[0].get_shader_parameter("desaturate")),0.22) and near(float(panel.reward_materials[2].get_shader_parameter("brightness")),0.72),"unchosen art uses original grayscale and brightness")
		check(not panel.reward_outlines[0].visible and not panel.reward_outlines[2].visible,"only chosen card has gold selection outline")
		var selection_snapshot: Dictionary=world.pending_reward.duplicate(true)
		map.queue_free()
		await process_frame
		session.reload_world()
		world=session.world
		check(world.pending_reward==selection_snapshot,"selected card and same three offers survive JSON reload")
		map=MapScene.instantiate()
		root.add_child(map)
		ready=await await_ready(func(): return is_treasure(map))
		check(ready,"reload recreates visible saved treasure transaction")
		if ready:
			panel=map.overlay
			check(panel.reward_outlines[1].visible and near(panel.options[0].modulate.a,0.48),"saved choice restores gold border and nonchosen dimming")
			var card_before: Dictionary=world.pending_reward.duplicate(true)
			panel.show_confirmed_choice(1)
			check(near(panel.options[1].scale.x,1.1) and not panel.options[0].visible==true or near(panel.options[0].modulate.a,0),"confirmation preview raises winner and dismisses rejects")
			check(world.pending_reward==card_before,"visual confirmation is never a saved transaction")
			panel.refresh()
			var receipt_id: String=str(world.pending_reward.id)
			check(not panel.confirm_button.disabled and panel.confirm_button.text=="선택한 보상 받기","reload restores an enabled explicit claim button")
			panel.confirm_button.pressed.emit()
			var complete: bool=await await_ready(func(): return world.pending_reward.is_empty() and not is_instance_valid(map.overlay),30000)
			check(complete,"explicit claim button awards selected reward and completes inventory-flight UI")
			check(receipt_id in world.reward_receipts,"single unique reward receipt committed")
			check(not session.open_treasure(gem),"completed reward cannot be reopened to duplicate inventory")
	map.queue_free()
	await process_frame
	var snapshot: Dictionary=world.snapshot().duplicate(true)
	session.reload_world()
	check(session.world.snapshot()==snapshot,"claimed reward remains stable across restart")
	session.save_file_path=former_save
	for suffix in ["",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("UI_TREASURE_REWARD_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
