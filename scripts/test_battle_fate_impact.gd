extends SceneTree
## Fate presentation contract: chest first, unmistakable curse, no RNG.
## Uses a real battlefield scene, layout, sprites, bars and CombatCues.
const Battle=preload("res://battlefield.tscn")
const Cues=preload("res://systems/combat_cues.gd")
var passed: int=0
var failed: int=0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		passed+=1
		print("PASS fate-impact: ",description)
	else:
		failed+=1
		printerr("FAIL fate-impact: ",description)

func wait_for(predicate: Callable, limit_msec: int=1600) -> bool:
	var started: int=Time.get_ticks_msec()
	while Time.get_ticks_msec()-started<limit_msec:
		if predicate.call(): return true
		await process_frame
	return bool(predicate.call())

func _run() -> void:
	var battle: Control=Battle.instantiate()
	root.add_child(battle)
	await process_frame
	var cues: Control=battle.cues
	check(cues!=null and cues.get_script()==Cues,"real combat cue renderer is installed")
	check(battle.rules.units.size()>=2,"real enemies and allies are present")
	check(is_equal_approx(float(Cues.BLESS_TORSO_FRACTION),0.40),"chest is inside upper part of opaque artwork")
	check(float(Cues.NORMAL_FATE_BODY_TIME)>=0.40,"ordinary brand body cue remains readable long enough")
	var all_chests: bool=true
	var located_on_torso: bool=true
	var follows_movement: bool=true
	var sample_count: int=0
	for u in battle.rules.units:
		if not battle.sprites.has(u.id): continue
		var sprite: TextureRect=battle.sprites[u.id]
		var metric: Dictionary=battle.presentation_layout.metrics.get(str(u.slug),{})
		var top: float=float(metric.get("top",0))
		var bottom: float=float(metric.get("bottom",maxi(1,int(metric.get("height",320))-1)))
		var local_top: Vector2=Vector2(sprite.size.x*0.5,sprite.size.y*top/maxf(1,float(metric.get("height",320))))
		var local_bottom: Vector2=Vector2(sprite.size.x*0.5,sprite.size.y*bottom/maxf(1,float(metric.get("height",320))))
		var canvas_inv: Transform2D=cues.get_global_transform_with_canvas().affine_inverse()
		var top_pos: Vector2=canvas_inv*(sprite.get_global_transform_with_canvas()*local_top)
		var bottom_pos: Vector2=canvas_inv*(sprite.get_global_transform_with_canvas()*local_bottom)
		var chest: Vector2=cues.chest_anchor(u)
		all_chests=all_chests and chest.is_finite() and top_pos.is_finite() and bottom_pos.is_finite()
		located_on_torso=located_on_torso and chest.y>=top_pos.y and chest.y<top_pos.y+(bottom_pos.y-top_pos.y)*0.50
		# The frame can be breathing or attacking when the impact starts.
		# The effect must follow its actual transform, not a fixed ground Y.
		var original_position: Vector2=sprite.position
		sprite.position+=Vector2(11,-8)
		var shifted: Vector2=cues.chest_anchor(u)
		follows_movement=follows_movement and shifted.distance_to(chest+Vector2(11,-8))<0.15
		sprite.position=original_position
		sample_count+=1
	check(sample_count>=2 and all_chests,"torso anchors are finite across actual combatants")
	check(located_on_torso,"every fate cue starts in top half of visible sprite, not at feet")
	check(follows_movement,"torso effects track current monster position and body motion")

	# Only presentation fixtures are changed. They are deep copies of one
	# real combatant and must leave real battle stats / dice unchanged.
	var before: String=JSON.stringify(battle.rules.snapshot())
	var rng_before: int=battle.rules.rng.state
	var unit: Dictionary=battle.rules.units[0].duplicate(true)
	unit.brands=[]
	for mode in ["bless","curse","mixed"]:
		unit.bless={"critical":1} if mode in ["bless","mixed"] else {}
		unit.curse={"poison":1} if mode in ["curse","mixed"] else {}
		battle.visuals.states[str(unit.id)]=unit.duplicate(true)
		cues.play_brands([unit])
		var reached: bool=await wait_for(func():
			return not cues.impact.is_empty() and str(cues.impact.get("mode",""))==mode)
		check(reached,"%s cue appears on an actual monster" % mode)
		if reached:
			check(float(cues.impact.duration)>=0.30,"%s impact stays visible for a readable chest pulse" % mode)
			var fate=battle.bars[unit.id].get_node_or_null("FateIcon")
			check(fate!=null and str(fate.mode)==("curse" if mode in ["curse","mixed"] else "bless"),"%s cue agrees with HP-bar fate icon" % mode)
		check(await wait_for(func(): return cues.impact.is_empty(),1800),"%s impact ends and cleans up" % mode)
	check(JSON.stringify(battle.rules.snapshot())==before and battle.rules.rng.state==rng_before,
		"every fate cue is purely visual and preserves combat RNG, brands and stats")
	battle.queue_free()
	await process_frame
	print("BATTLE_FATE_IMPACT: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
