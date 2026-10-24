extends SceneTree
## Real ResourceLoader lifecycle: no fake loader or gameplay save access.
class ObservedLoader extends "res://systems/battle_resources.gd":
	var process_calls: int = 0
	func _process(delta: float) -> void:
		process_calls += 1
		super._process(delta)

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	Engine.max_fps = 120
	call_deferred("_run")

func check(ok: bool, note: String) -> void:
	if ok:
		passed += 1
		print("PASS battle-resources: ",note)
	else:
		failed += 1
		printerr("FAIL battle-resources: ",note)

func wait_for(condition: Callable, milliseconds: int = 8000) -> bool:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < milliseconds:
		if condition.call(): return true
		await process_frame
	return bool(condition.call())

func _run() -> void:
	var loader = ObservedLoader.new()
	root.add_child(loader)
	await process_frame
	check(not loader.is_processing(),"empty loader starts asleep")
	var before: int = loader.process_calls
	for i in range(12): await process_frame
	check(loader.process_calls==before,"idle loader receives zero frame callbacks")

	var first: String = "res://assets/battle/effects/heal-cross.png"
	var second: String = "res://assets/battle/sfx/ui.ogg"
	loader.enqueue(first)
	loader.enqueue(first)
	loader.enqueue(second)
	check(loader.is_processing(),"enqueue wakes loader")
	check(loader.pending.size()==2,"duplicate request is not queued twice")
	var ready: bool = await wait_for(func(): return loader.resources.has(first) and loader.resources.has(second))
	check(ready and loader.resources.get(first)!=null and loader.resources.get(second)!=null,"real texture and audio finish background loading")
	await process_frame
	check(loader.pending.is_empty() and loader.requested.is_empty() and not loader.is_processing(),"completed work drains and sleeps")
	before = loader.process_calls
	for i in range(12): await process_frame
	check(loader.process_calls==before,"completed loader no longer polls")

	var late: String = "res://assets/battle/effects/combat-labels-sheet.jpg"
	loader.enqueue(late)
	check(loader.is_processing(),"later request restarts processing")
	ready = await wait_for(func(): return loader.resources.has(late))
	check(ready and loader.resources.get(late)!=null,"later request produces real texture")
	await process_frame
	check(not loader.is_processing(),"loader returns to sleep after later request")

	# Simulate an orphaned request (engine reports INVALID_RESOURCE).
	# This is a terminal failure path and must not leave a permanent poll.
	var orphan: String = "res://not_a_requested_resource.tres"
	loader.requested[orphan] = true
	loader.set_process(true)
	await process_frame
	await process_frame
	check(loader.resources.has(orphan) and loader.resources[orphan]==null,"invalid request is recorded as a failed resource")
	check(loader.requested.is_empty() and not loader.is_processing(),"invalid request cannot keep the loader awake")

	loader.enqueue(first)
	loader.enqueue("res://missing_battle_resource.png")
	check(not loader.is_processing() and loader.pending.is_empty(),"cached and missing paths do not wake an idle loader")
	loader.queue_free()
	await process_frame
	# Two scene owners can exit in the same frame with equal pending paths.
	# Distinct cleanup callbacks must survive value-equal bound arrays.
	var exiting_before: int=root.tree_exiting.get_connections().size()
	var owners: Array=[]
	for i in range(2):
		var leaving=ObservedLoader.new()
		root.add_child(leaving)
		leaving.requested["res://orphaned_cleanup_a.tres"]=true
		leaving.requested["res://orphaned_cleanup_b.tres"]=true
		owners.append(leaving)
	for leaving in owners:
		root.remove_child(leaving)
		leaving.free()
	check(root.tree_exiting.get_connections().size()==exiting_before+2,"equal pending paths retain two independent scene cleanup callbacks")
	await process_frame
	await process_frame
	check(root.tree_exiting.get_connections().size()==exiting_before,"both exited-scene cleanup callbacks release after draining")
	print("BATTLE_RESOURCE_LIFECYCLE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
