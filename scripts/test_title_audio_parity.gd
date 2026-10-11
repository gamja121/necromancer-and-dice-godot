extends SceneTree
## W005/W006: title music and persistent audio UI on the actual title.tscn.
## An isolated per-process ConfigFile is used; the player's settings are not touched.
const AudioSettings = preload("res://systems/audio_settings.gd")
const TITLE_SCENE = preload("res://title.tscn")

var passed: int=0
var failed: int=0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed+=1
		print("PASS title-audio: ",message)
	else:
		failed+=1
		printerr("FAIL title-audio: ",message)

func _run() -> void:
	AudioSettings.ensure_buses()
	var master_db: float=AudioServer.get_bus_volume_db(0)
	var master_mute: bool=AudioServer.is_bus_mute(0)
	var music_mute: bool=AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))
	var sfx_mute: bool=AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX"))
	var save_path: String="user://title_audio_parity_%d.cfg" % OS.get_process_id()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var initial=ConfigFile.new()
	initial.set_value("audio","volume",0.64)
	initial.set_value("audio","music_enabled",true)
	initial.set_value("audio","sfx_enabled",true)
	check(initial.save(save_path)==OK,"isolated audio settings fixture saved")
	check(ResourceLoader.exists("res://assets/title/music/title-theme.mp3"),"canonical title MP3 imported into Godot assets")
	var title=TITLE_SCENE.instantiate()
	title.audio_save_path=save_path
	root.add_child(title)
	var stream_player: AudioStreamPlayer=title.get_node("TitleBgm")
	check(stream_player.bus=="Music","title song routes to shared Music bus")
	check(stream_player.stream!=null,"original MP3 connected to actual title scene")
	if stream_player.stream!=null:
		check(stream_player.stream.get_length()>1.0,"title song decodes as a nonempty sound")
	var dialog: AcceptDialog=title.get_node("TitleUI/OptionsDialog")
	var volume: HSlider=title.get_node("TitleUI/OptionsDialog/OptionsContent/Volume")
	var music_toggle: CheckButton=title.get_node("TitleUI/OptionsDialog/OptionsContent/MusicEnabled")
	var sfx_toggle: CheckButton=title.get_node("TitleUI/OptionsDialog/OptionsContent/SfxEnabled")
	check(dialog!=null and volume!=null and music_toggle!=null and sfx_toggle!=null,"existing Options window includes three audio controls")
	check(music_toggle.button_pressed and sfx_toggle.button_pressed,"saved Music and SFX enabled flags reflected on title")
	check(absf(volume.value-0.64)<0.02,"saved master volume reflected in title slider")
	music_toggle.button_pressed=false
	sfx_toggle.button_pressed=false
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"title Music toggle updates shared music bus")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"title SFX toggle updates shared effects bus")
	volume.value=0.0
	check(AudioServer.is_bus_mute(0),"master zero volume mutes shared bus")
	volume.value=0.42
	check(not AudioServer.is_bus_mute(0),"raising volume unmutes shared bus")
	var settings=ConfigFile.new()
	check(settings.load(save_path)==OK,"title changes are written to the isolated config")
	check(settings.get_value("audio","music_enabled",true)==false,"Music off persists")
	check(settings.get_value("audio","sfx_enabled",true)==false,"SFX off persists")
	check(absf(float(settings.get_value("audio","volume",0))-0.42)<0.02,"master volume persists")
	# Simulate the same startup reload path used by map and battlefield.
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"),false)
	AudioServer.set_bus_volume_db(0,0.0)
	AudioSettings.apply_saved(save_path)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"reloaded setting also mutes map/battle Music bus")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"reloaded setting also mutes map/battle SFX bus")
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(0))-0.42)<0.02,"reloaded master volume is restored")
	title._sync_audio_controls()
	check(not music_toggle.button_pressed and not sfx_toggle.button_pressed,"title options resynchronize with restored buses")
	check(absf(volume.value-0.42)<0.02,"title slider resynchronizes with restored master")
	title.queue_free()
	AudioServer.set_bus_volume_db(0,master_db)
	AudioServer.set_bus_mute(0,master_mute)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),music_mute)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"),sfx_mute)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	check(not FileAccess.file_exists(save_path),"temporary audio settings cleaned up")
	print("TITLE_AUDIO_PARITY_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
