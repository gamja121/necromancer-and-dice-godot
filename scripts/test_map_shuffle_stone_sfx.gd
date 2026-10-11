extends SceneTree
## Stone shuffle stage 5: asset reuse, quiet weighted SFX, floor-contact timing.
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_stone_sfx.gd
const Layout = preload("res://systems/map_shuffle_layout.gd")
const Gather = preload("res://systems/map_shuffle_gather.gd")
const MapState = preload("res://systems/map_state.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS stone-sfx: ", description)
	else:
		failed += 1
		printerr("FAIL stone-sfx: ", description)


func texture_for() -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.48, 0.43, 0.38))
	return ImageTexture.create_from_image(img)


func _run() -> void:
	var scene := Control.new()
	scene.size = Vector2(1280, 720)
	root.add_child(scene)
	var art: Texture2D = texture_for()
	var tiles: Array = []
	var centers: Array = MapState.centers()
	for i in range(Layout.BOARD_TILE_COUNT):
		var tile := TextureButton.new()
		tile.ignore_texture_size = true
		tile.size = Layout.TILE_SIZE
		tile.texture_normal = art
		tile.position = centers[i] * Vector2(12.8, 7.2) - tile.size * 0.5
		scene.add_child(tile)
		tiles.append(tile)
	var saved_faces: Array = []
	for i in range(Layout.BOARD_TILE_COUNT):
		saved_faces.append(art if i in Layout.FIXED_INDICES else texture_for())

	var shuffle := Gather.new()
	scene.add_child(shuffle)
	check(shuffle.cue_players.size() == 3, "three reusable players, not 21 per-stone audio nodes")
	check(Gather.GATHER_SFX.resource_path.ends_with("/move.ogg"), "gather uses existing CC0 move sound")
	check(Gather.ROTATION_SFX.resource_path.ends_with("/magic.ogg"), "rotate reuses existing CC0 magic sound")
	check(Gather.LANDING_SFX.resource_path.ends_with("/heavy.ogg"), "landing reuses the existing heavy impact asset")
	check(Gather.SOUND_PRESETS["gather"]["pitch"] < 0.85, "gather has lowered stone-scrape pitch")
	check(Gather.SOUND_PRESETS["rotate"]["pitch"] < 0.80, "rotation has lowered grinding pitch")
	check(Gather.SOUND_PRESETS["land"]["pitch"] < 0.85, "heavy impact is slowed and deepened")
	var bus_index: int = AudioServer.get_bus_index("SFX")
	var music_index: int = AudioServer.get_bus_index("Music")
	check(bus_index >= 0 and music_index >= 0, "Master/Music/SFX buses present")
	var buses_correct := true
	var restrained := true
	for cue in ["gather", "rotate", "land"]:
		var player: AudioStreamPlayer = shuffle.cue_players[cue]
		if player.bus != "SFX" or player.stream == null or player.max_polyphony != 1:
			buses_correct = false
		if player.volume_db > -22.0 or player.pitch_scale > 0.85:
			restrained = false
	check(buses_correct, "all weighted audio uses SFX bus and prevents stacking")
	check(restrained, "all sound presets stay quiet and below normal pitch")

	var old_sfx: bool = AudioServer.is_bus_mute(bus_index)
	var old_music: bool = AudioServer.is_bus_mute(music_index)
	var old_master: bool = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(bus_index, true)
	check(shuffle.prepare(tiles), "full board prepares without changing audio preferences")
	await shuffle.play_gather()
	check(shuffle.played_audio_cues == ["gather"], "one scrape for gather, never one per tile")
	await shuffle.play_rotation()
	check(shuffle.played_audio_cues == ["gather", "rotate"], "one low grinding tone for both counterrotating rings")
	check(AudioServer.is_bus_mute(bus_index), "user SFX mute respected throughout stone rotation")
	check(AudioServer.is_bus_mute(music_index) == old_music and AudioServer.is_bus_mute(0) == old_master, "music and master mute unchanged")

	var recorded: Dictionary = {"early": false, "mid": false, "impact": false, "land_cues": 0}
	create_timer(Gather.SCATTER_DURATION + 0.06).timeout.connect(func():
		recorded["early"] = shuffle.played_audio_cues == ["gather", "rotate"]
	)
	create_timer(Gather.SCATTER_DURATION + Gather.DUST_IMPACT_OFFSET * 0.55).timeout.connect(func():
		recorded["mid"] = shuffle.played_audio_cues == ["gather", "rotate"]
	)
	create_timer(Gather.SCATTER_DURATION + Gather.DUST_IMPACT_OFFSET + 0.06).timeout.connect(func():
		recorded["impact"] = shuffle.played_audio_cues == ["gather", "rotate", "land"]
		recorded["land_cues"] = shuffle.played_audio_cues.count("land")
	)
	var revealed: bool = await shuffle.play_scatter(saved_faces, true)
	check(revealed, "saved world completes reveal")
	check(bool(recorded["early"]) and bool(recorded["mid"]), "no impact sound during approach or before tile floor contact")
	check(bool(recorded["impact"]) and int(recorded["land_cues"]) == 1, "single heavy thud plays at first real floor contact")
	check(shuffle.played_audio_cues.is_empty() and shuffle.active_sound_cue.is_empty(), "phase audio cleared after reveal")
	check(shuffle.cue_timestamps_msec.is_empty(), "no retained timing state across map laps")
	check(tiles.all(func(t): return t.visible), "all gameplay tiles visible after stone reveal")

	AudioServer.set_bus_mute(bus_index, old_sfx)
	check(shuffle.prepare(tiles), "same controller supports another round")
	await shuffle.play_gather()
	await shuffle.play_rotation()
	var failed_save: bool = await shuffle.play_scatter(saved_faces, false)
	check(not failed_save and shuffle.played_audio_cues.is_empty(), "failed save never plays heavy landing sound")
	check(shuffle.cue_players["land"].playing == false, "no heavy impact remains audible on rollback")
	check(shuffle.dust_centers.is_empty() and tiles.all(func(t): return t.visible), "failure restores board without landing effects")
	check(AudioServer.is_bus_mute(bus_index) == old_sfx, "saved SFX mute preference unchanged")

	scene.queue_free()
	print("MAP_SHUFFLE_STONE_SFX: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
