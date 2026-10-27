extends SceneTree
const Card=preload("res://systems/routine_event_card.gd")
const Routine=preload("res://systems/routine_event_catalog.gd")
const Discovery=preload("res://systems/event_discovery_card.gd")
var passed: int=0
var failed: int=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("PASS routine-side: ",message)
	else: failed+=1; printerr("FAIL routine-side: ",message)
func click(button: Button) -> void:
	var point: Vector2=button.get_global_transform_with_canvas()*(button.size*0.5)
	var motion=InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	root.push_input(motion,true)
	await process_frame
	for down in [true,false]:
		var press=InputEventMouseButton.new()
		press.button_index=MOUSE_BUTTON_LEFT
		press.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		press.pressed=down
		press.position=point
		press.global_position=point
		root.push_input(press,true)
		await process_frame
func run() -> void:
	preload("res://systems/audio_settings.gd").apply_saved()
	var language: Node=root.get_node("GameLanguage")
	for event_id in Routine.ORDER:
		var card=Card.new()
		root.add_child(card)
		var entry: Dictionary=Routine.details(event_id)
		card.setup_routine(entry,Routine.reward_image(event_id,{"image":"1"}))
		await create_timer(0.36).timeout
		check(card.position.is_equal_approx(Vector2(268,80)) and card.size==Vector2(452,560),event_id+": shortened card and side choices form a centered composition")
		check(card.get_node_or_null("EventDiscoveryReward")==null and card.get_node_or_null("EventDiscoveryTile")==null,event_id+": no reward label or reward icon is created")
		check(card.get_node("EventDiscoveryBase").texture.resource_path.ends_with("routine_event_card_base_v2.png"),event_id+": new painted parchment has no green reward strip")
		check(card.get_node("EventDiscoveryIllustration").stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,event_id+": the complete illustrated border remains visible")
		check(not card.get_node("EventDiscoveryDismissHint").visible,event_id+": no bottom dismissal text")
		var accept: Button=card.get_node("RoutineAccept")
		var decline: Button=card.get_node("RoutineDecline")
		check(accept.position.x>card.size.x and decline.position.x==accept.position.x and decline.position.y>=accept.position.y+accept.size.y+16,event_id+": choices sit separately on the right in a vertical stack")
		for option in [accept,decline]:
			var box: Rect2=option.get_global_rect()
			check(box.position.x>=0 and box.end.x<=1280 and box.end.y<=720,event_id+": side choice is fully inside the game surface")
		for locale in ["ko","en"]:
			language.set_language(locale)
			await process_frame
			for option in [accept,decline]:
				var font: Font=option.get_theme_font("font")
				var points: int=option.get_theme_font_size("font_size")
				check(font.get_string_size(option.tr(option.text),HORIZONTAL_ALIGNMENT_LEFT,-1,points).x<=option.size.x-20,event_id+": "+locale+" choice fits side button")
		language.set_language("ko")
		var choices: Array[String]=[]
		card.chosen.connect(func(choice: String): choices.append(choice))
		await click(accept)
		check(choices==["take"] and card.choosing,event_id+": native mouse click reaches the button outside the card bounds")
		decline.pressed.emit()
		check(choices==["take"],event_id+": a rapid second choice is blocked")
		card.allow_retry()
		await click(decline)
		check(choices==["take","skip"],event_id+": retry enables the separate decline button")
		card.queue_free()
		await process_frame
	var discovery=Discovery.new()
	root.add_child(discovery)
	discovery.setup("발견","언덕","숲길을 발견했다.","언덕 타일 해금")
	await create_timer(0.36).timeout
	check(discovery.position.is_equal_approx(Vector2(268,80)) and discovery.size==Vector2(452,560),"discovery shares the ordinary event parchment and composition")
	check(discovery.get_node("EventDiscoveryBase").texture.resource_path.ends_with("routine_event_card_base_v2.png"),"discovery uses the same painted parchment as routine events")
	check(discovery.get_node("EventDiscoveryIllustration").stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"discovery preserves its complete illustrated border")
	check(discovery.get_node_or_null("EventDiscoveryReward")!=null and discovery.get_node_or_null("EventDiscoveryTile")!=null,"discovery keeps its reward/location information")
	for node_name in ["EventDiscoveryReward","EventDiscoveryTile"]:
		var side: Control=discovery.get_node(node_name)
		var bounds: Rect2=side.get_global_rect()
		check(bounds.position.x>discovery.get_global_rect().end.x and bounds.end.x<=1280 and bounds.end.y<=720,"discovery "+node_name+" stays beside the parchment and inside the game surface")
	var description: Control=discovery.get_node("EventDiscoveryDescription")
	check(description.position.y+description.size.y<=discovery.size.y,"discovery body stays on the parchment")
	discovery.queue_free()
	await process_frame
	print("ROUTINE_SIDE_CHOICES: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
