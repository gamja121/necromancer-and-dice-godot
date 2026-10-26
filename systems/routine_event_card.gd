extends "res://systems/event_discovery_card.gd"
## Routine parchment omits reward UI and places its explicit choices beside the card.
signal chosen(choice: String)
var choosing: bool = false
const CHOICE_ART="res://assets/map/ui/routine_choice_button_v1.png"
var choice_backplate: AtlasTexture

func _gui_input(_event: InputEvent) -> void:
	# A routine choice cannot be dismissed as a free, unsaved reward.
	pass

func setup_routine(entry: Dictionary, reward_picture: String) -> void:
	super.setup("일반 사건",str(entry.title),str(entry.description),
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
	# The image's transparent canvas is trimmed at runtime; the original stays intact.
	if choice_backplate==null:
		var source: Texture2D=load(CHOICE_ART)
		choice_backplate=AtlasTexture.new()
		choice_backplate.atlas=source
		# Atlas selects the visible plaque; faint alpha noise outside is not part of the button.
		choice_backplate.region=Rect2(29,221,2131,273)
		choice_backplate.filter_clip=true
	var colors: Dictionary={
		"normal":Color.WHITE,
		"hover":Color(1.06,1.04,0.99),
		"pressed":Color(0.85,0.80,0.69),
		"disabled":Color(0.72,0.70,0.65,0.78)}
	for state in colors:
		var look:=StyleBoxTexture.new()
		look.texture=choice_backplate
		look.modulate_color=colors[state]
		look.set_content_margin(SIDE_LEFT,24.0)
		look.set_content_margin(SIDE_RIGHT,24.0)
		look.set_content_margin(SIDE_TOP,8.0)
		look.set_content_margin(SIDE_BOTTOM,8.0)
		option.add_theme_stylebox_override(state,look)
	var focus:=StyleBoxFlat.new()
	focus.draw_center=false
	focus.border_color=Color("#d3af70")
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(3)
	option.add_theme_stylebox_override("focus",focus)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		option.add_theme_color_override(key,Color("#332316"))
	option.add_theme_color_override("font_disabled_color",Color("#655747"))
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
