extends TextureRect
## A delayed, non-interactive pointer for the current player die.

const ARROW = preload("res://assets/cards/corpse-selection-arrow.png")
const WAIT_SECONDS := 3.0
const BOB_PERIOD := 1.36
const LIFT := 5.0
const GAP := 8.0

var die: TextureButton
var get_context: Callable
var context_id := 0
var ready_time := 0.0


func setup(target: TextureButton, context_provider: Callable) -> void:
	die = target
	get_context = context_provider
	name = "DicePressHint"
	texture = ARROW
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	size = Vector2(34,34)
	pivot_offset = size*0.5
	rotation = PI
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The global quit prompt pauses the game and freezes scaled time.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	die.get_parent().add_child(self)
	die.pressed.connect(reset_wait)


func reset_wait() -> void:
	context_id = 0
	ready_time = 0.0
	hide()


func _process(delta: float) -> void:
	if get_tree().paused or not is_instance_valid(die) or die.disabled or not die.is_visible_in_tree() or die.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		reset_wait()
		return
	var context: Node = get_context.call()
	if not is_instance_valid(context):
		reset_wait()
		return
	var current_id := context.get_instance_id()
	if current_id != context_id:
		reset_wait()
		context_id = current_id
	ready_time += delta
	if ready_time < WAIT_SECONDS: return
	var bounds: Rect2 = die.get_transform()*Rect2(Vector2.ZERO,die.size)
	var phase := (ready_time-WAIT_SECONDS)*TAU/BOB_PERIOD
	var lift := (1.0-cos(phase))*0.5*LIFT
	position = Vector2(bounds.get_center().x-size.x*0.5,bounds.position.y-size.y-GAP-lift)
	z_index = die.z_index+1
	show()
