extends Control
## Terminal expedition screen. The existing, saved die remains untouched:
## a transient copy cracks and splits into textured triangular fragments.
signal displayed

const FONT = preload("res://assets/fonts/nanum_gothic_regular.ttf")
const INTRO_SECONDS = 3.1
const CENTER = Vector2(640,318)

var session: Node
var source_die: TextureButton
var record: Dictionary = {}
var ally_footprints: Array = []
var shade: ColorRect
var die_copy: TextureRect
var skip_button: Button
var result_panel: Control
var shards: Array = []
var ring_alpha: float = 1.0
var cracking: bool = false
var finished: bool = false
var cinematic: bool = false
var circle_clock: float = 0.0
var _intro_tweens: Array = []

func setup(run_session: Node, persistent_die: TextureButton, positions: Array, instant: bool = false) -> void:
	session=run_session
	source_die=persistent_die
	record=session.world.run_result.duplicate(true)
	ally_footprints=positions.duplicate()
	name="GameOverScreen"
	position=Vector2.ZERO
	size=Vector2(1280,720)
	mouse_filter=Control.MOUSE_FILTER_STOP
	z_index=200
	set_process(true)
	shade=ColorRect.new()
	shade.size=size
	shade.color=Color(0.027,0.023,0.039,0.0 if not instant else 0.94)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	if is_instance_valid(source_die): source_die.hide()
	if not instant:
		die_copy=TextureRect.new()
		die_copy.name="DoomedDie"
		die_copy.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		die_copy.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		die_copy.texture=source_die.texture_normal if is_instance_valid(source_die) else load("res://assets/battle/dice/result-01.png")
		die_copy.size=Vector2(96,96)
		die_copy.position=(source_die.position if is_instance_valid(source_die) else CENTER)-Vector2(10,10)
		die_copy.pivot_offset=die_copy.size*0.5
		die_copy.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(die_copy)
		skip_button=_button("건너뛰기",Vector2(1100,22),Vector2(138,40),finish_now)
		skip_button.name="SkipGameOver"
		cinematic=true
		call_deferred("_cinematic")
	else:
		finish_now()

func _gui_input(event: InputEvent) -> void:
	if not cinematic: return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		finish_now()
		accept_event()

func _process(delta: float) -> void:
	if cinematic:
		circle_clock += delta
		queue_redraw()

func _draw() -> void:
	if not cinematic or ring_alpha<=0.0: return
	for center in ally_footprints:
		draw_set_transform(center,circle_clock*0.30,Vector2(1.0,0.25))
		for k in range(3):
			draw_arc(Vector2.ZERO,40.0+float(k)*12.0,0,TAU,48,Color(0.3,0.7,0.86,(0.46-float(k)*0.10)*ring_alpha),2.0,true)
		for spoke in range(8):
			var angle: float=TAU*float(spoke)/8
			draw_line(Vector2.RIGHT.rotated(angle)*39,Vector2.RIGHT.rotated(angle)*61,Color(0.56,0.8,0.93,ring_alpha*0.45),1.5,true)
		draw_set_transform(Vector2.ZERO)

func _cinematic() -> void:
	if finished: return
	var darken=create_tween()
	_intro_tweens.append(darken)
	darken.tween_property(shade,"color:a",0.70,0.72)
	darken.parallel().tween_property(self,"ring_alpha",0.0,1.05)
	await get_tree().create_timer(1.05).timeout
	if finished or not is_inside_tree(): return
	# Do not change or re-save the real die: only its on-screen copy moves.
	var rise=create_tween()
	_intro_tweens.append(rise)
	rise.tween_property(die_copy,"position",CENTER-die_copy.size*0.5,0.48).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.48).timeout
	if finished or not is_inside_tree(): return
	_crack_die()
	await get_tree().create_timer(0.76).timeout
	if finished or not is_inside_tree(): return
	var fade=create_tween()
	_intro_tweens.append(fade)
	fade.tween_property(shade,"color:a",0.94,0.45)
	await get_tree().create_timer(0.52).timeout
	if finished or not is_inside_tree(): return
	finish_now()

