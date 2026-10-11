extends Control
## Home-exit visual shuffle: gather, counter-rotate and reveal 21 tiles.
## All changes here are temporary visuals; gameplay/save state stays authoritative.

const Layout = preload("res://systems/map_shuffle_layout.gd")
const AudioSettings = preload("res://systems/audio_settings.gd")
# Reuse existing CC0 assets; the sound obeys the SFX and Master mute/volume.
const GATHER_SFX = preload("res://assets/battle/sfx/move.ogg")
const ROTATION_SFX = preload("res://assets/battle/sfx/magic.ogg")
const LANDING_SFX = preload("res://assets/battle/sfx/ui.ogg")
const SOUND_PRESETS = {
	"gather": {"volume_db": -23.0, "pitch": 0.92},
	"rotate": {"volume_db": -25.0, "pitch": 0.90},
	"land": {"volume_db": -20.0, "pitch": 0.88}
}
# Tiny resistance tremor before stone slabs leave their original sockets.
# Never displace the static map nodes or alter their saved positions.
const PREDEPARTURE_DURATION = 0.09
const PREDEPARTURE_AMPLITUDE = Vector2(0.8, 0.35)
const PREDEPARTURE_CYCLES = 3.0
const SHRINK_DURATION = 0.12
const TRAVEL_DURATION = 0.43
const ROTATE_DURATION = 0.85
# Stone flywheel: overcome initial inertia, maintain speed between rings,
# then apply a longer controlled brake. Fractions of ROTATE_DURATION.
const ROTATION_ACCEL_FRACTION = 0.20
const ROTATION_BRAKE_FRACTION = 0.30
const SCATTER_DURATION = 0.46
const FLIP_HALF_DURATION = 0.105
const FLIP_STAGGER = 0.008
const FLIP_EXPAND_DURATION = 0.135
const LANDING_LIFT = 4.0
const LANDING_DURATION = 0.14 # Heavy slab: accelerate downward, then stop without rebound.
# One lightweight canvas draw for 21 tiny impact puffs; no sprites, physics
# bodies, textures or per-grain nodes (suitable for mobile Web).
const DUST_GRAINS_PER_TILE = 4
const DUST_LIFETIME = 0.19
const DUST_IMPACT_OFFSET = FLIP_HALF_DURATION + LANDING_DURATION
const DUST_TOTAL_DURATION = DUST_IMPACT_OFFSET + (Layout.INNER_COUNT + Layout.OUTER_COUNT - 1) * FLIP_STAGGER + DUST_LIFETIME
const SHADOW_OFFSET = Vector2(4.0, 7.0)
const SHADOW_TINT = Color(0.035, 0.022, 0.045, 0.31)
# Faint magical focus only. The die face and position never animate.
const AURA_INNER_RADIUS = 48.0
const AURA_OUTER_RADIUS = 57.0
const AURA_FADE_IN = 0.35
const AURA_ROTATION_RISE = 0.26

var board_buttons: Array[TextureButton] = []
var tile_sources: Array[TextureButton] = []
var source_visibility: Array[bool] = []
var tile_visuals: Array[TextureRect] = []
var tile_shadows: Array[TextureRect] = []
var slots: Array[Dictionary] = []
var gathering: Tween
var predeparture_tween: Tween
var rotation_tween: Tween
var scatter_tween: Tween
var reveal_tween: Tween
var dust_tween: Tween
var dust_elapsed: float = -1.0
var dust_centers: Array[Vector2] = []
var gathered := false
var rotated := false
var aura_strength: float = 0.0
var aura_tween: Tween
var cue_players: Dictionary = {}
var played_audio_cues: Array[String] = []
var cue_timestamps_msec: Dictionary = {}
var active_sound_cue: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 3 # Static tiles (4), hero (16), and dice (19) remain visible above.
	size = Vector2(1280.0, 720.0)
	# Map._ready normally creates the buses. Ensure the same bus in
	# standalone scenes/tests without changing stored user preferences.
	AudioSettings.ensure_buses()
	for cue in SOUND_PRESETS.keys():
		var player := AudioStreamPlayer.new()
		player.name = "ShuffleSfx_%s" % cue
		player.bus = "SFX"
		player.volume_db = float(SOUND_PRESETS[cue]["volume_db"])
		player.pitch_scale = float(SOUND_PRESETS[cue]["pitch"])
		player.max_polyphony = 1
		match cue:
			"gather": player.stream = GATHER_SFX
			"rotate": player.stream = ROTATION_SFX
			"land": player.stream = LANDING_SFX
		add_child(player)
		cue_players[cue] = player


