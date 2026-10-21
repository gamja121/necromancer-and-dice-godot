extends Node
## Keeps a bounded set of shared battle assets alive; reads them off the UI thread.
var resources: Dictionary = {}
var pending: Array[String] = []
var requested: Dictionary = {}
var queued: Dictionary = {}

# A static callable outlives the scene without keeping a dead Node alive.
# Claim finished requests on later frames if their owner exits mid-load.
class PendingLoads extends RefCounted:
	static func flush(paths: Array) -> void:
		# Only application shutdown may join unfinished work. Normal scene
		# transitions use finish() and never wait for an in-flight request.
		for path in paths:
			if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				ResourceLoader.load_threaded_get(path)
		paths.clear()

	static func finish(tree: SceneTree, paths: Array, shutdown: Callable) -> void:
		var finished: String = ""
		for path in paths:
			var status = ResourceLoader.load_threaded_get_status(path)
			if status in [ResourceLoader.THREAD_LOAD_LOADED,ResourceLoader.THREAD_LOAD_FAILED]:
				ResourceLoader.load_threaded_get(path)
				finished = path
				break
			if status==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				finished = path
				break
		if not finished.is_empty(): paths.erase(finished)
		if not paths.is_empty():
			tree.process_frame.connect(finish.bind(tree,paths,shutdown),CONNECT_ONE_SHOT)
		elif tree.root.tree_exiting.is_connected(shutdown):
			tree.root.tree_exiting.disconnect(shutdown)

func _exit_tree() -> void:
	if requested.is_empty(): return
	var paths: Array = requested.keys()
	requested.clear()
	var shutdown: Callable = PendingLoads.flush.bind(paths)
	get_tree().root.tree_exiting.connect(shutdown,CONNECT_ONE_SHOT)
	PendingLoads.finish(get_tree(),paths,shutdown)

func _ready() -> void:
	set_process(not pending.is_empty() or not requested.is_empty())


# Only battle-owned frame references count toward this additional warmup.
# This is a decoded RGBA estimate, not a cap on the whole game's memory.
const FRAME_WARMUP_BUDGET: int = 32*1024*1024
var reserved_frame_bytes: int = 0
var warmed_species: Dictionary = {}

func warm_combatants(units: Array, metrics: Dictionary) -> void:
	var species: Array[String] = []
	var longest: int = 0
	for unit in units:
		var slug: String = str(unit.get("slug",""))
		if not unit.get("alive",true) or warmed_species.has(slug) or not metrics.has(slug): continue
		warmed_species[slug] = true
		species.append(slug)
		for motion in ["attack","hit","death"]:
			var frames: Array = metrics[slug].get(motion,[])
			longest = maxi(longest,frames.size())
	# Round-robin participants: warm each actor's next attack frame before
	# later frames. Attack-01 is already required by the visible battlefield.
	for step in range(longest):
		for motion in ["attack","hit","death"]:
			for slug in species:
				var profile: Dictionary = metrics[slug]
				var frames: Array = profile.get(motion,[])
				var index: int = step+(1 if motion=="attack" else 0)
				if index>=frames.size(): continue
				var path: String = "res://assets/battle/frames/%s/%s-%02d.png" % [slug,motion,int(frames[index])]
				if queued.has(path) or ResourceLoader.has_cached(path) or not ResourceLoader.exists(path): continue
				var bytes: int = int(profile.get("width",0))*int(profile.get("height",0))*4
				if bytes<=0 or reserved_frame_bytes+bytes>FRAME_WARMUP_BUDGET: continue
				reserved_frame_bytes += bytes
				enqueue(path)

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
	set_process(true)

func _process(_delta: float) -> void:
	if not pending.is_empty():
		var path: String = pending.pop_front()
		var result = ResourceLoader.load_threaded_request(path)
		if result == OK: requested[path] = true
		else: resources[path] = null
	# Never block waiting for unfinished disk work. Accept at most one result per frame.
	var finished: String = ""
	for path in requested:
		var status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			resources[path] = ResourceLoader.load_threaded_get(path)
			finished = path
			break
		if status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			if status==ResourceLoader.THREAD_LOAD_FAILED: ResourceLoader.load_threaded_get(path)
			resources[path] = null
			finished = path
			break
	if not finished.is_empty(): requested.erase(finished)
	if pending.is_empty() and requested.is_empty(): set_process(false)