func _crack_die() -> void:
	if not is_instance_valid(die_copy) or cracking: return
	cracking=true
	var texture: Texture2D=die_copy.texture
	var center: Vector2=die_copy.position+die_copy.size*0.5
	var half: float=die_copy.size.x*0.5
	# Eight triangles meet at the source die center, retaining the real face.
	# Polygon2D UVs use texture-pixel coordinates, not a fabricated die image.
	var points: Array=[
		Vector2(-half,-half),Vector2(0,-half),Vector2(half,-half),
		Vector2(half,0),Vector2(half,half),Vector2(0,half),
		Vector2(-half,half),Vector2(-half,0)
	]
	for k in range(points.size()):
		var piece=Polygon2D.new()
		piece.name="DieShard_%d" % k
		var triangle=PackedVector2Array([Vector2.ZERO,points[k],points[(k+1)%points.size()]])
		piece.polygon=triangle
		piece.texture=texture
		var texture_size: Vector2=texture.get_size()
		var uvs=PackedVector2Array()
		for p in triangle:
			uvs.append((p+Vector2(half,half))*texture_size/(half*2.0))
		piece.uv=uvs
		piece.position=center
		piece.modulate=Color(1,1,1,1)
		add_child(piece)
		shards.append(piece)
	die_copy.hide()
	# Use existing heavy impact and soul-death samples; no new asset files.
	if DisplayServer.get_name()!="headless":
		_play_impact("res://assets/battle/sfx/heavy.ogg",-4.0,0.72)
		_play_impact("res://assets/battle/sfx/death.ogg",-9.0,0.92)
	for k in range(shards.size()):
		var piece: Polygon2D=shards[k]
		var direction: Vector2=Vector2.RIGHT.rotated(TAU*(float(k)+0.28)/float(shards.size()))
		var drift: Vector2=direction*(93.0+float(k%3)*23.0)+Vector2(0,30)
		var tween=create_tween().set_parallel(true)
		_intro_tweens.append(tween)
		tween.tween_property(piece,"position",piece.position+drift,0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(piece,"rotation",(-1.0 if k%2==0 else 1.0)*(0.5+float(k%3)*0.24),0.65)
		tween.tween_property(piece,"modulate:a",0.0,0.6).set_delay(0.12)

func _play_impact(path: String, volume: float, pitch: float) -> void:
	var player=AudioStreamPlayer.new()
	player.bus="SFX"
	player.stream=load(path)
	player.volume_db=volume
	player.pitch_scale=pitch
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func finish_now() -> void:
	if finished: return
	finished=true
	cinematic=false
	ring_alpha=0
	for tween in _intro_tweens:
		if tween is Tween and tween.is_valid(): tween.kill()
	if is_instance_valid(die_copy): die_copy.hide()
	for piece in shards:
		if is_instance_valid(piece): piece.hide()
	if is_instance_valid(skip_button): skip_button.hide()
	shade.color=Color(0.027,0.023,0.039,0.95)
	_show_results()
	displayed.emit()
	queue_redraw()

func _label(parent: Control, value: String, pos: Vector2, dimensions: Vector2, font_size: int, color: Color, centered: bool = true) -> Label:
	var node=Label.new()
	node.text=value
	node.position=pos
	node.size=dimensions
	node.add_theme_font_override("font",FONT)
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _button(value: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button=Button.new()
	button.text=value
	button.position=pos
	button.size=dimensions
	button.add_theme_font_override("font",FONT)
	button.add_theme_font_size_override("font_size",16)
	button.add_theme_color_override("font_color",Color("e9d4ae"))
	var box=StyleBoxFlat.new()
	box.bg_color=Color("30272b")
	box.border_color=Color("917654")
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal",box)
	add_child(button)
	button.pressed.connect(callback)
	return button

func _show_results() -> void:
	if is_instance_valid(result_panel): return
	result_panel=Control.new()
	result_panel.name="FinalExpeditionRecord"
	result_panel.position=Vector2(316,93)
	result_panel.size=Vector2(648,534)
	add_child(result_panel)
	var plate=ColorRect.new()
	plate.color=Color("16141b")
	plate.size=result_panel.size
	plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	result_panel.add_child(plate)
	_label(result_panel,"NECROMANCER AND DICE",Vector2(110,28),Vector2(430,20),14,Color("a8786b"))
	_label(result_panel,"원정 종료",Vector2(100,62),Vector2(448,72),47,Color("e4cbb8"))
	_label(result_panel,"망자의 계약이 끊어졌다.",Vector2(96,137),Vector2(456,34),18,Color("aaa09b"))
	var rows: Array=[
		["도달한 바퀴","%d / 60" % int(record.get("laps",0))],
		["처치한 적","%d" % int(record.get("enemies_defeated",0))],
		["잃은 마물","%d" % int(record.get("lost_monsters",0))],
		["최종 오염도","%d / 100" % int(record.get("contamination",0))]
	]
	for i in range(rows.size()):
		var x: float=48.0+float(i%2)*290.0
		var y: float=212.0+float(i/2)*104.0
		var bg=ColorRect.new()
		bg.position=Vector2(x,y)
		bg.size=Vector2(262,84)
		bg.color=Color("242329")
		bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
		result_panel.add_child(bg)
		_label(result_panel,rows[i][0],Vector2(x,y+8),Vector2(262,28),14,Color("a99c90"))
		_label(result_panel,rows[i][1],Vector2(x,y+34),Vector2(262,43),26,Color("e9d9c2"))
	var new_run=_button("새 원정 시작",Vector2(388,552),Vector2(240,52),_new_run)
	new_run.name="NewExpedition"
	var title=_button("타이틀로 돌아가기",Vector2(652,552),Vector2(240,52),_back_to_title)
	title.name="ReturnToTitle"

func _new_run() -> void:
	session.start_new_world()
	get_tree().change_scene_to_file("res://intro.tscn")

func _back_to_title() -> void:
	get_tree().change_scene_to_file("res://title.tscn")
