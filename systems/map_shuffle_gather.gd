extends Control
## Step 2 only: visually gather the 21 movable map tiles into two distinct
## rings. No map state, randomness, dice result, or save data is modified.
## This is not wired into the live home-exit transition until later steps.

const Layout = preload("res://systems/map_shuffle_layout.gd")
const GATHER_DURATION = 0.47
const STAGGER = 0.025

var tile_sources: Array[TextureButton] = []
var source_visibility: Array[bool] = []
var tile_visuals: Array[TextureRect] = []
var slots: Array[Dictionary] = []
var gathering: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 7 # Above map tiles (4), below the hero (16) and dice (19).
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
## Step 3 will rotate these same visuals; step 4 will return them to the map.
func play_gather() -> void:
	if tile_visuals.size() != Layout.INNER_COUNT + Layout.OUTER_COUNT:
		return
	if gathering != null and gathering.is_running():
		return
	gathering = create_tween().set_parallel(true)
	for i in range(tile_visuals.size()):
		var visual: TextureRect = tile_visuals[i]
		var slot: Dictionary = slots[i]
		var destination: Vector2 = Layout.orbit_position(slot, 0.0) - visual.size * 0.5
		var destination_scale: Vector2 = Vector2.ONE * float(slot["scale"])
		var delay: float = float(i % 3) * STAGGER
		gathering.tween_property(visual, "position", destination, GATHER_DURATION).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		gathering.tween_property(visual, "scale", destination_scale, GATHER_DURATION).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await gathering.finished


func restore_tiles() -> void:
	if gathering != null and gathering.is_running():
		gathering.kill()
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


func _exit_tree() -> void:
	# If a transition is aborted, never leave the original board invisible.
	for i in range(tile_sources.size()):
		if is_instance_valid(tile_sources[i]):
			tile_sources[i].visible = source_visibility[i]
