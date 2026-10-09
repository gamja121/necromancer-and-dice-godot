extends RefCounted

# Visual randomness stays separate from world/battle result randomness.
var visual_rng = RandomNumberGenerator.new()
var frame_index = 0

func _init() -> void:
	visual_rng.randomize()

func roll_battle(button: TextureButton, get_texture: Callable, play_sound: Callable, wait: Callable) -> void:
	var origin = button.position
	var base_scale = button.scale
	var base_rotation = button.rotation
	button.pivot_offset = button.size*0.5
	var steps = visual_rng.randi_range(18,22)
	var elapsed = 0.0
	for step in range(steps):
		if not is_instance_valid(button) or not button.is_inside_tree(): return
		frame_index = (frame_index+1)%12
		button.texture_normal = get_texture.call("res://assets/battle/dice/roll-%02d.png" % (frame_index+1))
		var phase = (sin(elapsed*PI/0.21)+1.0)*0.5
		button.position = origin+Vector2(0,lerpf(5,-6,phase))
		button.rotation = base_rotation+deg_to_rad(lerpf(-3,3,phase))
		button.scale = base_scale*lerpf(0.96,1.04,phase)
		if step%2==0 and play_sound.is_valid(): play_sound.call("dice-tick")
		var progress = float(step)/maxi(1,steps-1)
		var interval = 0.042+progress*progress*0.062
		await wait.call(interval)
		elapsed += interval
	if is_instance_valid(button):
		button.position = origin
		button.rotation = base_rotation
		button.scale = base_scale

func roll_map(button: TextureButton, face: int, area: Rect2, get_texture: Callable, play_sound: Callable) -> void:
	button.pivot_offset = button.size*0.5
	var radius = button.size.length()*0.55
	var minimum = area.position+Vector2.ONE*radius
	var maximum = area.end-Vector2.ONE*radius
	var center = button.position+button.size*0.5
	center = center.clamp(minimum,maximum)
	var angle = visual_rng.randf_range(0,TAU)
	if absf(cos(angle))<0.28: angle += 0.45
	var base_speed = 1280.0*visual_rng.randf_range(0.62,0.78)
	var velocity = Vector2(cos(angle)*base_speed,sin(angle)*base_speed*0.72)
	var rotation = visual_rng.randf_range(-40,40)
	var duration = visual_rng.randf_range(1.75,2.20)
	var elapsed = 0.0
	var frame_clock = 0.0
	var sound_clock = 0.0
	if play_sound.is_valid(): play_sound.call("dice-tick")
	while elapsed<duration:
		await button.get_tree().process_frame
		if not is_instance_valid(button) or not button.is_inside_tree(): return
		var dt = minf(button.get_process_delta_time(),0.035)
		elapsed += dt
		frame_clock += dt
		sound_clock += dt
		velocity *= exp(-(3.4 if elapsed>duration*0.62 else 1.15)*dt)
		center += velocity*dt
		var bounced = false
		if center.x<minimum.x:
			center.x = minimum.x
			velocity.x = absf(velocity.x)*0.78
			bounced = true
		elif center.x>maximum.x:
			center.x = maximum.x
			velocity.x = -absf(velocity.x)*0.78
			bounced = true
		if center.y<minimum.y:
			center.y = minimum.y
			velocity.y = absf(velocity.y)*0.78
			bounced = true
		elif center.y>maximum.y:
			center.y = maximum.y
			velocity.y = -absf(velocity.y)*0.78
			bounced = true
		if bounced and sound_clock>0.085 and play_sound.is_valid():
			play_sound.call("dice-tick")
			sound_clock = 0.0
		var speed = velocity.length()
		rotation += (1.0 if velocity.x>=0 else -1.0)*speed*dt*0.62
		button.position = center-button.size*0.5
		button.rotation_degrees = rotation
		button.scale = Vector2.ONE*(1.0+minf(speed/base_speed,1)*0.09)
		if frame_clock>0.062:
			frame_index = (frame_index+1)%12
			button.texture_normal = get_texture.call("res://assets/battle/dice/roll-%02d.png" % (frame_index+1))
			frame_clock = 0.0
		if elapsed>1.25 and speed<1280.0*0.045: break
	button.texture_normal = get_texture.call("res://assets/battle/dice/result-%02d.png" % face)
	button.scale = Vector2.ONE*1.04
	if play_sound.is_valid(): play_sound.call("dice-land")
	await button.get_tree().create_timer(0.12).timeout
	if is_instance_valid(button): button.scale = Vector2.ONE
