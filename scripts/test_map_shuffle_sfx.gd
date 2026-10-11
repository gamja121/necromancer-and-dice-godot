extends SceneTree
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_sfx.gd
## Verify phase cues, independent SFX bus/mute and rollback cleanup.
const Layout = preload("res://systems/map_shuffle_layout.gd")
const Gather = preload("res://systems/map_shuffle_gather.gd")
const MapState = preload("res://systems/map_state.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS shuffle-sfx: ", label)
	else:
		failed += 1
		printerr("FAIL shuffle-sfx: ", label)


func colored_texture(color: Color) -> ImageTexture:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _run() -> void:
	var old := colored_texture(Color(0.6, 0.4, 0.7))
	var stage := Control.new()
	stage.size = Vector2(1280.0, 720.0)
	root.add_child(stage)
	var buttons: Array = []
	var map_centers: Array = MapState.centers()
	for i in range(Layout.BOARD_TILE_COUNT):
		var tile := TextureButton.new()
		tile.texture_normal = old
		tile.ignore_texture_size = true
		tile.size = Layout.TILE_SIZE
		tile.position = map_centers[i] * Vector2(12.8, 7.2) - tile.size * 0.5
		stage.add_child(tile)
		buttons.append(tile)
	var dice := TextureButton.new()
	dice.texture_normal = old
	dice.position = Vector2(602.0, 307.6)
	dice.size = Vector2(76.0, 76.0)
	stage.add_child(dice)
	var changed: Array = []
	for i in range(Layout.BOARD_TILE_COUNT):
		changed.append(old if i in Layout.FIXED_INDICES else colored_texture(Color(float(i) / 24.0, 0.4, 0.3)))
	var shuffle := Gather.new()
	stage.add_child(shuffle)
	var bus_index: int = AudioServer.get_bus_index("SFX")
	check(bus_index >= 0, "SFX audio bus exists")
	check(shuffle.cue_players.size() == 3, "exactly three reusable audio players")
	check(shuffle.played_audio_cues.is_empty(), "no sound on entering the map")
	var streams_match: bool = true
	var gains_safe: bool = true
	for kind in ["gather", "rotate", "land"]:
		var player: AudioStreamPlayer = shuffle.cue_players[kind]
		if player.bus != "SFX" or player.stream == null:
			streams_match = false
		if player.volume_db > -19.0 or player.pitch_scale > 1.0 or player.max_polyphony != 1:
			gains_safe = false
	check(streams_match, "all cues use owned assets and SFX bus, not Music")
	check(gains_safe, "no cue is loud, sharp or high-pitched")

	check(shuffle.prepare(buttons), "prepare original board")
	await shuffle.play_rotation()
	check(shuffle.played_audio_cues.is_empty(), "no rotation cue before gathering")

	# Muting SFX must not mute Music or Master or change user preferences.
	var old_sfx_mute: bool = AudioServer.is_bus_mute(bus_index)
	var music_index: int = AudioServer.get_bus_index("Music")
	var old_music_mute: bool = AudioServer.is_bus_mute(music_index)
	var old_master_mute: bool = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(bus_index, true)
	var gather_started: int = Time.get_ticks_msec()
	await shuffle.play_gather()
	check(shuffle.played_audio_cues == ["gather"], "one soft gather cue across all 21 tiles")
	check(shuffle.active_sound_cue == "gather", "gather phase is the active audio cue")
	check(absi(int(shuffle.cue_timestamps_msec.get("gather", -999999)) - gather_started) <= 100, "gather sound starts with the shrink animation")
	var rotation_started: int = Time.get_ticks_msec()
	await shuffle.play_rotation()
	check(shuffle.played_audio_cues == ["gather", "rotate"], "one rotation cue, no individual tile clicks")
	check(shuffle.active_sound_cue == "rotate", "rotation replaces gather as active sound")
	check(absi(int(shuffle.cue_timestamps_msec.get("rotate", -999999)) - rotation_started) <= 100, "rotation sound starts with orbital motion")
	var gather_to_rotate: int = int(shuffle.cue_timestamps_msec["rotate"]) - int(shuffle.cue_timestamps_msec["gather"])
	check(gather_to_rotate >= 490 and gather_to_rotate <= 900, "gather-to-rotation sound gap tracks animation duration")
	check(AudioServer.is_bus_mute(bus_index), "SFX mute remains active through transition")
	check(AudioServer.is_bus_mute(music_index) == old_music_mute and AudioServer.is_bus_mute(0) == old_master_mute, "Music and Master mute unchanged")
	AudioServer.set_bus_mute(bus_index, old_sfx_mute)
	check(dice.position == Vector2(602.0, 307.6) and dice.texture_normal == old, "dice face and position unchanged")

	# Watch for the single landing cue after the spread reaches its slots.
	var sampled: Dictionary = {"seen": false, "ordered": false, "landing_gap": -1, "active": false}
	var scatter_started: int = Time.get_ticks_msec()
	create_timer(Gather.SCATTER_DURATION + 0.055).timeout.connect(func():
		sampled["seen"] = true
		sampled["ordered"] = shuffle.played_audio_cues == ["gather", "rotate", "land"]
		sampled["active"] = shuffle.active_sound_cue == "land"
		sampled["landing_gap"] = int(shuffle.cue_timestamps_msec.get("land", -999999)) - scatter_started
	)
	var ok: bool = await shuffle.play_scatter(changed, true)
	check(ok, "saved board reveal completes")
	check(bool(sampled["seen"]) and bool(sampled["ordered"]), "landing cue plays once after spread, before cards reveal")
	check(bool(sampled["active"]), "landing is the only active phase after scatter")
	check(int(sampled["landing_gap"]) >= 410 and int(sampled["landing_gap"]) <= 800, "landing sound begins at end of scatter, not per tile")
	check(shuffle.played_audio_cues.is_empty() and shuffle.active_sound_cue.is_empty() and shuffle.cue_timestamps_msec.is_empty(), "audio state cleared after map reconstruction")
	var silent: bool = true
	for player in shuffle.cue_players.values():
		if player.playing:
			silent = false
	check(silent, "no audio player left playing after successful completion")
	check(buttons.all(func(t): return t.visible), "all original gameplay tiles shown")

	check(shuffle.prepare(buttons), "reusable shuffle prepares for failure case")
	await shuffle.play_gather()
	await shuffle.play_rotation()
	check(shuffle.played_audio_cues == ["gather", "rotate"], "failure case has no landing cue before save")
	var refused: bool = await shuffle.play_scatter(changed, false)
	check(not refused, "save failure refuses revealing changed map")
	check(shuffle.played_audio_cues.is_empty(), "save failure clears pending audio cues")
	check(shuffle.active_sound_cue.is_empty() and shuffle.cue_timestamps_msec.is_empty(), "save failure clears active stage and timing markers")
	silent = true
	for player in shuffle.cue_players.values():
		if player.playing:
			silent = false
	check(silent, "no sounds linger after failed save")
	check(buttons.all(func(t): return t.visible), "failed save restores original tiles")
	check(dice.texture_normal == old, "dice face stays unchanged on failed save")

	shuffle.queue_free()
	stage.queue_free()
	print("MAP_SHUFFLE_SFX: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
