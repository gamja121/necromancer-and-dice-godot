extends Control
## One heavy cog-notch around the 21 nonfixed map slots. The travelling
## stone face IS the saved destination face; never replace art on landing.
## Original home/village/fortune slots and the gameplay die stay still.
const Layout = preload("res://systems/map_shuffle_layout.gd")
const StoneInertia = preload("res://systems/map_shuffle_gather.gd")
const AudioSettings = preload("res://systems/audio_settings.gd")
const MOVE_SFX = preload("res://assets/battle/sfx/move.ogg")
const LAND_SFX = preload("res://assets/battle/sfx/heavy.ogg")
const NOTCH_DURATION = 1.12
const START_RESISTANCE = 0.10
const SETTLE_DURATION = 0.12
const BOARD_CENTER = Vector2(640.0,345.6)
const STONE_OFFSET = Vector2(3.0,6.0)
var sources: Array[TextureButton] = []
var original_visibility: Array[bool] = []
var visuals: Array[TextureRect] = []
var starts: Array[Vector2] = []
var destinations: Array[Vector2] = []
var source_indices: Array[int] = []
var target_indices: Array[int] = []
var rotation_tween: Tween
var finished: bool = false
var last_progress: float = 0.0
var click_sounds: Array[AudioStreamPlayer] = []

## Keeping as many shifted originals as possible respects the generated
## board's exact per-type counts. Only real rule changes (new graveyard,
## patrol deltas, corruption monster conversion, boss slot 23) need a new face.
## The returned board is persisted in the same atomic leave-home save.
static func compose_board(previous: Array, generated: Array) -> Array:
	if previous.size()!=Layout.BOARD_TILE_COUNT or generated.size()!=Layout.BOARD_TILE_COUNT:
		return generated.duplicate()
	var indices: Array[int] = Layout.moving_indices()
	for fixed in Layout.FIXED_INDICES:
		if previous[fixed]!=generated[fixed]:
			return generated.duplicate()
	var result: Array = generated.duplicate()
	var remaining: Dictionary = {}
	var shifted: Dictionary = {}
	for i in range(indices.size()):
		var dest: int = indices[(i+1)%indices.size()]
		shifted[dest] = str(previous[indices[i]])
		var kind: String = str(generated[dest])
		remaining[kind] = int(remaining.get(kind,0))+1
	# The boss always occupies the dedicated last board cell; do not
	# propagate an old boss into ordinary numbered squares on later laps.
	var reserved: Dictionary = {}
	if str(generated[23])=="boss":
		result[23]="boss"
		remaining["boss"]=int(remaining["boss"])-1
		reserved[23]=true
	var unresolved: Array[int] = []
	for dest in indices:
		if reserved.has(dest): continue
		var kind: String = str(shifted[dest])
		if kind!="boss" and int(remaining.get(kind,0))>0:
			result[dest]=kind
			remaining[kind]=int(remaining[kind])-1
		else:
			unresolved.append(dest)
	for dest in unresolved:
		var picked: String = str(generated[dest])
		if int(remaining.get(picked,0))<=0:
			for candidate in indices:
				var candidate_type: String = str(generated[candidate])
				if int(remaining.get(candidate_type,0))>0:
					picked=candidate_type
					break
		result[dest]=picked
		remaining[picked]=int(remaining.get(picked,0))-1
	return result

static func changed_count(previous: Array, planned: Array) -> int:
	if previous.size()!=Layout.BOARD_TILE_COUNT or planned.size()!=Layout.BOARD_TILE_COUNT: return -1
	var indices: Array[int]=Layout.moving_indices()
	var changed: int=0
	for i in range(indices.size()):
		if previous[indices[i]]!=planned[indices[(i+1)%indices.size()]]:
			changed+=1
	return changed

func _ready() -> void:
	name="SingleNotchTileGear"
	size=Vector2(1280,720)
	z_index=3
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	AudioSettings.ensure_buses()
	for sound in [MOVE_SFX,LAND_SFX]:
		var player:=AudioStreamPlayer.new()
		player.bus="SFX"
		player.stream=sound
		player.max_polyphony=1
		player.volume_db=-25.0 if click_sounds.is_empty() else -19.0
		player.pitch_scale=0.70 if click_sounds.is_empty() else 0.73
		add_child(player)
		click_sounds.append(player)

