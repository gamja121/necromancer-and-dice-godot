extends Node
## Keeps a bounded set of shared battle assets alive; reads them off the UI thread.
var resources: Dictionary = {}
var pending: Array[String] = []
var requested: Dictionary = {}
var queued: Dictionary = {}

func setup(world) -> void:
	var metadata = JSON.parse_string(FileAccess.get_file_as_string("res://assets/battle/effects/original_effects.json"))
	for config in metadata.effects.values():
		enqueue("res://assets/battle/effects/"+String(config.sheet).get_file())
	for name in ["damage-digits-sheet.jpg","healing-digits-sheet.jpg","combat-labels-sheet.jpg","status-labels-sheet.jpg","summon-effect-sheet.jpg","heal-cross.png"]:
		enqueue("res://assets/battle/effects/"+name)
	for path in ["res://assets/battle/music/battle.mp3","res://assets/battle/sfx/ui.ogg","res://assets/battle/ui/battle-deck-selection-board.png","res://assets/map/ui/battle_frame.png","res://assets/battle/ui/legion-slot-frame.png"]:
		enqueue(path)
	var regions = {"default":"dark-forest","winter":"snow-forest","hell":"lava-forest"}
	enqueue("res://assets/battle/backgrounds/%s.jpg" % regions.get(world.region,"dark-forest"))
	for unit in world.roster:
		enqueue("res://assets/cards/unit-card-%s.png" % unit.slug)
		enqueue("res://assets/battle/frames/%s/attack-01.png" % unit.slug)

func enqueue(path: String) -> void:
	if queued.has(path) or not ResourceLoader.exists(path): return
	queued[path] = true
	pending.append(path)

func _process(_delta: float) -> void:
	if not pending.is_empty():
		var path: String = pending.pop_front()
		var result = ResourceLoader.load_threaded_request(path)
		if result == OK: requested[path] = true
	# Never block waiting for unfinished disk work. Accept at most one result per frame.
	for path in requested:
		if resources.has(path): continue
		var status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			resources[path] = ResourceLoader.load_threaded_get(path)
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED:
			resources[path] = null
			break
