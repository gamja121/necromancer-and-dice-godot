extends SceneTree
## Compact crow contamination HUD and its actual 2D die collision boundary.
## Pure UI/animation changes: no dice result, inventory or world save mutation.
const HUD = preload("res://systems/contamination_hud.gd")
const DICE = preload("res://systems/dice_animation.gd")
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
var passed: int=0
var failed: int=0

func check(ok: bool, what: String) -> void:
	if ok:
		passed+=1
		print("PASS contamination-dice-wall: ",what)
	else:
		failed+=1
		printerr("FAIL contamination-dice-wall: ",what)

func _initialize() -> void:
	call_deferred("_run")

func check_bounce(animation: RefCounted, wall: Rect2, from: Vector2, to: Vector2, velocity: Vector2, axis: String, sign: int, radius: float) -> void:
	var result: Dictionary=animation.resolve_wall_bounce(from,to,velocity,radius,wall)
	check(bool(result.get("bounced",false)),axis+": obstacle produces bounce")
	var new_velocity: Vector2=result["velocity"]
	var center: Vector2=result["center"]
	if axis=="x":
		check(signf(new_velocity.x)==float(sign) and absf(new_velocity.x)>0.0,axis+": reflection sends die away from stone")
	else:
		check(signf(new_velocity.y)==float(sign) and absf(new_velocity.y)>0.0,axis+": reflection sends die away from stone")
	check(not wall.grow(radius).has_point(center),axis+": reflected die is fully outside solid HUD")

func _run() -> void:
	var hud: Control=HUD.new()
	root.add_child(hud)
	await process_frame
	check(hud.uses_approved_art,"selected crow stone artwork loads")
	check(hud.size==Vector2(480,160),"HUD width/height shrink from 576x192 to 480x160")
	check(hud.position==Vector2(400,395),"HUD remains centred above lower map tiles")
	check(hud.mouse_filter==Control.MOUSE_FILTER_IGNORE,"decorative frame never blocks user clicks")
	var wall: Rect2=hud.dice_wall_rect()
	check(wall.has_area() and wall.position.x>=hud.position.x and wall.end.x<=hud.position.x+hud.size.x,"die wall covers the compact stone frame")
	check(wall.position.y>hud.position.y and wall.end.y<=hud.position.y+hud.size.y,"wall excludes the high crow/transparent upper pixels")
	var src: String=FileAccess.get_file_as_string("res://systems/contamination_hud.gd")
	check(src.find("title_size: int = 31")!=-1 and src.find("title: String = \"오염도\"")!=-1,"only the contamination title is enlarged")
	check(src.find("value_text:")==-1 and src.find("%d / 100")==-1 and src.find("caption =")==-1,"all numeric and stage labels removed from active/fallback paint")
	hud.set_value(12,true)
	var steps: PackedFloat32Array=hud.segment_fractions(hud.display_value)
	check(steps.size()==10 and steps[0]==1.0 and is_equal_approx(steps[1],0.2),"0–100 still has ten partial-fill slots")

	var die: RefCounted=DICE.new()
	var radius: float=Vector2(76,76).length()*0.55
	var mid_x: float=wall.get_center().x
	var mid_y: float=wall.get_center().y
	var upper: float=wall.position.y-radius
	var lower: float=wall.end.y+radius
	var left: float=wall.position.x-radius
	var right: float=wall.end.x+radius
	check_bounce(die,wall,Vector2(mid_x,upper-4),Vector2(mid_x,upper+9),Vector2(0,350),"y",-1,radius)
	check_bounce(die,wall,Vector2(mid_x,lower+4),Vector2(mid_x,lower-9),Vector2(0,-350),"y",1,radius)
	check_bounce(die,wall,Vector2(left-4,mid_y),Vector2(left+9,mid_y),Vector2(350,0),"x",-1,radius)
	check_bounce(die,wall,Vector2(right+4,mid_y),Vector2(right-9,mid_y),Vector2(-350,0),"x",1,radius)
	var free: Dictionary=die.resolve_wall_bounce(Vector2(640,190),Vector2(640,215),Vector2(0,800),radius,wall)
	check(not free["bounced"] and free["center"]==Vector2(640,215),"die is unaffected away from obstacle")
	var ignored: Dictionary=die.resolve_wall_bounce(Vector2(mid_x,upper-4),Vector2(mid_x,upper+9),Vector2(0,350),radius,Rect2())
	check(not ignored["bounced"],"hidden/empty HUD has no collision")
	var trapped: Dictionary=die.resolve_wall_bounce(wall.get_center(),wall.get_center(),Vector2(0,90),radius,wall)
	check(trapped["bounced"] and not wall.grow(radius).has_point(trapped["center"]),"embedded die can escape nearest wall face")
	hud.hide()
	check(not hud.dice_wall_rect().has_area(),"hidden board chrome cannot act as invisible wall")
	hud.queue_free()
	await process_frame

	var session: Node=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var path_before: String=session.save_file_path
	var temp_path: String="user://contamination_die_wall_%d.json"%OS.get_process_id()
	session.save_file_path=temp_path
	session.start_new_world()
	var snapshot: Dictionary=session.world.snapshot().duplicate(true)
	var rng: int=session.world.rng.state
	var map: Control=MAP.instantiate()
	root.add_child(map)
	await process_frame
	var real_hud: Control=map.presentation.gauge
	check(real_hud.size==Vector2(480,160) and real_hud.dice_wall_rect().has_area(),"real map uses compact die-blocking HUD")
	check(map.dice.position==Vector2(602,307.6),"original clickable map die location preserved")
	check(real_hud.dice_wall_rect().position.y-radius>map.dice.position.y+map.dice.size.y*0.5,"die starts above the expanded HUD wall")
	check(session.world.snapshot()==snapshot and session.world.rng.state==rng,"layout/wall updates never change saved world or die RNG")
	map.modal()
	check(not real_hud.dice_wall_rect().has_area(),"modal hides both the bar and its physical collision")
	map.close_overlay()
	check(real_hud.dice_wall_rect().has_area(),"closing modal restores HUD collision")
	map.queue_free()
	await process_frame
	session.save_file_path=path_before
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(temp_path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path+suffix))
	if created: session.queue_free()
	print("CONTAMINATION_DICE_WALL: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
