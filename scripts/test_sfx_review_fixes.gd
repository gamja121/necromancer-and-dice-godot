extends SceneTree
## Targeted regressions for the reported input, book, critical and defeat audio bugs.
const Sound=preload("res://systems/game_audio.gd")
const Hand=preload("res://systems/dice_control_hand.gd")
const Inheritance=preload("res://systems/home_inheritance.gd")
const Book=preload("res://systems/main_story_book.gd")
const Visuals=preload("res://systems/battle_visuals.gd")
const GameOver=preload("res://systems/game_over_screen.gd")
const Rules=preload("res://systems/battlefield_rules.gd")
class MapFixture extends "res://map.gd":
	func _ready()->void: pass
class BattleFixture extends "res://battlefield.gd":
	func _ready()->void: pass
var passed:=0
var failed:=0
var service: Node
var heard: Array[String]=[]
func _initialize()->void: call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:
		passed+=1
		print("PASS sfx-review: ",label)
	else:
		failed+=1
		printerr("FAIL sfx-review: ",label)
func reset_audio()->void:
	Sound.stop(root)
	service.last_started.clear()
	heard.clear()
func wait_for(predicate: Callable)->bool:
	var deadline:=Time.get_ticks_msec()+5000
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())

func escape()->InputEventKey:
	var key:=InputEventKey.new()
	key.keycode=KEY_ESCAPE
	key.pressed=true
	return key
func cards()->void:
	for keyboard in [false,true]:
		reset_audio()
		var hand:=Hand.new()
		root.add_child(hand)
		var item={"id":"audio-fixed","card_id":"fixed-1","image":"1","label":"고정 1"}
		hand.setup([item],{})
		check(await wait_for(func(): return not hand.opening),"production card fan opens")
		var committed: Array=[false]
		hand.chosen.connect(func(_id: String): committed[0]=true)
		var option: TextureButton=hand.options[0]
		option.button_down.emit()
		check(not heard.has("card_use") and not heard.has("ui_select"),"automatic press does not double the manual card cue")
		if keyboard: option.pressed.emit()
		else:
			var drag: Node = null
			for child in option.get_children():
				if child.get_script()==preload("res://systems/drag_card_module.gd"): drag=child
			check(drag!=null,"actual pointer activation module is present")
			drag.activated.emit()
		check(await wait_for(func(): return bool(committed[0])),"card use reaches the original chosen signal")
		check(heard.count("card_use")==1,"keyboard card use once" if keyboard else "pointer card use once")
		Sound.stop(hand)
		hand.queue_free()
		await process_frame
	reset_audio()
	var closing:=Hand.new()
	root.add_child(closing)
	closing.setup([],{})
	closing._unhandled_key_input(escape())
	await create_timer(0.16).timeout
	check(heard.count("ui_cancel")==1,"Escape closes card hand with one cancel cue")
	closing.queue_free()
	await process_frame
	reset_audio()
	var inheritance:=Inheritance.new()
	root.add_child(inheritance)
	inheritance._unhandled_key_input(escape())
	await create_timer(0.17).timeout
	check(heard.count("ui_cancel")==1,"Escape closes inheritance with one cancel cue")
	inheritance.queue_free()
	await process_frame
func books()->void:
	reset_audio()
	var map:=MapFixture.new()
	root.add_child(map)
	map.stage=Control.new()
	map.add_child(map.stage)
	var first=map.story_modal()
	first.skip_opening()
	map.close_overlay()
	check(heard.count("book_close")==1,"normal story completion closes the book audibly")
	await process_frame
	reset_audio()
	var previous=map.story_modal()
	previous.skip_opening()
	var next=map.story_modal()
	check(next.instant and not heard.has("book_close"),"beat replacement remains an open book without a closing sound")
	await process_frame
	await process_frame
	reset_audio()
	var back=map.location_button(next,"돌아가기",Vector2(700,480),Vector2(440,44),map.dismiss_overlay,4)
	back.pressed.emit()
	check(heard.count("ui_cancel")==1 and not heard.has("book_confirm"),"book return is cancellation, not a story choice")
	check(heard.count("book_close")==1,"return closes the book exactly once")
	reset_audio()
	var finished=map.story_modal()
	finished.skip_opening()
	var finish=map.location_button(finished,"마치기",Vector2(700,480),Vector2(440,44),map.close_overlay,4)
	finish.pressed.emit()
	check(heard.count("book_confirm")==1 and not heard.has("ui_cancel"),"finishing a story is a positive action regardless of button artwork")
	check(heard.count("book_close")==1,"finish action closes the book once")
	map.queue_free()
	await create_timer(0.15).timeout
