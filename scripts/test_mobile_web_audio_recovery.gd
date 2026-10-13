extends SceneTree
## Godot 4.7 web silent-audio regression: dynamic AudioServer.add_bus()
## breaks sample Audio graph (#119026); use bus_count growth instead.
## Verify the title does not autoplay before browser activation.
const Audio = preload("res://systems/audio_settings.gd")
const Title = preload("res://title.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS mobile-web-audio: ",label)
	else:
		failed += 1
		printerr("FAIL mobile-web-audio: ",label)

func _run() -> void:
	var source: String = FileAccess.get_file_as_string("res://systems/audio_settings.gd")
	check(source.contains("AudioServer.bus_count = new_index + 1"),"runtime buses use count growth, not broken web addAt(-1)")
	check(not source.contains("AudioServer.add_bus(") or source.contains("AudioServer.add_bus() forwards"),"no actual dynamic add_bus invocation on web")
	var title_source: String=FileAccess.get_file_as_string("res://title.gd")
	check(title_source.contains("should_unlock_web_audio(OS.has_feature(\"web\")"),"title defers browser BGM until input activation")
	check(title_source.contains("not OS.has_feature(\"web\")"),"native title still plays instantly")
	var initial_count: int=AudioServer.bus_count
	Audio.ensure_buses()
	check(AudioServer.get_bus_index("Master")==0,"Master retains the canonical output root")
	var music: int=AudioServer.get_bus_index("Music")
	var sfx: int=AudioServer.get_bus_index("SFX")
	check(music>0 and sfx>0 and music!=sfx,"Music and SFX buses are defined and separate")
	check(AudioServer.get_bus_send(music)=="Master" and AudioServer.get_bus_send(sfx)=="Master","both buses send directly to audible Master")
	var added_count: int=AudioServer.bus_count
	Audio.ensure_buses()
	check(AudioServer.bus_count==added_count,"re-entry does not append duplicate buses")
	check(added_count>=initial_count and added_count<=initial_count+2,"only genuinely missing audio buses were added")
	check(not AudioServer.is_bus_solo(music) and not AudioServer.is_bus_solo(sfx),"no unexpected solo buses")
	var touch:=InputEventScreenTouch.new()
	touch.pressed=true
	var mouse:=InputEventMouseButton.new()
	mouse.pressed=true
	var key:=InputEventKey.new()
	key.pressed=true
	var move:=InputEventMouseMotion.new()
	var released:=InputEventScreenTouch.new()
	released.pressed=false
	check(Title.should_unlock_web_audio(true,false,touch),"first Android touch unlocks mobile music")
	check(Title.should_unlock_web_audio(true,false,mouse),"first browser mouse click unlocks mobile music")
	check(Title.should_unlock_web_audio(true,false,key),"first keyboard activation unlocks web music")
	check(not Title.should_unlock_web_audio(true,false,move),"mouse movement cannot trigger autoplay")
	check(not Title.should_unlock_web_audio(true,false,released),"finger lift alone cannot trigger autoplay")
	check(not Title.should_unlock_web_audio(true,true,touch),"second touch does not restart the soundtrack")
	check(not Title.should_unlock_web_audio(false,false,touch),"native playback does not depend on a click")
	var title_scene: PackedScene=load("res://title.tscn")
	var title: Node=title_scene.instantiate()
	check(is_instance_valid(title.get_node_or_null("TitleBgm")),"title still contains canonical music stream node")
	if is_instance_valid(title):
		title.free()
	var sound: AudioStream=load("res://assets/title/music/title-theme.mp3")
	check(sound!=null and sound.get_length()>1.0,"title soundtrack remains a valid imported MP3")
	print("MOBILE_WEB_AUDIO_RECOVERY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
