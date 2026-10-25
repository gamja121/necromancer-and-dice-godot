extends "res://systems/event_discovery_card.gd"
## Routine parchment omits reward UI and places its explicit choices beside the card.
signal chosen(choice: String)
var choosing: bool = false

func _gui_input(_event: InputEvent) -> void:
	# A routine choice cannot be dismissed as a free, unsaved reward.
	pass

func setup_routine(entry: Dictionary, reward_picture: String) -> void:
	super.setup("루틴 사건",str(entry.title),str(entry.description),
		str(entry.reward),str(entry.illustration),reward_picture,false)
	name = "RoutineEventCard"
	get_node("EventDiscoveryDismissHint").hide()
	_make_choice("RoutineAccept",str(entry.action),Vector2(500,213),"take")
	_make_choice("RoutineDecline",str(entry.decline),Vector2(500,289),"skip")
	get_node("RoutineAccept").focus_neighbor_bottom=NodePath("../RoutineDecline")
	get_node("RoutineDecline").focus_neighbor_top=NodePath("../RoutineAccept")

func _make_choice(node_name: String, caption: String, pos: Vector2, choice: String) -> void:
	var option := Button.new()
	option.name = node_name
	option.text = caption
	option.position = pos
	option.size = Vector2(250,58)
	option.mouse_filter = Control.MOUSE_FILTER_STOP
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#50301d")
	normal.border_color = Color("#b99c65")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(5)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("#714629")
	option.add_theme_stylebox_override("normal",normal)
	option.add_theme_stylebox_override("hover",hover)
	option.add_theme_color_override("font_color",Color("#ffe7b7"))
	option.add_theme_font_override("font",preload("res://assets/fonts/nanum_gothic_regular.ttf"))
	option.add_theme_font_size_override("font_size",20)
	add_child(option)
	option.pressed.connect(func():
		if choosing: return
		choosing = true
		get_node("RoutineAccept").disabled=true
		get_node("RoutineDecline").disabled=true
		chosen.emit(choice))

func allow_retry() -> void:
	choosing = false
	get_node("RoutineAccept").disabled=false
	get_node("RoutineDecline").disabled=false
