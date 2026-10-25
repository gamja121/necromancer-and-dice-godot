extends Control
## Presentation only. Gameplay/storage is committed by the map after collect_requested.
signal collect_requested
signal ready_to_collect
const SIZE=Vector2(156,234)
const Paper="res://assets/map/ui/routine_event_card_base_v2.png"
const Sound=preload("res://systems/game_audio.gd")
var phase: String="opening"
var effect: String="dice"
var visual: Control
var back: Control
var front: Control
var hint: Label
var halo: Panel
var motion: Tween
var from_center: Vector2
var side_center: Vector2
var front_center: Vector2
var delivery_target: Vector2

class ArrivalPulse extends Control:
	var amount: float=0.0
	var tint: Color=Color("dfbd75")
	func _draw() -> void:
		var ink: Color=tint
		ink.a=(1.0-amount)*0.75
		draw_arc(Vector2.ZERO,16.0+amount*40.0,0.0,TAU,48,ink,2.0,true)
		for i in range(8):
			var angle: float=TAU*float(i)/8.0
			draw_circle(Vector2(cos(angle),sin(angle))*(14.0+amount*47.0),2.2*(1.0-amount),ink)
	func advance(value: float) -> void:
		amount=value
		queue_redraw()

func picture(parent: Control, path: String, pos: Vector2, dimensions: Vector2) -> TextureRect:
	var node:=TextureRect.new()
	# Ignore the imported texture minimum before assigning size (native GPU textures can be 1k+).
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture=load(path)
	node.position=pos
	node.size=dimensions
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func caption(parent: Control, value: String, pos: Vector2, dimensions: Vector2, points: int, ink: Color=Color("332316")) -> Label:
	var node:=Label.new()
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.text=value
	node.position=pos
	node.size=dimensions
	node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",points)
	node.add_theme_color_override("font_color",ink)
	parent.add_child(node)
	return node

func build(_entry: Dictionary, reward_picture: String) -> void:
	name="RoutineRewardMotion"
	size=Vector2(1280,720)
	mouse_filter=Control.MOUSE_FILTER_STOP
	effect="dice"
	visual=Control.new()
	visual.name="RoutineRewardCard"
	visual.size=SIZE
	visual.pivot_offset=SIZE*0.5
	visual.mouse_filter=Control.MOUSE_FILTER_IGNORE
	visual.z_index=1
	add_child(visual)
	halo=Panel.new()
	halo.position=Vector2(-5,-5)
	halo.size=SIZE+Vector2(10,10)
	halo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	halo.show_behind_parent=true
	var rim:=StyleBoxFlat.new()
	rim.draw_center=false
	rim.border_color=Color("d5b878")
	rim.set_border_width_all(1)
	rim.set_corner_radius_all(6)
	rim.shadow_color=Color(0.84,0.65,0.26,0.30)
	rim.shadow_size=19
	halo.add_theme_stylebox_override("panel",rim)
	halo.hide()
	visual.add_child(halo)
	back=Control.new()
	back.size=SIZE
	back.mouse_filter=Control.MOUSE_FILTER_IGNORE
	visual.add_child(back)
	var reverse:=picture(back,Paper,Vector2.ZERO,SIZE)
	reverse.stretch_mode=TextureRect.STRETCH_SCALE
	reverse.modulate=Color("766348")
	caption(back,"✦",Vector2(18,65),Vector2(120,85),58,Color("dfbd75"))
	front=Control.new()
	front.size=SIZE
	front.mouse_filter=Control.MOUSE_FILTER_IGNORE
	visual.add_child(front)
	picture(front,reward_picture,Vector2.ZERO,SIZE)
	front.hide()
	hint=caption(self,"화면을 한 번 누르면 받습니다",Vector2(340,620),Vector2(600,50),18,Color("f7e4bd"))
	hint.z_index=6
	hint.hide()

