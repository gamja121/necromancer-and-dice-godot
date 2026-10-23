extends RefCounted
## Six boss-only candidates; draw three distinct species once per NEW run.
## A separate RNG uses the expedition seed so boss selection never
## advances map/dice RNG. Each stage assignment is stored in the save.
## Old saves without assignments retain the historical provisional roster.
const CANDIDATES = ["death-knight","hydra","kraken","spider-knight","goblin-chief","grave-priest"]
const ASSIGNMENTS = {20:"death-knight",40:"hydra",60:"kraken"} # legacy saves ONLY
const STAGES = [20,40,60]
const FINAL = 80
const PREFIX = "boss:contamination:"

static func legacy_assignments() -> Dictionary:
	return {"20":ASSIGNMENTS[20],"40":ASSIGNMENTS[40],"60":ASSIGNMENTS[60]}

static func roll_assignments(seed_value: int) -> Dictionary:
	var pool: Array = CANDIDATES.duplicate()
	var choice_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	choice_rng.seed = seed_value
	var assigned: Dictionary = {}
	for stage in STAGES:
		assigned[str(stage)] = pool.pop_at(choice_rng.randi_range(0,pool.size()-1))
	return assigned

static func current_stage(contamination: int) -> int:
	if contamination>=FINAL: return FINAL
	for i in range(STAGES.size()-1,-1,-1):
		if contamination>=STAGES[i]: return STAGES[i]
	return 0

static func stage_flag(stage: int) -> String:
	return "%s%d:defeated" % [PREFIX,stage]

static func defeated(flags: Dictionary, stage: int) -> bool:
	return flags.get(stage_flag(stage),false)==true

static func boss_slug(stage: int, assignments: Dictionary = {}) -> String:
	if stage==FINAL: return "dragon"
	return str(assignments.get(str(stage),ASSIGNMENTS.get(stage,"")))

static func reserved_slugs() -> Array:
	return CANDIDATES.duplicate()+["dragon"]

static func valid(definitions: Dictionary, assignments: Dictionary = {}) -> bool:
	var seen: Array = []
	for stage in STAGES:
		var slug: String = boss_slug(stage,assignments)
		if slug.is_empty() or slug in seen or slug not in CANDIDATES: return false
		if not definitions.has(slug) or str(definitions[slug].grade) not in ["normal","advanced","hero"]: return false
		seen.append(slug)
	return true
