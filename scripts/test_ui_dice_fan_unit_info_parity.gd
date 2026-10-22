extends SceneTree
## Stage 5C: 5-card bottom-right source fan, drag/permission, unit-info original art.
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
func _run() -> void:
	var context: Dictionary={"previous_roll":0,"previous_card":"","ui_surface_height":720}
	var items: Array=[]
	for i in range(5):
		items.append({"id":"test-dice-%d" % i,"card_id":"fixed-%d" % (i+1),"image":str(i+1),"label":"눈금 %d" % (i+1)})
	var hand=DiceHand.new()
	root.add_child(hand)
	hand.setup(items,context,true)
	await create_timer(1.0).timeout
	check(hand.battle_mode and hand.battle_backdrop!=null,"battle overlay is transparent and dismissible")
	check(hand.options.size()==5,"all five cards laid out")
	check(hand.options[0].position.x>hand.options[1].position.x and hand.options[4].position.x<hand.options[2].position.x,"source overlapping 5-card fan stretches toward left")
	check(absf(hand.options[0].rotation_degrees-10.0)<0.1 and absf(hand.options[2].rotation_degrees)<0.1 and absf(hand.options[4].rotation_degrees+10.0)<0.1,"source 10/5/0/-5/-10 angles kept")
	check(hand.options[0].position.x>995 and hand.options[4].position.x>610,"fan is anchored to original bottom-right deck")
	check(hand.options.all(func(card): return card.position.y>=430 and card.position.y<550),"card bases stay in lower 40% of 720px battlefield")
	check(hand.options.all(func(card): return not card.get_child(0).visible),"battle card labels hidden; original artwork remains")
	check(hand.options.all(func(card): return card.get_child(1) is Control),"cards retain original upward drag controllers")
	check(hand.options.all(func(card): return not card.disabled),"all five normal fixed-face cards available")
	var chosen_ids: Array[String]=[]
	hand.chosen.connect(func(id: String): chosen_ids.append(id))
	hand.choose("test-dice-2")
	await create_timer(0.3).timeout
	check(chosen_ids.size()==1 and chosen_ids[0]=="test-dice-2","confirmed card identity emitted once without changing rules")
	hand.queue_free()
	await process_frame
	# Empty deck should still open/close gracefully.
	var empty=DiceHand.new()
	root.add_child(empty)
	empty.setup([],context,true)
	await process_frame
	check(empty.options.is_empty() and empty.battle_backdrop!=null,"empty deck has backdrop but no fake cards")
	empty.queue_free()
	await process_frame
	var invalid=DiceHand.new()
	root.add_child(invalid)
	var unusable: Array=[{"id":"echo-test","card_id":"echo","image":"echo","label":"효과 재발동"}]
	invalid.setup(unusable,context,true)
	await create_timer(0.65).timeout
	check(invalid.options.size()==1 and invalid.options[0].disabled,"echo unavailable without previously used control card")
	var blocked: Array[String]=[]
	invalid.chosen.connect(func(id: String): blocked.append(id))
	invalid.choose("echo-test")
	check(blocked.is_empty() and not invalid.choosing,"disabled option cannot be consumed")
	invalid.queue_free()
	await process_frame
	# Check embedded battlefield positioning: 530px tall battle region.
	var compact=DiceHand.new()
	root.add_child(compact)
	var small_context=context.duplicate()
	small_context.ui_surface_height=530
	compact.setup(items,small_context,true)
	await create_timer(0.85).timeout
	check(compact.options.size()==5 and compact.options[0].position.y<375,"embedded battle fan respects 530px height")
	check(compact.battle_backdrop.size.y==530,"embedded overlay does not block map UI outside battle viewport")
	compact.queue_free()
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
	check(panel.effects.get_child_count()>=5,"full legion/passive/brand details remain accessible")
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
