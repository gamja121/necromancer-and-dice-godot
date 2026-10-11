extends Control
## Steps 2 and 3: gather the 21 movable map tiles, then counter-rotate
## their two separate orbits. No game rules, dice results or saves change.
## This is not wired into the live home-exit transition until later steps.

const Layout = preload("res://systems/map_shuffle_layout.gd")
const SHRINK_DURATION = 0.12
const TRAVEL_DURATION = 0.43
const ROTATE_DURATION = 0.85

var tile_sources: Array[TextureButton] = []
var source_visibility: Array[bool] = []
var tile_visuals: Array[TextureRect] = []
var slots: Array[Dictionary] = []
var gathering: Tween
var rotation_tween: Tween
var gathered := false
var rotated := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 3 # Static tiles (4), hero (16), and dice (19) remain visible above.
	size = Vector2(1280.0, 720.0)


## Parent this Control to the existing map.stage before calling prepare().
## The clones share stage coordinates with the map's real tile buttons.
func prepare(tile_buttons: Array) -> bool:
	if get_parent() == null or not tile_visuals.is_empty():
		return false
	if tile_buttons.size() != Layout.BOARD_TILE_COUNT:
		return false
	var target_slots: Array[Dictionary] = Layout.ring_slots()
	# Validate the entire input before hiding or cloning anything.
	for slot in target_slots:
		var source := tile_buttons[int(slot["tile_index"])] as TextureButton
		if source == null or not is_instance_valid(source):
			return false
		if source.get_parent() != get_parent() or source.texture_normal == null:
			return false
	slots = target_slots
	for slot in slots:
		var source: TextureButton = tile_buttons[int(slot["tile_index"])]
		var visual := TextureRect.new()
		visual.texture = source.texture_normal
		visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.size = source.size
		visual.pivot_offset = visual.size * 0.5
		visual.position = source.position
		add_child(visual)
		tile_sources.append(source)
		source_visibility.append(source.visible)
		tile_visuals.append(visual)
		source.visible = false
	return true


## At the end, cloned tiles remain at the beginning of their respective orbits.
## Step 3 rotates the same temporary visuals; step 4 will redistribute them.
func play_gather() -> void:
	if tile_visuals.size() != Layout.INNER_COUNT + Layout.OUTER_COUNT:
		return
	if gathering != null and gathering.is_running():
		return
	# Shrink in place first. Keeping the tiles small during travel avoids
	# crossing/stacking that would occur if 21 full-size tiles moved at once.
	gathering = create_tween().set_parallel(true)
	for i in range(tile_visuals.size()):
		var visual: TextureRect = tile_visuals[i]
		gathering.tween_property(visual, "scale", Vector2.ONE * float(slots[i]["scale"]), SHRINK_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await gathering.finished
	gathering = create_tween().set_parallel(true)
	for i in range(tile_visuals.size()):
		var visual: TextureRect = tile_visuals[i]
		var destination: Vector2 = Layout.orbit_position(slots[i], 0.0) - visual.size * 0.5
		gathering.tween_property(visual, "position", destination, TRAVEL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await gathering.finished
	if tile_visuals.size() == slots.size():
		gathered = true


## Clockwise inner orbit (+210 deg), counterclockwise outer orbit (-250 deg).
## Only centers orbit around the unchanged dice; sprites themselves stay upright.
## Calling before gathering, while spinning, or twice after completion is a no-op.
func play_rotation() -> void:
	if not gathered or rotated or tile_visuals.size() != Layout.INNER_COUNT + Layout.OUTER_COUNT:
		return
	if rotation_tween != null and rotation_tween.is_running():
		return
	rotation_tween = create_tween()
	rotation_tween.tween_method(_apply_rotation_progress, 0.0, 1.0, ROTATE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await rotation_tween.finished
	if tile_visuals.size() == slots.size():
		_apply_rotation_progress(1.0)
		rotated = true


func _apply_rotation_progress(progress: float) -> void:
	for i in range(tile_visuals.size()):
		var visual: TextureRect = tile_visuals[i]
		if is_instance_valid(visual):
			visual.position = Layout.orbit_position(slots[i], progress) - visual.size * 0.5


func restore_tiles() -> void:
	if gathering != null and gathering.is_running():
		gathering.kill()
	if rotation_tween != null and rotation_tween.is_running():
		rotation_tween.kill()
	for i in range(tile_sources.size()):
		if is_instance_valid(tile_sources[i]):
			tile_sources[i].visible = source_visibility[i]
	for visual in tile_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	tile_sources.clear()
	source_visibility.clear()
	tile_visuals.clear()
	slots.clear()
	gathering = null
	rotation_tween = null
	gathered = false
	rotated = false


func _exit_tree() -> void:
	# If a transition is aborted, never leave the original board invisible.
	for i in range(tile_sources.size()):
		if is_instance_valid(tile_sources[i]):
			tile_sources[i].visible = source_visibility[i]
