extends SceneTree
const Sound = preload("res://systems/game_audio.gd")
var passed := 0
var failed := 0
var heard: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:
		passed+=1
		print("PASS game-audio: ",label)
	else:
		failed+=1
		printerr("FAIL game-audio: ",label)
func button(owner: Control, caption: String) -> Button:
	var node:=Button.new()
	node.text=caption
	node.size=Vector2(120,40)
	owner.add_child(node)
	return node
func run() -> void:
	var service=root.get_node_or_null("GameAudio")
	check(service!=null,"shared service is loaded by production project")
	if service==null: quit(1);return
	service.cue_started.connect(func(kind: String): heard.append(kind))
	var owner:=Control.new()
	root.add_child(owner)
	var select:=button(owner,"마물 선택")
	var confirm:=button(owner,"확정")
	var cancel:=button(owner,"취소")
	select.button_down.emit()
	confirm.button_down.emit()
	cancel.button_down.emit()
	check(heard==["ui_select","ui_confirm","ui_cancel"],"select/confirm/cancel are distinguishable physical controls")
	var count:=heard.size()
	select.grab_focus()
	select.mouse_entered.emit()
	check(heard.size()==count,"programmatic focus and hover are silent")
	var manual:=button(owner,"이야기 선택")
	manual.set_meta("sfx_manual",true)
	manual.button_down.emit()
	check(heard.size()==count,"manual story choices do not confirm during text reveal")
	select.disabled=true
	select.button_down.emit()
	check(heard.size()==count,"disabled controls never trigger an active selection")
	var touch:=InputEventScreenTouch.new()
	touch.pressed=true
	select.gui_input.emit(touch)
	check(heard.back()=="ui_blocked","disabled touch reports unavailable without enabling action")
	count=heard.size()
	for i in range(30): Sound.cue(owner,"ui_blocked")
	check(heard.size()==count,"rapid repeated input is rate limited")
	var sfx_bus:=AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_mute(sfx_bus,true)
	check(not Sound.cue(owner,"reward_gain"),"SFX off suppresses new sounds")
	AudioServer.set_bus_mute(sfx_bus,false)
	AudioServer.set_bus_mute(0,true)
	check(not Sound.cue(owner,"reward_gain"),"master off suppresses new sounds")
	AudioServer.set_bus_mute(0,false)
	Sound.stop(owner)
	service.last_started.clear()
	Sound.cue(owner,"dragon_roar")
	Sound.pause(owner,true)
	check(service.voices.back().player.stream_paused,"existing owned voice pauses")
	Sound.cue(owner,"dragon_intro")
	check(service.voices.back().player.stream_paused,"new owned voice inherits pause")
	Sound.pause(owner,false)
	check(not service.voices.back().player.stream_paused,"owned voice resumes without pitch changes")
	Sound.stop(owner)
	check(service.voices.is_empty(),"explicit stop releases owner voices")
	service.last_started.clear()
	for kind in service.profiles.keys():
		Sound.cue(owner,kind)
	check(service.voices.size()<=service.MAX_VOICES,"combined result and combat bursts respect total voice cap")
	var group_counts: Dictionary={}
	for voice in service.voices: group_counts[voice.group]=int(group_counts.get(voice.group,0))+1
	for voice in service.voices: check(group_counts[voice.group]<=int(service.profiles[voice.kind].limit),"category voice cap: "+str(voice.group))
	Sound.stop(owner)
	for kind in service.profiles:
		var path: String=service.profiles[kind].path
		var stream=load(path)
		check(stream is AudioStream and stream.get_length()>0.0,"imported finite audio: "+str(kind))
	service.last_started.clear()
	Sound.cue(owner,"summon")
	root.remove_child(owner)
	await process_frame
	await process_frame
	check(service.voices.is_empty(),"scene removal stops its in-flight sound")
	check(not Sound.cue(owner,"summon"),"detached scene cannot start audio")
	owner.free()
	service.streams.clear()
	await create_timer(0.15).timeout
	print("GAME_AUDIO: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
