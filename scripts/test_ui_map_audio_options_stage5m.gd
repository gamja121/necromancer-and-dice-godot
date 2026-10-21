extends SceneTree
## Stage 5M: frozen web compact OPTION controls, persistence and native extras.
const AudioOptions = preload("res://systems/audio_settings.gd")
const MapScene = preload("res://map.tscn")
const RunSessionScript = preload("res://systems/run_session.gd")
var passed: int = 0
var failed: int = 0
var test_file: String = ""

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ui-map-audio: ",label)
	else:
		failed += 1
		printerr("FAIL ui-map-audio: ",label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	AudioOptions.ensure_buses()
	test_file = "user://map_audio_stage5m_%d.cfg" % OS.get_process_id()
	if FileAccess.file_exists(test_file): DirAccess.remove_absolute(ProjectSettings.globalize_path(test_file))
	var music_bus = AudioServer.get_bus_index("Music")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	var original_music = AudioServer.is_bus_mute(music_bus)
	var original_sfx = AudioServer.is_bus_mute(sfx_bus)
	var original_master_mute = AudioServer.is_bus_mute(0)
	var original_master_volume = AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_mute(music_bus,false)
	AudioServer.set_bus_mute(sfx_bus,false)
	AudioServer.set_bus_mute(0,false)
	AudioServer.set_bus_volume_db(0,linear_to_db(1.0))
	var root_control = Control.new()
	root_control.size = Vector2(1280,720)
	root.add_child(root_control)
	var audio = AudioOptions.new()
	audio.save_file_path = test_file
	audio.setup(root_control)
	await process_frame
	check(audio.get_child(0)==audio.options_button and audio.options_button.name=="MapOptionsButton","existing map integration keeps original image button as first child")
	check(audio.panel.name=="MapAudioOptionsPanel" and not audio.panel.visible,"source OPTION panel starts hidden")
	check(audio.panel.position.distance_to(Vector2(995.84,82.8))<1.0,"source right 2.2%, top 11.5% placement")
	check(absf(audio.panel.size.x-256.0)<1.0,"source 20%-wide compact options panel")
	check(audio.panel.z_index==40 and audio.z_index==90,"source z-index 130 placed above the map only when open")
	check(audio.panel.get_theme_stylebox("panel") is StyleBoxTexture and (audio.panel.get_theme_stylebox("panel") as StyleBoxTexture).texture is ImageTexture,"popup uses uneven brush-stroke parchment instead of rectangular style box")
	check(audio.music_toggle.get_theme_stylebox("normal") is StyleBoxTexture and (audio.music_toggle.get_theme_stylebox("normal") as StyleBoxTexture).texture is ImageTexture,"music toggle has brush-painted border")
	check(audio.panel.get_node_or_null("AudioOptionsContent/MapAudioOptionsHeader/AudioOptionsTitle").text=="설정","hand-brushed Korean settings heading exists")
	check(audio.close_button.text=="×" and audio.close_button.custom_minimum_size==Vector2(28,28),"web 28px close control exists")
	check(audio.music_toggle.text=="ON" and audio.sfx_toggle.text=="ON","both web sound switches reflect live enabled state")
	check(audio.advanced_content!=null and not audio.advanced_content.visible,"automatic OS output and native master volume remain folded away")
	check(audio.options_button.pressed.is_connected(Callable(audio,"toggle_panel")),"map options button opens and closes working panel")
	audio.options_button.pressed.emit()
	check(audio.panel.visible,"source options opens after the original map button")
	audio.music_toggle.pressed.emit()
	check(AudioServer.is_bus_mute(music_bus) and audio.music_toggle.text=="OFF","BGM off affects real Music audio bus")
	check(not AudioServer.is_bus_mute(sfx_bus) and audio.sfx_toggle.text=="ON","independent SFX remains on when BGM disabled")
	var cfg = ConfigFile.new()
	check(cfg.load(test_file)==OK,"audio changes persist in test-only ConfigFile")
	check(not bool(cfg.get_value("audio","music_enabled",true)) and bool(cfg.get_value("audio","sfx_enabled",false)),"BGM off/SFX on saved independently")
	audio.sfx_toggle.pressed.emit()
	check(audio.sfx_toggle.text=="OFF" and AudioServer.is_bus_mute(sfx_bus),"SFX button independently disables real SFX bus")
	audio.advanced_button.pressed.emit()
	check(audio.advanced_content.visible and audio.output_label!=null and audio.volume_slider!=null,"system default output policy and master volume available under Advanced")
	check(audio.output_label.text.contains("시스템 기본") and audio.advanced_content.get_node_or_null("MapAudioOutputDevice")==null,"no device-specific selector can bind the game to this PC")
	# A previously saved Realtek preference must no longer control output or
	# survive a later write of regular volume/Music/SFX settings. Reload
	# latest toggles first: do not accidentally undo the just saved SFX OFF.
	check(cfg.load(test_file)==OK,"legacy output fixture reads latest music/SFX toggles")
	cfg.set_value("audio","output","Realtek")
	check(cfg.save(test_file)==OK,"legacy machine-specific output fixture stored")
	AudioOptions.apply_saved(test_file)
	audio.volume_slider.value=45
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(0))*100.0-45)<0.2,"advanced master volume still updates actual audio bus")
	check(cfg.load(test_file)==OK and absf(float(cfg.get_value("audio","volume",0))-0.45)<0.02,"native master volume persists while maintaining source toggles")
	var migrated_cfg = ConfigFile.new()
	check(migrated_cfg.load(test_file)==OK and not migrated_cfg.has_section_key("audio","output"),"new audio saves remove legacy machine-specific output device name")
	audio.advanced_button.pressed.emit()
	check(not audio.advanced_content.visible,"advanced fold closes without losing source switches")
	audio.close_button.pressed.emit()
	check(not audio.panel.visible,"web close X dismisses options without changing BGM/SFX")
	audio.options_button.pressed.emit()
	check(audio.panel.visible and audio.music_toggle.text=="OFF" and audio.sfx_toggle.text=="OFF","reopening original map button preserves saved toggle state")
	audio.options_button.pressed.emit()
	check(not audio.panel.visible,"same original button can close options")
	root_control.queue_free()
	await process_frame
	AudioOptions.apply_saved(test_file)
	check(AudioServer.is_bus_mute(music_bus) and AudioServer.is_bus_mute(sfx_bus),"audio settings survive a fresh apply_saved run")
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(0))*100.0-45)<0.2,"persisted volume re-applies after reload")
	# Exercise actual Map.render -> AudioSettings integration without touching user saves.
	var session = root.get_node_or_null("RunSession")
	var created = session==null
	if created:
		session = RunSessionScript.new()
		session.name = "RunSession"
		root.add_child(session)
	var original_path: String = session.save_file_path
	var map_path: String = "user://map_audio_live_%d.json" % OS.get_process_id()
	session.save_file_path = map_path
	session.start_new_world()
	var map = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	var actual = map.map_audio
	check(actual!=null and actual.options_button!=null,"real map initializes audio settings correctly")
	check(actual.get_child(0)==actual.options_button,"real map original audio image targets expected first button")
	var icon: TextureRect
	for child in actual.options_button.get_children():
		if child is TextureRect and child.texture!=null:
			icon=child
			break
	check(icon!=null and icon.texture!=null,"real map displays decoded embedded original audio icon")
	if icon!=null and icon.texture!=null:
		check(icon.texture is ImageTexture,"real map uses painted brush gear asset")
	check(actual.options_button.position==Vector2(1192,14) and actual.options_button.size==Vector2(58,58),"painted gear sits in the map upper-right without enlarging the touch target")
	actual.options_button.pressed.emit()
	check(actual.panel.visible and actual.panel.position.distance_to(Vector2(995.84,82.8))<1.0,"real map opens source-relative 256px option panel")
	actual.close_button.pressed.emit()
	check(not actual.panel.visible,"real map close returns to board")
	map.queue_free()
	await process_frame
	session.save_file_path = original_path
	if created: session.queue_free()
	if FileAccess.file_exists(map_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(map_path))
	AudioServer.set_bus_mute(music_bus,original_music)
	AudioServer.set_bus_mute(sfx_bus,original_sfx)
	AudioServer.set_bus_mute(0,original_master_mute)
	AudioServer.set_bus_volume_db(0,original_master_volume)
	if FileAccess.file_exists(test_file): DirAccess.remove_absolute(ProjectSettings.globalize_path(test_file))
	check(not FileAccess.file_exists(test_file) and not FileAccess.file_exists(map_path),"temporary audio and world saves cleaned up")
	print("UI_MAP_AUDIO_OPTIONS_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