func _play_sound(cue: String) -> void:
	if not cue_players.has(cue):
		return
	# The three recorded stage starts match the actual visual phases.
	# Avoid layering effects when an older clip outlasts its phase.
	for previous in cue_players.values():
		if is_instance_valid(previous) and previous.playing:
			previous.stop()
	active_sound_cue = cue
	played_audio_cues.append(cue)
	cue_timestamps_msec[cue] = Time.get_ticks_msec()
	# Headless checks record the same phase markers without opening audio.
	# The SFX bus continues to own user mute and Master volume.
	if DisplayServer.get_name() == "headless":
		return
	var player: AudioStreamPlayer = cue_players[cue]
	player.play()


func _stop_sounds() -> void:
	for player in cue_players.values():
		if is_instance_valid(player):
			player.stop()
	active_sound_cue = ""
	cue_timestamps_msec.clear()
	played_audio_cues.clear()


func _draw() -> void:
	if aura_strength > 0.0:
		# Draw behind the real die (z19). Two narrow arcs and a soft center glow.
		draw_circle(Layout.DICE_CENTER, AURA_OUTER_RADIUS + 3.0, Color(0.47, 0.26, 0.75, 0.035 * aura_strength))
		draw_arc(Layout.DICE_CENTER, AURA_INNER_RADIUS, 0.0, TAU, 72, Color(0.76, 0.60, 1.0, 0.28 * aura_strength), 2.0, true)
		draw_arc(Layout.DICE_CENTER, AURA_OUTER_RADIUS, 0.0, TAU, 88, Color(0.59, 0.39, 0.89, 0.17 * aura_strength), 1.5, true)
	_draw_stone_dust()


## -1 means no burst is active. Tiles land in the existing index stagger.
static func dust_burst_fraction(elapsed: float, tile_index: int) -> float:
	if tile_index < 0 or tile_index >= Layout.INNER_COUNT + Layout.OUTER_COUNT:
		return -1.0
	var since_impact: float = elapsed - DUST_IMPACT_OFFSET - float(tile_index) * FLIP_STAGGER
	if since_impact < 0.0 or since_impact >= DUST_LIFETIME:
		return -1.0
	return since_impact / DUST_LIFETIME


func _set_dust_elapsed(elapsed: float) -> void:
	dust_elapsed = elapsed
	queue_redraw()


func _draw_stone_dust() -> void:
	if dust_elapsed < 0.0:
		return
	for i in range(dust_centers.size()):
		var fraction: float = dust_burst_fraction(dust_elapsed, i)
		if fraction < 0.0:
			continue
		# A low-opacity stone-grey puff pushes outward from both bottom
		# corners, then quickly fades. Avoid bright arcs and camera shake.
		var opacity: float = 0.23 * (1.0 - fraction) * minf(1.0, fraction * 12.0)
		var center: Vector2 = dust_centers[i]
		for grain in range(DUST_GRAINS_PER_TILE):
			var side: float = -1.0 if grain % 2 == 0 else 1.0
			var depth: float = float(grain / 2)
			var offset: Vector2 = Vector2(side * (55.0 + 7.0 * fraction + 3.0 * depth), -2.0 - 8.0 * fraction - depth * 2.0)
			draw_circle(center + offset, 1.5 * (1.0 - 0.45 * fraction), Color(0.53, 0.50, 0.46, opacity))
		# The short low ground kick suggests stone meeting solid ground.
		var impact_opacity: float = opacity * 0.55
		draw_line(center + Vector2(-48.0 - 5.0 * fraction, 2.0), center + Vector2(-40.0, 2.0), Color(0.43, 0.40, 0.37, impact_opacity), 1.0)
		draw_line(center + Vector2(40.0, 2.0), center + Vector2(48.0 + 5.0 * fraction, 2.0), Color(0.43, 0.40, 0.37, impact_opacity), 1.0)


func _set_aura_strength(value: float) -> void:
	aura_strength = clampf(value, 0.0, 1.0)
	queue_redraw()


func _aura_fade_in() -> void:
	if aura_tween != null and aura_tween.is_running():
		aura_tween.kill()
	aura_tween = create_tween()
	aura_tween.tween_method(_set_aura_strength, aura_strength, 0.60, AURA_FADE_IN)


