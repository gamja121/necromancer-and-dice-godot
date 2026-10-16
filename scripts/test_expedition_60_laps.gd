extends SceneTree
## Deterministic 60-lap real MapState progression and boss tile invariant.
## This tests board progression, NOT combat/event/reward UI or boss victory.
const State = preload("res://systems/map_state.gd")
const LAPS = 60
const SEEDS = 30

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json"))
	if not parsed is Dictionary or not parsed.has("units"):
		printerr("EXPEDITION ERROR missing units")
		quit(1)
		return
	var failures := 0
	var boss_first_laps: Dictionary = {}
	for seed_value in range(SEEDS):
		var world = State.new(parsed.units, seed_value + 74001)
		var first_boss := -1
		for lap_index in range(1,LAPS + 1):
			var rolls := 0
			while not world.lap_ready and rolls < 30:
				rolls += 1
				world.move_path(world.rng.randi_range(1,6))
			if not world.lap_ready:
				printerr("EXPEDITION ERROR no home seed=",seed_value," lap=",lap_index)
				failures += 1
				break
			world.leave_home()
			if world.laps != lap_index or world.contamination != mini(100,lap_index * State.LAP_CONTAMINATION_GAIN):
				printerr("EXPEDITION ERROR lap/contamination seed=",seed_value," lap=",lap_index)
				failures += 1
				break
			if world.tiles.size() != 24 or world.tiles[State.HOME] != "home":
				printerr("EXPEDITION ERROR invalid board seed=",seed_value," lap=",lap_index)
				failures += 1
				break
			var has_boss: bool = world.tiles[State.BOSS_TILE_INDEX] == "boss"
			if world.contamination >= State.BOSS_CONTAMINATION and not has_boss:
				printerr("EXPEDITION ERROR boss missing seed=",seed_value," lap=",lap_index)
				failures += 1
				break
			if has_boss and first_boss == -1:
				first_boss = lap_index
			if lap_index in [20,40,60]:
				print("EXPEDITION seed=",seed_value," lap=",lap_index," contamination=",world.contamination," boss_tile=",has_boss)
		boss_first_laps[first_boss] = int(boss_first_laps.get(first_boss,0)) + 1
	print("EXPEDITION seeds=",SEEDS," target_laps=",LAPS," failures=",failures," first_boss_laps=",boss_first_laps)
	quit(0 if failures == 0 else 1)