func defeat()->void:
	reset_audio()
	var map:=MapFixture.new()
	root.add_child(map)
	map.stage=Control.new()
	map.add_child(map.stage)
	map.dice=TextureButton.new()
	map.stage.add_child(map.dice)
	var session: Node=root.get_node("RunSession")
	session.start_new_world()
	session.world.run_result={"reason":"battle_defeat"}
	map.world=session.world
	map.session=session
	map.map_music=AudioStreamPlayer.new()
	map.add_child(map.map_music)
	map.map_music.stream=load("res://assets/map/music/map_board.mp3")
	map.map_music.play()
	var battle:=BattleFixture.new()
	map.stage.add_child(battle)
	battle.rules=Rules.new({},1)
	battle.dice=TextureButton.new()
	battle.add_child(battle.dice)
	battle.audio=AudioStreamPlayer.new()
	battle.add_child(battle.audio)
	battle.audio.stream=load("res://assets/battle/music/battle.mp3")
	battle.audio.play()
	map.embedded_battle=battle
	check(battle.audio.playing,"real battle music player starts")
	map.show_game_over(true)
	check(not battle.audio.playing and battle.audio.stream==null,"defeat stops and releases battle music before the result screen")
	check(map.map_music.stream_paused,"defeat also pauses map music")
	map.queue_free()
	await create_timer(0.15).timeout
	reset_audio()
	var screen:=GameOver.new()
	root.add_child(screen)
	screen.shade=ColorRect.new()
	screen.add_child(screen.shade)
	Sound.cue(screen,"defeat_crack")
	Sound.cue(screen,"defeat_echo")
	check(service.voices.size()==2,"shatter cues use the shared controlled service")
	screen.finish_now()
	check(service.voices.is_empty(),"skip cuts off both shatter sound tails")
	check(float(service.profiles.defeat_crack.db)==-12.0,"shatter impact uses normal headroom instead of the former 8 dB boost")
	screen.queue_free()
	await create_timer(0.15).timeout
func native_mix()->void:
	reset_audio()
	var capture:=AudioEffectCapture.new()
	capture.buffer_length=2.0
	var bus:=AudioServer.get_bus_index("SFX")
	AudioServer.add_bus_effect(bus,capture)
	var mixes:Array=[["card_use"],["reward_gain","cleanse"],["capture_success","prophecy_bless"],["dragon_roar","dragon_impact"],["dragon_critical"],["defeat_crack","defeat_echo"]]
	var maximum:=0.0
	for index in range(mixes.size()):
		reset_audio()
		capture.clear_buffer()
		for kind in mixes[index]: Sound.cue(root,kind)
		await create_timer(0.4).timeout
		var samples:=capture.get_buffer(capture.get_frames_available())
		var peak:=0.0
		for sample in samples: peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
		maximum=maxf(maximum,peak)
		check(samples.size()>0 and peak>0.0001,"native output for corrected mix %d"%index)
		check(peak<0.95,"native peak headroom for corrected mix %d"%index)
		print("REVIEW_MIX %d peak=%f"%[index,peak])
	reset_audio()
	AudioServer.remove_bus_effect(bus,0)
	print("REVIEW_NATIVE_PEAK: ",maximum)
func run()->void:
	service=root.get_node("GameAudio")
	service.cue_started.connect(func(kind:String):heard.append(kind))
	await cards()
	await books()
	check(Visuals.impact_cue("skeleton-spear","dragon",false)=="dragon_hit","ordinary dragon impact has its own cue")
	check(Visuals.impact_cue("skeleton-spear","dragon",true)=="dragon_critical","critical dragon impact stays distinct")
	check(Visuals.impact_cue("dragon","skeleton-spear",true)=="battle_critical","dragon critical outgoing strike preserves critical feedback")
	await defeat()
	if DisplayServer.get_name()!="headless": await native_mix()
	reset_audio()
	service.streams.clear()
	await create_timer(0.15).timeout
	print("SFX_REVIEW_FIXES: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)