func _aura_during_rotation() -> void:
	if aura_tween != null and aura_tween.is_running():
		aura_tween.kill()
	aura_tween = create_tween()
	aura_tween.tween_method(_set_aura_strength, aura_strength, 1.0, AURA_ROTATION_RISE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	aura_tween.tween_method(_set_aura_strength, 1.0, 0.65, ROTATE_DURATION - AURA_ROTATION_RISE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _aura_fade_out() -> void:
	if aura_tween != null and aura_tween.is_running():
		aura_tween.kill()
	aura_tween = create_tween()
	aura_tween.tween_method(_set_aura_strength, aura_strength, 0.0, SCATTER_DURATION).set_trans(Tween.TRANS_SINE)


## Parent this Control to the existing map.stage before calling prepare().
## The clones share stage coordinates with the map's real tile buttons.
func prepare(tile_buttons: Array) -> bool:
	if get_parent() == null or not tile_visuals.is_empty():
		return false
	if tile_buttons.size() != Layout.BOARD_TILE_COUNT:
		return false
	var target_slots: Array[Dictionary] = Layout.ring_slots()
	# Validate the entire input before hiding or cloning anything.
	for button in tile_buttons:
		var item := button as TextureButton
		if item == null or not is_instance_valid(item):
			return false
		if item.get_parent() != get_parent() or item.texture_normal == null:
			return false
	for slot in target_slots:
		var source := tile_buttons[int(slot["tile_index"])] as TextureButton
		if source == null or not is_instance_valid(source):
			return false
		if source.get_parent() != get_parent() or source.texture_normal == null:
			return false
	for button in tile_buttons:
		board_buttons.append(button as TextureButton)
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
		# A tinted copy of the original silhouette reads as a small contact
		# shadow without requiring additional imported images or real 3D.
		var shadow := TextureRect.new()
		shadow.name = "TileShadow"
		shadow.texture = source.texture_normal
		shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shadow.show_behind_parent = true
		shadow.size = visual.size
		shadow.position = SHADOW_OFFSET
		shadow.modulate = SHADOW_TINT
		visual.add_child(shadow)
		tile_shadows.append(shadow)
		tile_sources.append(source)
		source_visibility.append(source.visible)
		tile_visuals.append(visual)
		source.visible = false
	return true


## At the end, cloned tiles remain at the beginning of their respective orbits.
## Rotation and scatter use these same temporary images.
func play_gather() -> void:
	if tile_visuals.size() != Layout.INNER_COUNT + Layout.OUTER_COUNT:
		return
	if gathered or (gathering != null and gathering.is_running()) or (predeparture_tween != null and predeparture_tween.is_running()):
		return
	_aura_fade_in()
	_play_sound("gather")
	# The slab first resists the pull: 21 tiny alternating tremors fade
	# to exactly zero, then all cards shrink and travel along the old path.
	predeparture_tween = create_tween()
	predeparture_tween.tween_method(_apply_predeparture, 0.0, 1.0, PREDEPARTURE_DURATION)
	await predeparture_tween.finished
	_apply_predeparture(1.0)
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
		# Heavy acceleration from rest and then a controlled slowdown near
		# the inner/outer ring. Route and total travel time do not change.
		gathering.tween_property(visual, "position", destination, TRAVEL_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await gathering.finished
	if tile_visuals.size() == slots.size():
		gathered = true


func _apply_predeparture(progress: float) -> void:
	# Each cloned stone stays within one pixel of its original tile. The
	# sine envelope guarantees no offset remains when shrinking begins.
	var envelope: float = sin(PI * progress)
	var pulse: float = sin(TAU * PREDEPARTURE_CYCLES * progress) * envelope
	for i in range(tile_visuals.size()):
		var visual: TextureRect = tile_visuals[i]
		if is_instance_valid(visual) and is_instance_valid(tile_sources[i]):
			var direction: float = -1.0 if i % 2 == 0 else 1.0
			visual.position = tile_sources[i].position + Vector2(direction * PREDEPARTURE_AMPLITUDE.x * pulse, PREDEPARTURE_AMPLITUDE.y * pulse)


## Clockwise inner orbit (+210 deg), counterclockwise outer orbit (-250 deg).
## Only centers orbit around the unchanged dice; sprites themselves stay upright.
## Calling before gathering, while spinning, or twice after completion is a no-op.
func play_rotation() -> void:
	if not gathered or rotated or tile_visuals.size() != Layout.INNER_COUNT + Layout.OUTER_COUNT:
		return
	if rotation_tween != null and rotation_tween.is_running():
		return
	_aura_during_rotation()
	_play_sound("rotate")
	rotation_tween = create_tween()
	rotation_tween.tween_method(_apply_inertial_rotation_progress, 0.0, 1.0, ROTATE_DURATION).set_trans(Tween.TRANS_LINEAR)
	await rotation_tween.finished
	if tile_visuals.size() == slots.size():
		_apply_rotation_progress(1.0)
		rotated = true


## Integrated rotational velocity curve: zero initial speed, short smooth
## acceleration, constant angular travel in the middle, a longer smooth brake.
## A cosine-derived ramp keeps speed and acceleration continuous at joins.
## The normalized integral guarantees each ring still turns exactly its
## canonical +210 / -250 degrees in the original 0.85 seconds.
static func stone_rotation_progress(time_fraction: float) -> float:
	var t: float = clampf(time_fraction, 0.0, 1.0)
	var a: float = ROTATION_ACCEL_FRACTION
	var b: float = ROTATION_BRAKE_FRACTION
	var brake_start: float = 1.0 - b
	var area: float = 1.0 - 0.5 * (a + b)
	if t <= a:
		return clampf(0.5 * (t - a / PI * sin(PI * t / a)) / area, 0.0, 1.0)
	if t < brake_start:
		return (0.5 * a + t - a) / area
	var braking_time: float = t - brake_start
	var distance_before_brake: float = 0.5 * a + brake_start - a
	var braking_distance: float = 0.5 * (braking_time + b / PI * sin(PI * braking_time / b))
	return clampf((distance_before_brake + braking_distance) / area, 0.0, 1.0)


func _apply_inertial_rotation_progress(time_fraction: float) -> void:
	_apply_rotation_progress(stone_rotation_progress(time_fraction))


func _apply_rotation_progress(progress: float) -> void:
	for i in range(tile_visuals.size()):
		var visual: TextureRect = tile_visuals[i]
		if is_instance_valid(visual):
			visual.position = Layout.orbit_position(slots[i], progress) - visual.size * 0.5


## Called only AFTER RunSession.leave_home() has saved the new board.
## The caller must provide the saved board's 24 textures in tile-index order.
## A false persistence result always restores the old visuals without changes.
## This step does not yet replace map.gd's live cloud transition.
func play_scatter(next_tile_textures: Array, save_succeeded: bool) -> bool:
	if not rotated or tile_visuals.size() != Layout.INNER_COUNT + Layout.OUTER_COUNT:
		return false
	if scatter_tween != null or reveal_tween != null:
		return false
	if not save_succeeded or not _valid_next_tiles(next_tile_textures):
		restore_tiles()
		return false

	_aura_fade_out()
	# The source art travels toward the closest available destination; a
	# different tile image is chosen ONLY after arrival at that board slot.
	scatter_tween = create_tween().set_parallel(true)
	for i in range(tile_visuals.size()):
		var visual: TextureRect = tile_visuals[i]
		var destination_index: int = int(Layout.SCATTER_DESTINATIONS[i])
		var destination: Vector2 = board_buttons[destination_index].position
		scatter_tween.tween_property(visual, "position", destination, SCATTER_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await scatter_tween.finished
	_play_sound("land")
	# Dust is strictly visual, only after persistence has succeeded. All
	# 21 puffs are drawn in this one Control with a single time tween.
	dust_centers.clear()
	for i in range(tile_visuals.size()):
		var destination_index: int = int(Layout.SCATTER_DESTINATIONS[i])
		dust_centers.append(board_buttons[destination_index].position + Vector2(Layout.TILE_SIZE.x * 0.5, Layout.TILE_SIZE.y))
	dust_tween = create_tween()
	dust_tween.tween_method(_set_dust_elapsed, 0.0, DUST_TOTAL_DURATION, DUST_TOTAL_DURATION).set_trans(Tween.TRANS_LINEAR)

	# Stone slab landing: fall the final four pixels with accelerating
	# weight and stop firmly at the board. Neither position nor flip may
	# overshoot or bounce, as stone would feel rubbery.
	# Delay by tile index to preserve the existing staggered reveal.
	reveal_tween = create_tween().set_parallel(true)
	for i in range(tile_visuals.size()):
		var visual: TextureRect = tile_visuals[i]
		var shadow: TextureRect = tile_shadows[i]
		var destination_index: int = int(Layout.SCATTER_DESTINATIONS[i])
		var next_texture: Texture2D = next_tile_textures[destination_index]
		var delay: float = float(i) * FLIP_STAGGER
		var landing_y: float = visual.position.y
		visual.position.y -= LANDING_LIFT
		# Counter-shift the child shadow as the tile lifts: unlike the
		# card, its world-space contact point remains on the ground.
		shadow.position.y = SHADOW_OFFSET.y + LANDING_LIFT
		reveal_tween.tween_property(visual, "scale:x", 0.04, FLIP_HALF_DURATION).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		reveal_tween.tween_callback(_reveal_tile_face.bind(visual, shadow, next_texture)).set_delay(delay + FLIP_HALF_DURATION)
		reveal_tween.tween_property(visual, "scale", Vector2.ONE, FLIP_EXPAND_DURATION).set_delay(delay + FLIP_HALF_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		reveal_tween.tween_property(visual, "position:y", landing_y, LANDING_DURATION).set_delay(delay + FLIP_HALF_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Match the falling tile offset so its shadow stays anchored on
		# the board, instead of lifting and bouncing with the stone.
		reveal_tween.tween_property(shadow, "position:y", SHADOW_OFFSET.y, LANDING_DURATION).set_delay(delay + FLIP_HALF_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		reveal_tween.tween_property(shadow, "modulate:a", 0.0, LANDING_DURATION).set_delay(delay + FLIP_HALF_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await reveal_tween.finished
	# Allow the final small puff to dissolve before removing temporary
	# visuals. The world is already saved; gameplay is still input-locked.
	if dust_tween != null and dust_tween.is_running():
		await dust_tween.finished

	# Commit the already saved images to the formerly hidden buttons, then
	# remove the temporary cards. A later map.render() refreshes metadata.
	for i in range(tile_visuals.size()):
		var destination_index: int = int(Layout.SCATTER_DESTINATIONS[i])
		board_buttons[destination_index].texture_normal = next_tile_textures[destination_index]
	restore_tiles()
	return true


func _reveal_tile_face(visual: TextureRect, shadow: TextureRect, new_face: Texture2D) -> void:
	visual.texture = new_face
	shadow.texture = new_face


func _valid_next_tiles(next_tile_textures: Array) -> bool:
	if next_tile_textures.size() != Layout.BOARD_TILE_COUNT:
		return false
	if board_buttons.size() != Layout.BOARD_TILE_COUNT:
		return false
	for i in range(next_tile_textures.size()):
		if not next_tile_textures[i] is Texture2D:
			return false
	for fixed_index in Layout.FIXED_INDICES:
		if next_tile_textures[fixed_index] != board_buttons[fixed_index].texture_normal:
			return false
	return true

func restore_tiles() -> void:
	_stop_sounds()
	if dust_tween != null and dust_tween.is_running():
		dust_tween.kill()
	dust_tween = null
	dust_elapsed = -1.0
	dust_centers.clear()
	queue_redraw()
	if aura_tween != null and aura_tween.is_running():
		aura_tween.kill()
	aura_tween = null
	_set_aura_strength(0.0)
	if predeparture_tween != null and predeparture_tween.is_running():
		predeparture_tween.kill()
	if gathering != null and gathering.is_running():
		gathering.kill()
	if rotation_tween != null and rotation_tween.is_running():
		rotation_tween.kill()
	if scatter_tween != null and scatter_tween.is_running():
		scatter_tween.kill()
	if reveal_tween != null and reveal_tween.is_running():
		reveal_tween.kill()
	for i in range(tile_sources.size()):
		if is_instance_valid(tile_sources[i]):
			tile_sources[i].visible = source_visibility[i]
	for visual in tile_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	board_buttons.clear()
	tile_sources.clear()
	source_visibility.clear()
	tile_visuals.clear()
	tile_shadows.clear()
	slots.clear()
	predeparture_tween = null
	gathering = null
	rotation_tween = null
	scatter_tween = null
	reveal_tween = null
	gathered = false
	rotated = false


func _exit_tree() -> void:
	_stop_sounds()
	if dust_tween != null and dust_tween.is_running():
		dust_tween.kill()
	dust_centers.clear()
	# If a transition is aborted, never leave the original board invisible.
	for i in range(tile_sources.size()):
		if is_instance_valid(tile_sources[i]):
			tile_sources[i].visible = source_visibility[i]