func _sound(id: int) -> void:
	if DisplayServer.get_name()=="headless" or id>=click_sounds.size(): return
	click_sounds[id].play()

func prepare(buttons: Array, destination_textures: Array) -> bool:
	if get_parent()==null or not visuals.is_empty(): return false
	if buttons.size()!=Layout.BOARD_TILE_COUNT or destination_textures.size()!=Layout.BOARD_TILE_COUNT: return false
	var moving: Array[int] = Layout.moving_indices()
	for i in range(Layout.BOARD_TILE_COUNT):
		if not buttons[i] is TextureButton or not destination_textures[i] is Texture2D: return false
		if not is_instance_valid(buttons[i]) or buttons[i].texture_normal==null or buttons[i].get_parent()!=get_parent(): return false
	for fixed in Layout.FIXED_INDICES:
		if destination_textures[fixed]!=buttons[fixed].texture_normal: return false
	for i in range(moving.size()):
		var origin: int=moving[i]
		var dest: int=moving[(i+1)%moving.size()]
		var source: TextureButton=buttons[origin]
		var visual:=TextureRect.new()
		visual.name="OneNotchTile_%d_to_%d" % [origin,dest]
		visual.texture=destination_textures[dest]
		visual.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		visual.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		visual.mouse_filter=Control.MOUSE_FILTER_IGNORE
		visual.size=source.size
		visual.position=source.position
		visual.pivot_offset=visual.size*0.5
		# Small contact shadow travels with each heavy slab.
		var shadow:=TextureRect.new()
		shadow.texture=visual.texture
		shadow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shadow.size=source.size
		shadow.position=STONE_OFFSET
		shadow.modulate=Color(0.03,0.02,0.03,0.23)
		shadow.mouse_filter=Control.MOUSE_FILTER_IGNORE
		shadow.show_behind_parent=true
		visual.add_child(shadow)
		add_child(visual)
		sources.append(source)
		original_visibility.append(source.visible)
		source.visible=false
		visuals.append(visual)
		source_indices.append(origin)
		target_indices.append(dest)
		starts.append(source.position)
		destinations.append(buttons[dest].position)
	return true

func _apply_notch(time_fraction: float) -> void:
	# Existing stone flywheel has a continuous slow-start / firm brake curve.
	var progress: float=StoneInertia.stone_rotation_progress(time_fraction)
	last_progress=progress
	for i in range(visuals.size()):
		var visual: TextureRect=visuals[i]
		var start_center: Vector2=starts[i]+visual.size*0.5
		var end_center: Vector2=destinations[i]+visual.size*0.5
		var center: Vector2=start_center.lerp(end_center,progress)
		# Tiny outward lift feels like meshing gear teeth, never another
		# full orbit; at t=1 the tile is EXACTLY at its saved destination.
		var radial: Vector2=(start_center+end_center)*0.5-BOARD_CENTER
		if radial.length()>0.01:
			center+=radial.normalized()*5.0*sin(progress*PI)
		visual.position=center-visual.size*0.5

func play_once() -> void:
	if visuals.size()!=Layout.INNER_COUNT+Layout.OUTER_COUNT or rotation_tween!=null: return
	_sound(0)
	rotation_tween=create_tween()
	rotation_tween.tween_interval(START_RESISTANCE)
	rotation_tween.tween_method(_apply_notch,0.0,1.0,NOTCH_DURATION).set_trans(Tween.TRANS_LINEAR)
	await rotation_tween.finished
	_apply_notch(1.0)
	_sound(1)
	await get_tree().create_timer(SETTLE_DURATION).timeout
	finished=true

func clean_up() -> void:
	if rotation_tween!=null and rotation_tween.is_running(): rotation_tween.kill()
	for i in range(sources.size()):
		if is_instance_valid(sources[i]): sources[i].visible=original_visibility[i]
	for visual in visuals:
		if is_instance_valid(visual): visual.queue_free()
	visuals.clear()
	sources.clear()
	original_visibility.clear()
	starts.clear()
	destinations.clear()
	source_indices.clear()
	target_indices.clear()

func _exit_tree() -> void:
	for i in range(sources.size()):
		if is_instance_valid(sources[i]): sources[i].visible=original_visibility[i]
