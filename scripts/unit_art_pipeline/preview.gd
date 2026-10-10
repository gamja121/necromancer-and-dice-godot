extends SceneTree

var frame_root: String
var output_root: String
var counts: Dictionary
var manifest: Dictionary
var frames: Dictionary = {}
var kind := "attack"
var current := 0
var playing := true
var speed := 10.0
var picture: TextureRect
var frame_label: Label
var pause_button: Button
var timer: Timer
var tabs: Dictionary = {}
var load_label: Label

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass the candidate manifest.json after --")
		quit(1)
		return
	manifest=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if manifest.is_empty():
		push_error("Invalid candidate manifest")
		quit(1)
		return
	output_root=args[0].get_base_dir()
	frame_root=output_root+"/frames"
	counts=manifest.counts
	for motion in counts: counts[motion]=int(counts[motion])
	root.title = "%s 애니메이션 미리보기"%manifest.slug
	root.size = Vector2i(1000,800)
	root.min_size = Vector2i(760,650)
	var usable := DisplayServer.screen_get_usable_rect()
	root.position = usable.position + (usable.size-root.size)/2
	var background := ColorRect.new()
	background.color = Color("151711")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+edge,20)
	var theme := Theme.new()
	var font := preload("res://assets/fonts/nanum_gothic_regular.ttf")
	theme.default_font = font
	theme.default_font_size = 18
	margin.theme = theme
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "%s · 애니메이션 검토 후보"%manifest.slug
	heading.add_theme_font_size_override("font_size",25)
	column.add_child(heading)
	load_label = Label.new()
	load_label.text = "이미지 준비 중…"
	column.add_child(load_label)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",10)
	column.add_child(controls)
	for entry in [["attack","공격"],["hit","피격"],["death","사망"]]:
		var button := Button.new()
		button.text = entry[1]
		button.custom_minimum_size = Vector2(100,40)
		button.pressed.connect(select_kind.bind(entry[0]))
		controls.add_child(button)
		tabs[entry[0]] = button
	pause_button = Button.new()
	pause_button.text = "일시정지"
	pause_button.custom_minimum_size = Vector2(110,40)
	pause_button.pressed.connect(toggle_playing)
	controls.add_child(pause_button)
	var speeds := OptionButton.new()
	for value in [5,10,15]: speeds.add_item("%d FPS"%value)
	speeds.select(1)
	speeds.item_selected.connect(func(index: int): speed=[5.0,10.0,15.0][index];schedule())
	controls.add_child(speeds)
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("20231c")
	style.border_color = Color("66573d")
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel",style)
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(picture)
	var navigation := HBoxContainer.new()
	column.add_child(navigation)
	var prev := Button.new()
	prev.text = "◀ 이전"
	prev.pressed.connect(step.bind(-1))
	navigation.add_child(prev)
	frame_label = Label.new()
	frame_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	navigation.add_child(frame_label)
	var next := Button.new()
	next.text = "다음 ▶"
	next.pressed.connect(step.bind(1))
	navigation.add_child(next)
	var note := Label.new()
	note.text = "검토용 독립 창 · 기존 게임 자산 유지 · 일시정지 후 한 장씩 확인 가능"
	note.add_theme_font_size_override("font_size",15)
	column.add_child(note)
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(advance)
	root.add_child(timer)
	for entry in counts:
		frames[entry]=[]
		for i in counts[entry]:
			var path: String=frame_root+"/%s-%02d.png"%[entry,i+1]
			var image := Image.load_from_file(path)
			if image == null:
				load_label.text = "이미지를 읽지 못했어: "+path
				push_error(load_label.text)
				return
			frames[entry].append(ImageTexture.create_from_image(image))
			if entry=="attack" and i==0: picture.texture=frames[entry][0]
			await process_frame
	load_label.text = "공격 %d장 · 피격 %d장 · 사망 %d장 | 기본 자세 높이 %dpx"%[counts.attack,counts.hit,counts.death,manifest.body_height]
	refresh()
	schedule()
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	if screenshot != null:
		screenshot.save_png(output_root+"/native_preview_check.png")
	print("NATIVE_PREVIEW_READY ",manifest.slug," counts=",counts," window=",root.size)

func refresh() -> void:
	if not frames.has(kind) or frames[kind].size()<=current: return
	picture.texture=frames[kind][current]
	frame_label.text="%s %d / %d"%[{"attack":"공격","hit":"피격","death":"사망"}[kind],current+1,counts[kind]]
	for key in tabs: tabs[key].modulate=Color("e4c385") if key==kind else Color.WHITE

func schedule() -> void:
	if timer == null: return
	timer.stop()
	if playing and frames.has(kind) and frames[kind].size()==counts[kind]:
		timer.start(0.45 if current==counts[kind]-1 else 1.0/speed)

func select_kind(value: String) -> void:
	kind=value
	current=0
	refresh()
	schedule()

func advance() -> void:
	current=(current+1)%counts[kind]
	refresh()
	schedule()

func toggle_playing() -> void:
	playing=not playing
	pause_button.text="일시정지" if playing else "재생"
	schedule()

func step(direction: int) -> void:
	playing=false
	pause_button.text="재생"
	current=posmod(current+direction,counts[kind])
	refresh()
	schedule()
