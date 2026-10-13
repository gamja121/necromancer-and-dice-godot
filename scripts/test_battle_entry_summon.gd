extends SceneTree
## The real selected deck (not a stub) must summon each allied source sprite
## from a ritual circle, BLACK -> source art, before dice/card clicks unlock.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS entry-summon: ",label)
	else:
		failed += 1
		printerr("FAIL entry-summon: ",label)

func wait_for(condition: Callable, limit: int = 16000) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < limit:
		if condition.call(): return true
		await process_frame
	return bool(condition.call())

func _initialize() -> void:
	call_deferred("_run")

func run_party(session: Node, count: int) -> void:
	session.start_new_world()
	var world = session.world
	while world.roster.size()<count:
		var extra: Dictionary=world.roster[0].duplicate(true)
		extra.id="summon-test-unit-%d" % world.roster.size()
		world.roster.append(extra)
	var monster: int=world.tiles.find("monster")
	check(monster>=0,"%d allies: ordinary monster tile exists" % count)
	if monster<0: return
	world.position=monster
	session.save_world()
	var map: Control=MAP.instantiate()
	root.add_child(map)
	await process_frame
	map.show_battle_deck(monster)
	var deck: Control=map.overlay
	var ids: Array=[]
	for i in range(count):
		var id: String=str(world.roster[count-1-i].id)
		ids.append(id)
		deck.toggle_unit(id)
	deck.confirm_button.pressed.emit()
	var entered: bool=await wait_for(func(): return is_instance_valid(map.embedded_battle) and map.embedded_battle.entry_summon_active)
	check(entered,"%d allies: fresh deck starts opening summon before accepting clicks" % count)
	if not entered:
		map.queue_free()
		await process_frame
		return
	var battle: Control=map.embedded_battle
	var snapshot: String=JSON.stringify(world.snapshot())
	var original_rng: int=world.rng.state
	var original_face: int=world.dice_visual_face
	check(battle.play_entry_summon and battle.rules.round_number==0 and battle.session.encounter.phase=="ready","%d allies: only fresh ready encounter summons" % count)
	check(map.dice.disabled and battle.entry_summon_active,"%d allies: shared die is locked during summoning" % count)
	check(not is_instance_valid(battle.brand_reference),"%d allies: no brand overlay interrupts sequential monster entrance" % count)
	var hidden: bool=true
	for id in ids:
		var sprite: TextureRect=battle.sprites[id]
		hidden=hidden and sprite.modulate.a<0.02 and absf(float(sprite.material.get_shader_parameter("entry_reveal")))<0.02
	check(hidden,"%d allies: existing source sprites initially hidden behind black-silhouette shader" % count)
	var first_effect: bool=await wait_for(func(): return battle.visuals.entry_circles.has(ids[0]))
	check(first_effect,"%d allies: first selected monster receives a glowing floor magic circle" % count)
	check(battle.visuals.entry_circles.size()==1 and battle.sprites[ids[0]].modulate.a>0.9,"%d allies: first silhouette appears before later slots" % count)
	var first_shader: float=float(battle.sprites[ids[0]].material.get_shader_parameter("entry_reveal"))
	check(first_shader<0.5,"%d allies: first unit stays dark when portal opens" % count)
	var complete: bool=await wait_for(func(): return not battle.entry_summon_active,16000)
	check(complete,"%d allies: all sequential summon reveals finish" % count)
	if complete:
		var uncovered: bool=battle.visuals.entry_circles.is_empty()
		for id in ids:
			var sprite: TextureRect=battle.sprites[id]
			uncovered=uncovered and absf(float(sprite.material.get_shader_parameter("entry_reveal"))-1.0)<0.01
			uncovered=uncovered and sprite.modulate.a>0.99 and battle.bars[id].modulate.a>0.99
		check(uncovered,"%d allies: all original monster artwork and HP bars fully restored" % count)
		check(is_instance_valid(battle.brand_reference) and battle.entry_brand_auto_open,
			"%d allies: original brand reference opens once after last summoned monster" % count)
		if is_instance_valid(battle.brand_reference):
			var panel: Control=battle.brand_reference
			check(panel.reference_rows.size()==battle.rules.units.filter(func(u): return u.alive and not u.is_summon and u.slot<4).size(),
				"%d allies: brand chart uses all real living allied and enemy units" % count)
			check(panel.dice_headers.size()==6 and panel.face_cells.size()==panel.reference_rows.size(),
				"%d allies: six die faces for each real monster" % count)
			check(panel.get_parent()==map.stage,
				"%d allies: chart overlays entire map, not clipped inside battle viewport" % count)
			check(map.dice.disabled and battle.cards[ids[0]].disabled and battle.dice_cards_button==null,
				"%d allies: rolling and cards stay locked behind the automatic brand chart" % count)
			check(battle.rules.round_number==0 and session.encounter.phase=="ready",
				"%d allies: presentation never starts the first turn without consent" % count)
			# Dismiss through the original close tween/signal, just as a
			# player would tap the parchment X.
			panel.close()
			var dismissed: bool=await wait_for(func(): return not is_instance_valid(battle.brand_reference))
			check(dismissed and not battle.entry_brand_auto_open,
				"%d allies: closing automatic chart finishes the entry gate" % count)
			check(not map.dice.disabled and not battle.cards[ids[0]].disabled and not battle.entry_summon_active,
				"%d allies: close restores shared die and card clicks for first turn" % count)
			battle.show_brand_reference()
			check(is_instance_valid(battle.brand_reference) and not battle.entry_brand_auto_open,
				"%d allies: brand chart remains manually inspectable without auto-repeat" % count)
			battle.close_brand_reference()
			check(not map.dice.disabled,
				"%d allies: manual closing cannot re-lock the entry die" % count)
	check(JSON.stringify(world.snapshot())==snapshot and world.rng.state==original_rng and world.dice_visual_face==original_face,
		"%d allies: introductory presentation leaves saved game, dice, and RNG unchanged" % count)
	map.queue_free()
	await process_frame
	# Opening a SAVED ready encounter is intentionally different from a newly
	# confirmed deck: no repeated ceremony and no extra gameplay mutations.
	var reloaded: Control=MAP.instantiate()
	root.add_child(reloaded)
	await process_frame
	var restored: bool=await wait_for(func(): return is_instance_valid(reloaded.embedded_battle))
	check(restored,"%d allies: saved encounter restores battlefield" % count)
	if restored:
		check(not reloaded.embedded_battle.play_entry_summon and not reloaded.embedded_battle.entry_summon_active
			and not reloaded.embedded_battle.entry_brand_auto_open and not is_instance_valid(reloaded.embedded_battle.brand_reference)
			and not reloaded.dice.disabled,"%d allies: restored encounter repeats neither entrance nor automatic brand chart" % count)
	reloaded.queue_free()
	await process_frame

func _run() -> void:
	var session: Node=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var prior_path: String=session.save_file_path
	var scratch: String="user://battle_entry_summon_%d.json" % OS.get_process_id()
	session.save_file_path=scratch
	for count in [1,2,4]:
		await run_party(session,count)
	session.save_file_path=prior_path
	if created: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("BATTLE_ENTRY_SUMMON: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