func setup(card: Control, entry: Dictionary, reward_picture: String) -> void:
	build(entry,reward_picture)
	card.z_index=2
	var transform: Transform2D=get_global_transform_with_canvas().affine_inverse()*card.get_global_transform_with_canvas()
	from_center=transform*(card.size*0.5)
	side_center=transform*Vector2(card.size.x+SIZE.x*0.82,card.size.y*0.40)
	front_center=from_center+Vector2(0,-20)
	visual.position=from_center-SIZE*0.5
	visual.scale=Vector2.ONE*0.82
	visual.rotation_degrees=-12
	visual.modulate.a=0.0

func setup_direct(entry: Dictionary, reward_picture: String, source_rect: Rect2) -> void:
	build(entry,reward_picture)
	front.show()
	back.hide()
	visual.z_index=4
	visual.position=source_rect.get_center()-SIZE*0.5
	visual.scale=source_rect.size/SIZE
	phase="committing"

func reveal() -> void:
	Sound.cue(self,"book_page")
	motion=create_tween().set_parallel(true)
	motion.tween_property(visual,"modulate:a",1.0,0.12)
	motion.tween_method(orbit_out,0.0,1.0,0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await motion.finished
	if not is_inside_tree(): return
	phase="turning"
	visual.z_index=4
	motion=create_tween()
	motion.tween_method(turn_front,0.0,1.0,0.50).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await motion.finished
	if not is_inside_tree(): return
	visual.scale=Vector2.ONE
	visual.rotation_degrees=0.0
	back.hide()
	front.show()
	halo.show()
	hint.show()
	phase="ready"
	ready_to_collect.emit()

func orbit_out(t: float) -> void:
	var control: Vector2=from_center.lerp(side_center,0.5)+Vector2(0,-150)
	var point: Vector2=from_center*(1-t)*(1-t)+control*2*(1-t)*t+side_center*t*t
	visual.position=point-SIZE*0.5
	visual.rotation_degrees=lerpf(-12.0,17.0,t)
	visual.scale=Vector2.ONE*lerpf(0.82,1.0,t)

func turn_front(t: float) -> void:
	var control: Vector2=side_center.lerp(front_center,0.45)+Vector2(45,110)
	visual.position=side_center*(1-t)*(1-t)+control*2*(1-t)*t+front_center*t*t-SIZE*0.5
	visual.scale=Vector2(maxf(0.055,absf(cos(PI*t))),1.0)
	visual.rotation_degrees=lerpf(17.0,0.0,t)
	back.visible=t<0.5
	front.visible=t>=0.5

func collect() -> void:
	if phase!="ready": return
	phase="committing"
	hint.hide()
	collect_requested.emit()

func allow_retry(message: String) -> void:
	phase="ready"
	hint.text=message+"\n"+"화면을 한 번 누르면 받습니다"
	hint.show()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		collect()
	elif event is InputEventScreenTouch and event.pressed:
		accept_event()
		collect()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		collect()

func deliver(target: Vector2) -> void:
	phase="collecting"
	delivery_target=target
	hint.hide()
	halo.hide()
	var start: Vector2=visual.position
	var finish: Vector2=target-SIZE*0.5
	var control: Vector2=start.lerp(finish,0.45)+Vector2(0,-155)
	var initial_scale: Vector2=visual.scale
	motion=create_tween()
	motion.tween_method(func(t: float):
		visual.position=start*(1-t)*(1-t)+control*2*(1-t)*t+finish*t*t
		visual.scale=initial_scale.lerp(Vector2.ONE*0.12,t)
		visual.rotation_degrees=lerpf(0.0,10.0,t)
		visual.modulate.a=minf(1.0,(1.0-t)*4.0),0.0,1.0,0.80).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await motion.finished
	if not is_inside_tree(): return
	visual.hide()
	var pulse:=ArrivalPulse.new()
	pulse.position=target
	pulse.z_index=5
	pulse.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pulse.tint=Color("dfbd75")
	add_child(pulse)
	motion=create_tween()
	motion.tween_method(pulse.advance,0.0,1.0,0.34)
	await motion.finished
	phase="done"

func _exit_tree() -> void:
	if motion!=null and motion.is_valid(): motion.kill()
	Sound.stop(self)
