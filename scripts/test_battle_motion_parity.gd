extends SceneTree
## W195: all production frame assets and on-screen BattleField motion pathways.
## The 46 fixed web species plus the retained Godot Dracula must work.
const BattleScene = preload("res://battlefield.tscn")
const Layout = preload("res://systems/battle_presentation_layout.gd")

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS battle-motion: ",message)
	else:
		failed += 1
		printerr("FAIL battle-motion: ",message)

func _run() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json"))
	if not parsed is Dictionary:
		check(false,"Godot unit source parse")
		quit(1)
		return
	var defs: Dictionary = parsed.units
	var layout = Layout.new()
	check(layout.metrics.size()==defs.size() and defs.size()==47,
		"all 46 original species and retained Dracula have motion profiles")
	var missing: Array[String] = []
	var decoded_count: int = 0
	for slug in defs:
		var profile: Dictionary = layout.metrics.get(slug,{})
		if profile.is_empty():
			missing.append(str(slug)+":metadata")
			continue
		for motion in ["attack","hit","death"]:
			var frames: Array = layout.frames(str(slug),motion)
			if frames.is_empty():
				missing.append(str(slug)+":"+motion+":empty")
				continue
			for j in range(frames.size()):
				var frame: int = int(frames[j])
				if frame != j+1:
					missing.append("%s:%s:non-consecutive-%d" % [slug,motion,frame])
				var file: String = "res://assets/battle/frames/%s/%s-%02d.png" % [slug,motion,frame]
				if not ResourceLoader.exists(file):
					missing.append(file)
					continue
				var texture: Texture2D = load(file) as Texture2D
				if texture==null or texture.get_width()<=0 or texture.get_height()<=0:
					missing.append(file+":decode")
				else:
					decoded_count += 1
					if slug in ["guardian-seed","goblin-commoner","soul-reaper"]:
						var nonblank = texture.get_image().get_used_rect()
						if nonblank.size.x<=0 or nonblank.size.y<=0:
							missing.append(file+":transparent")
	check(missing.is_empty(),"all exact production motion paths decode: "+", ".join(missing.slice(0,12)))
	check(decoded_count>700,"actual engine decoded %d attack/hit/death images" % decoded_count)
	for expected in [["guardian-seed",[5,3,4]],["goblin-commoner",[10,7,8]],["soul-reaper",[6,4,6]]]:
		var slug: String = expected[0]
		var counts: Array = expected[1]
		for i in range(3):
			var motion: String=["attack","hit","death"][i]
			check(layout.frames(slug,motion).size()==counts[i],"%s %s frame count %d" % [slug,motion,counts[i]])

	# Instantiate the actual production battlefield. The preexisting lab path
	# is used only to make a visual test party; save files are untouched.
	var scene = BattleScene.instantiate()
	scene.selection = ["guardian-seed","goblin-commoner","soul-reaper","dracula"]
	root.add_child(scene)
	await process_frame
	var actor_ids: Dictionary = {}
	for unit in scene.rules.units:
		if unit.team=="ally" and unit.slug in scene.selection:
			actor_ids[unit.slug] = unit.id
	check(actor_ids.size()==4,"actual battlefield rendered test monsters through the production scene")
	for slug in ["guardian-seed","goblin-commoner","soul-reaper"]:
		if not actor_ids.has(slug): continue
		var id: String = actor_ids[slug]
		var unit: Dictionary = scene.rules.find_id(id)
		check(scene.sprites.has(id) and scene.sprites[id].texture!=null,slug+" live sprite is visible")
		check(scene.cards.has(id) and scene.cards[id].texture_normal!=null,slug+" live battle card is present")
		for motion in ["attack","hit","death"]:
			# Exercise the real BattleField.animate_unit coroutine, not a
			# test-only image path. It advances frames using in-engine ticks.
			await scene.animate_unit(id,motion)
			var final_path: String = scene.frame_path(unit,motion,int(scene.motion_frames(unit,motion).back()))
			check(scene.sprites[id].texture==scene.texture(final_path),
				"%s %s animation finishes on its real final frame" % [slug,motion])
			scene.render_units(scene.rules.units)

	if actor_ids.has("soul-reaper"):
		var id: String = actor_ids["soul-reaper"]
		var enemy_id: String = scene.rules.units[4].id
		await scene.visuals.play_strike(id,enemy_id,{})
		check(not scene.visuals.active.has(id),"actual BattleVisuals.play_strike completes all attack frames")

	if actor_ids.has("goblin-commoner"):
		var id: String = actor_ids["goblin-commoner"]
		var u: Dictionary = scene.rules.find_id(id)
		var target: Dictionary = scene.rules.units.duplicate(true)[0]
		var before: Array=[u.duplicate(true)]
		var dead: Dictionary=u.duplicate(true)
		dead.alive=false
		dead.hp=0
		dead.is_summon=true
		await scene.visuals.play_deaths(before,[dead])
		var last_death_path: String=scene.frame_path(dead,"death",int(scene.motion_frames(dead,"death").back()))
		check(scene.sprites[id].texture==scene.texture(last_death_path),"actual death presentation shows final frame")
		check(scene.visuals.removed.has(id),"summoned unit death removes expired sprite")

	scene.queue_free()
	print("BATTLE_MOTION_PARITY_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
