extends RefCounted

const ROSTER = ["death-knight","skeleton-spear","skeleton-archer","skeleton-cavalry","grave-worm","flesh-golem","ghoul","boulder-ogre","plague-doctor","plague-frog","hydra","minotaur","yeti","ice-lord","sea-wolf","spider-knight","spiderling","goblin-chief","goblin-commoner","goblin-soldier","grave-priest","doom-executor","abyss-eye","hell-mantis","abyss-claw-hunter","corpse-slime","scorpion-knight","ancient-treant","stone-golem","kraken","crystal-devourer","raging-treant","cerberus","mushroom-soldier","goblin-rider","abyss-harpy","orc-warrior","bone-golem","forest-fairy","mummy-guardian","soul-reaper","bone-hound","mimic","ice-princess","siren","dracula"]
# All non-summoned species, including Dracula and stage-boss candidates not
# selected this expedition, may enter encounters/rewards at their normal
# grade. This expedition's three bosses and the final dragon are protected.
const BossStages = preload("res://systems/boss_stage_catalog.gd")
const GRADES = ["normal","advanced","hero"]
const STAGES = [
	{"min":0,"counts":[1,2],"weights":[0.65,0.35],"grades":[0.90,0.10,0.0]},
	{"min":20,"counts":[2],"weights":[1.0],"grades":[0.75,0.25,0.0]},
	{"min":40,"counts":[2,3],"weights":[0.65,0.35],"grades":[0.55,0.40,0.05]},
	{"min":60,"counts":[3],"weights":[1.0],"grades":[0.35,0.50,0.15]},
	{"min":80,"counts":[3,4],"weights":[0.55,0.45],"grades":[0.20,0.55,0.25]}
]

static func eligible_roster(definitions: Dictionary, boss_assignments: Dictionary = {}) -> Array:
	var reserved: Array = BossStages.reserved_slugs(boss_assignments)
	return ROSTER.filter(func(slug): return definitions.has(slug) and definitions[slug].grade in GRADES and not slug in reserved)

static func stage(contamination: int) -> Dictionary:
	for index in range(STAGES.size()-1,-1,-1):
		if contamination>=STAGES[index].min: return STAGES[index]
	return STAGES[0]

static func weighted(values: Array, weights: Array, rng: RandomNumberGenerator):
	var total = 0.0
	for weight in weights: total += float(weight)
	var roll = rng.randf()*total
	for index in range(values.size()):
		roll -= float(weights[index])
		if roll<=0: return values[index]
	return values.back()

static func constrained_count(requested: int, loop: int) -> int:
	return 1 if loop<=2 else maxi(2,clampi(requested,1,4))

static func mimic_count(contamination: int, loop: int) -> int:
	var requested = 4 if contamination>=80 else (3 if contamination>=60 else (2 if contamination>=20 else 1))
	return constrained_count(requested,loop)

# Green stones always field normal monsters. Purple rare stones field exactly
# one advanced/hero anchor plus ordinary support at higher group sizes.
# This keeps the map indicator truthful and retains the existing group-size
# and stage-based elite-vs-hero weighting without adding extra battles.
static func slugs(definitions: Dictionary, contamination: int, loop: int, rng: RandomNumberGenerator, intel: Dictionary = {}, tile_kind: String = "monster", boss_assignments: Dictionary = {}) -> Array:
	var current: Dictionary = stage(contamination)
	var requested: int = int(intel.count) if not intel.is_empty() else int(weighted(current.counts,current.weights,rng))
	var count: int = constrained_count(requested,loop)
	var available: Array = eligible_roster(definitions,boss_assignments)
	var normal_pool: Array = available.filter(func(slug): return str(definitions[slug].grade)=="normal")
	var elite_pool: Array = available.filter(func(slug): return str(definitions[slug].grade) in ["advanced","hero"])
	var rare: bool = tile_kind=="rare-monster"
	var first_pool: Array = elite_pool if rare else normal_pool
	if first_pool.is_empty() or normal_pool.is_empty(): return []
	var grade: String = "normal"
	if rare:
		grade = str(intel.get("grade",""))
		if grade not in ["advanced","hero"]:
			grade = str(weighted(["advanced","hero"],[float(current.grades[1]),float(current.grades[2])],rng))
	var anchors: Array = first_pool.filter(func(slug): return str(definitions[slug].grade)==grade)
	if not intel.is_empty() and str(intel.get("grade",""))==grade:
		var legion: String = str(intel.get("legion",""))
		var matched: Array = anchors.filter(func(slug): return legion in definitions[slug].legions)
		if not matched.is_empty(): anchors=matched
	if anchors.is_empty(): anchors=first_pool
	var first: String = str(anchors[rng.randi_range(0,anchors.size()-1)])
	var result: Array = [first]
	normal_pool.erase(first)
	while result.size()<count and not normal_pool.is_empty():
		var index: int = rng.randi_range(0,normal_pool.size()-1)
		result.append(normal_pool.pop_at(index))
	return result

static func scout_intel(definitions: Dictionary, contamination: int, loop: int, rng: RandomNumberGenerator, index: int, type: String, boss_assignments: Dictionary = {}) -> Dictionary:
	var current: Dictionary = stage(contamination)
	var count: int = constrained_count(int(weighted(current.counts,current.weights,rng)),loop)
	var grade: String = "normal"
	if type=="rare-monster":
		grade = str(weighted(["advanced","hero"],[float(current.grades[1]),float(current.grades[2])],rng))
	var pool: Array = eligible_roster(definitions,boss_assignments).filter(func(slug): return str(definitions[slug].grade)==grade and not definitions[slug].legions.is_empty())
	if pool.is_empty(): return {}
	var anchor: Dictionary = definitions[pool[rng.randi_range(0,pool.size()-1)]]
	var legion: String = str(anchor.legions[rng.randi_range(0,anchor.legions.size()-1)])
	return {"index":index,"type":type,"count":count,"grade":grade,"legion":legion}
