extends SceneTree
## Verify actual battle chest anchoring and every fate-impact presentation.
## Cosmetic only: the battle snapshot, die, brands and RNG never change.
const BattleScene=preload("res://battlefield.tscn")
var passed: int=0
var failed: int=0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, caption: String) -> void:
	if value:
		passed+=1
		print("PASS fate-impact: ",caption)
	else:
		failed+=1
		printerr("FAIL fate-impact: ",caption)

func verify_cue(battle: Control, unit: Dictionary, blessings: bool, curses: bool, expected_mode: String) -> void:
	var cues: Control=battle.cues
	var count: int=0
	var captured: Array=[]
	var observed: Callable=func():
		if not cues.impact.is_empty():
			captured.append(str(cues.impact.get("mode","")))
			count+=1
	process_frame.connect(observed)
	var original_bless: Dictionary=unit.bless.duplicate(true)
	var original_curse: Dictionary=unit.curse.duplicate(true)
	unit.bless={"critical":1} if blessings else {}
	unit.curse={"guard":1} if curses else {}
	# Invoke the real production presentation coroutine, no simulated state.
	await cues.play_brands([unit])
	process_frame.disconnect(observed)
	check(count>=2 and expected_mode in captured,expected_mode+" impact visible across several actual rendered frames")
	check(cues.impact.is_empty(),expected_mode+" clears effect state after presentation")
	var icon=battle.bars[unit.id].get_node_or_null("FateIcon")
	check(icon!=null and icon.mode==("curse" if curses else "bless"),expected_mode+" uses the appropriate HP fate icon")
	unit.bless=original_bless
	unit.curse=original_curse

func _run() -> void:
	var battle=BattleScene.instantiate()
	battle.selection=["skeleton-spear","dracula","spider-knight","guardian-seed"]
	root.add_child(battle)
	await process_frame
	check(battle.cues!=null and battle.visuals!=null,"real combat cue and sprites instantiated")
	var ids: Array=[]
	for unit in battle.rules.units:
		if unit.team=="ally" and ids.size()<4: ids.append(str(unit.id))
	check(ids.size()==4,"four distinct real monsters available")
	if ids.size()!=4:
		battle.queue_free()
		quit(1)
		return
	var cues: Control=battle.cues
	for id in ids:
		var unit: Dictionary=battle.rules.find_id(id)
		var sprite: TextureRect=battle.sprites[id]
		var center: Vector2=cues.chest_anchor(unit)
		var metric: Dictionary=battle.presentation_layout.metrics.get(str(unit.slug),{})
		var relative: float=(center.y-sprite.position.y)/maxf(1.0,sprite.size.y)
		var expected: float=(float(metric.get("top",0))+(float(metric.get("bottom",float(metric.get("height",320))-1.0))-float(metric.get("top",0)))*0.43)/maxf(1.0,float(metric.get("height",320)))
		check(absf(relative-expected)<0.03,str(unit.slug)+" bright center matches artwork upper torso rather than feet")
		var original: Vector2=sprite.position
		sprite.position=original+Vector2(5.0,8.0)
		check(cues.chest_anchor(unit).distance_to(center+Vector2(5.0,8.0))<0.6,str(unit.slug)+" cue stays attached through sprite movement")
		sprite.position=original
	var snapshot: String=JSON.stringify(battle.rules.snapshot())
	var rng: int=battle.rules.rng.state
	var first: Dictionary=battle.rules.find_id(ids[0])
	await verify_cue(battle,first,true,false,"bless")
	await verify_cue(battle,first,false,true,"curse")
	await verify_cue(battle,first,true,true,"mixed")
	check(JSON.stringify(battle.rules.snapshot())==snapshot and battle.rules.rng.state==rng,"all visual modes preserve combat rules and RNG")
	battle.queue_free()
	await process_frame
	print("FATE_CHEST_IMPACT: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
