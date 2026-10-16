extends SceneTree
## Deterministic balance smoke simulation; no combat rule changes.
const Rules = preload("res://systems/battlefield_rules.gd")
const TRIALS = 2000
const ALLY_BRANDS = 3
const ALTAR_LEVEL = 3
const ROUND_CAP = 80

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json"))
	if not parsed is Dictionary or not parsed.has("units"):
		printerr("BALANCE ERROR: units.json missing units")
		quit(1)
		return
	var definitions: Dictionary = parsed.units
	var pool: Array = []
	for slug in definitions:
		var d: Dictionary = definitions[slug]
		if str(d.get("grade","")) != "special" and d.has("hp") and d.has("attack") and d.has("speed"):
			pool.append(str(slug))
	pool.sort()
	if pool.size() < 8:
		printerr("BALANCE ERROR: too few valid units")
		quit(1)
		return
	var wins := 0
	var losses := 0
	var timeouts := 0
	var rounds_sum := 0
	var first_ally_deaths := 0
	var unit_wins: Dictionary = {}
	var unit_uses: Dictionary = {}
	for trial in range(TRIALS):
		var rng = RandomNumberGenerator.new()
		rng.seed = trial + 81001
		var battle = Rules.new(definitions,trial + 92001)
		var allies: Array = []
		var enemies: Array = []
		for i in range(4):
			var a_slug: String = pool[rng.randi_range(0,pool.size()-1)]
			var e_slug: String = pool[rng.randi_range(0,pool.size()-1)]
			var ally: Dictionary = battle.individual(a_slug,"a%d" % i)
			# Altar level 3: +3 attack, +6 max/current HP; three sacrifices in actual gameplay.
			ally.attack = int(ally.attack) + ALTAR_LEVEL
			ally.max_hp = int(ally.max_hp) + 2 * ALTAR_LEVEL
			ally.current_hp = ally.max_hp
			ally.altar_enhancements = ALTAR_LEVEL
			# Three equipped brand slots (including original innate brand if present).
			while ally.brands.size() < ALLY_BRANDS:
				var kinds: Array = battle.COUNTS.keys()
				ally.brands.append(battle.make_brand(str(kinds[rng.randi_range(0,kinds.size()-1)])))
			allies.append(ally)
			enemies.append(battle.individual(e_slug,"e%d" % i))
			unit_uses[a_slug] = int(unit_uses.get(a_slug,0)) + 1
		battle.start(allies,enemies)
		var first_dead := false
		for round_index in range(ROUND_CAP):
			if not battle.winner().is_empty():
				break
			battle.begin_round()
			for action_index in range(80):
				if battle.next_action().is_empty():
					break
			if not first_dead and battle.living("ally").size() < 4:
				first_dead = true
		var result: String = battle.winner()
		rounds_sum += battle.round_number
		if first_dead:
			first_ally_deaths += 1
		if result == "ally":
			wins += 1
			for u in allies:
				unit_wins[u.slug] = int(unit_wins.get(u.slug,0)) + 1
		elif result == "enemy":
			losses += 1
		else:
			timeouts += 1
	print("BALANCE setup=ally4_brand3_altar3 enemy4_unmodified")
	print("BALANCE trials=",TRIALS," units=",pool.size()," ally_wins=",wins," enemy_wins=",losses," timeouts=",timeouts)
	print("BALANCE mean_rounds=",float(rounds_sum)/TRIALS," ally_first_death_rate=",float(first_ally_deaths)/TRIALS)
	for slug in pool:
		if int(unit_uses.get(slug,0)) >= 20:
			print("UNIT ",slug," picked=",unit_uses[slug]," ally_win_rate=",float(unit_wins.get(slug,0))/float(unit_uses[slug]))
	if timeouts > TRIALS / 20:
		printerr("BALANCE WARNING: more than 5% unresolved by round ",ROUND_CAP)
	quit(0)
