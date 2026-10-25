extends SceneTree
## Bottom right-to-left 10-card hand, input and unchanged unit-info regression.
const DiceHand=preload("res://systems/dice_control_hand.gd")
const UnitInfo=preload("res://systems/unit_info.gd")
const BattleRules=preload("res://systems/battlefield_rules.gd")
var passed=0
var failed=0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool,label: String) -> void:
	if ok:
		passed+=1
		print("PASS ui-dice-fan: ",label)
	else:
		failed+=1
		printerr("FAIL ui-dice-fan: ",label)
func wait_open(hand: Control) -> void:
	var deadline: int=Time.get_ticks_msec()+3000
	while hand.opening and Time.get_ticks_msec()<deadline: await process_frame
	check(not hand.opening,"hand finishes opening within deadline")

func _run() -> void:
	preload("res://systems/audio_settings.gd").apply_saved()
	var context: Dictionary={"previous_roll":0,"previous_card":"","ui_surface_height":720}
	var items: Array=[]
	for i in range(10):
		items.append({"id":"test-dice-%d" % i,"card_id":"fixed-%d" % ((i%6)+1),"image":str((i%6)+1),"label":"눈금 %d" % ((i%6)+1)})
	for spec in [[false,720,0],[false,720,1],[false,720,5],[false,720,10],[true,720,10],[true,530,10]]:
		var hand=DiceHand.new()
		root.add_child(hand)
		var count: int=spec[2]
		var height: int=spec[1]
		var current_context=context.duplicate()
		current_context.ui_surface_height=height
		hand.setup(items.slice(0,count),current_context,spec[0])
		await wait_open(hand)
		check(hand.battle_backdrop!=null and hand.battle_backdrop.size.y==height,"map and battle use correctly bounded dismissible backdrop")
		check(hand.options.size()==count,"all %d owned cards are shown" % count)
		for i in range(count):
			var option: TextureButton=hand.options[i]
			check(option.size.is_equal_approx(Vector2(136,218)) and option.z_index>0,"card %d retains artwork size and positive stacking (%s, z=%d)" % [i,option.size,option.z_index])
			check(option.position.y>=height-240 and option.position.y<=height-200,"card %d sits along bottom" % i)
			if i>0: check(option.position.x<hand.options[i-1].position.x-20,"card %d has a distinct selectable strip to the left" % i)
			check(option.get_node_or_null("DiceCardDrag")!=null and not option.disabled,"card %d remains usable" % i)
		if count>0:
			var last: TextureButton=hand.options[-1]
			var drag=last.get_node("DiceCardDrag")
			var home: Vector2=drag.home
			var base_z: int=drag.home_z
			hand.focus_card(last,true)
			check(last.position.y==home.y-26 and last.z_index==100,"hover reveals the complete leftmost card")
			hand.focus_card(last,false)
			check(last.position==home and last.z_index==base_z,"hover release restores hand stacking")
			var center: Vector2=last.size*0.5
			var start_point: Vector2=drag.get_global_transform_with_canvas()*center
			drag.begin(-1,center,true)
			drag.release(start_point-Vector2(0,15))
			await create_timer(0.2).timeout
			check(last.position.distance_to(home)<0.1 and last.z_index==base_z and not hand.choosing,"short drag restores original position and stacking")
		var chosen_ids: Array[String]=[]
		var closed: Array[bool]=[]
		hand.chosen.connect(func(id: String): chosen_ids.append(id))
		hand.closed.connect(func(): closed.append(true))
		if count==10:
			var index: int=9 if bool(spec[0]) else 6
			if bool(spec[0]):
				var option: TextureButton=hand.options[index]
				var drag=option.get_node("DiceCardDrag")
				var center: Vector2=option.size*0.5
				var point: Vector2=drag.get_global_transform_with_canvas()*center
				drag.begin(-1,center,true)
				drag.release(point-Vector2(0,45))
			else:
				# Exercise the native overlapping Control hit path on the seventh card.
				var option: TextureButton=hand.options[index]
				var point: Vector2=option.get_global_transform_with_canvas()*Vector2(110,80)
				var move=InputEventMouseMotion.new()
				move.position=point
				move.global_position=point
				root.push_input(move,true)
				await process_frame
				for pressed in [true,false]:
					var click=InputEventMouseButton.new()
					click.button_index=MOUSE_BUTTON_LEFT
					click.pressed=pressed
					click.position=point
					click.global_position=point
					root.push_input(click,true)
					await process_frame
			await create_timer(0.25).timeout
			check(chosen_ids==["test-dice-%d" % index],"seventh/tenth card activation emits correct ID once")
			hand.choose("test-dice-0")
			check(chosen_ids.size()==1,"selection cannot consume a second card")
		else:
			hand.close_hand()
			await create_timer(0.7).timeout
			check(closed.size()==1,"empty or partial hand closes once")
		hand.queue_free()
		await process_frame
	var immediate=DiceHand.new()
	root.add_child(immediate)
	var immediate_closed: Array[bool]=[]
	immediate.closed.connect(func(): immediate_closed.append(true))
	immediate.setup(items,context,false)
	immediate.close_hand()
	await create_timer(1.9).timeout
	check(immediate_closed.size()==1,"closing during ten-card opening completes without a stuck tween")
	immediate.queue_free()
	await process_frame
	var invalid=DiceHand.new()
	root.add_child(invalid)
	invalid.setup([{"id":"echo-test","card_id":"echo","image":"echo","label":"효과 재발동"}],context,true)
	await wait_open(invalid)
	check(invalid.options[0].disabled,"echo unavailable without previous card")
	invalid.choose("echo-test")
	check(not invalid.choosing,"disabled option cannot be consumed")
	invalid.queue_free()
	await process_frame
	var definitions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	var rules=BattleRules.new(definitions,705)
	var ally=rules.individual("skeleton-spear","own-1")
	var enemy=rules.individual("goblin-rider","enemy-1")
	rules.start([ally],[enemy])
	var before=JSON.stringify(rules.snapshot())
	var panel=UnitInfo.new()
	root.add_child(panel)
	panel.setup(rules.units[0],rules)
	await process_frame
	check(panel.portrait!=null and panel.portrait.texture!=null,"unit information uses real portrait artwork")
	check(panel.get_child_count()>=4 and panel.effects!=null,"unit information renders separate portrait and effect sections")
	check(panel.get_node_or_null("Control/InfoClose")!=null or panel.get_children().any(func(x): return x is Control and x.get_node_or_null("InfoClose")!=null),"original close button retained on portrait")
	check(panel.effects.get_child_count()>=1 and panel.effects.get_children().all(func(c): return c is HBoxContainer or c is VBoxContainer or c is GridContainer),"effect information retains a scrollbar-free aligned ledger with real data")
	check(before==JSON.stringify(rules.snapshot()),"unit info reads battle without mutating rules")
	var closed: Array[bool]=[]
	panel.closed.connect(func(): closed.append(true))
	panel.close()
	panel.close() # Closing twice during the existing animation emits only once.
	var close_deadline: int=Time.get_ticks_msec()+1300
	while closed.is_empty() and Time.get_ticks_msec()<close_deadline:
		await process_frame
	check(closed.size()==1,"unit info close signal delivered once after the real depth exit")
	await process_frame
	print("UI_DICE_FAN_UNIT_INFO_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
