extends RefCounted

const ROSTER = ["death-knight","skeleton-spear","skeleton-archer","skeleton-cavalry","grave-worm","flesh-golem","ghoul","boulder-ogre","plague-doctor","plague-frog","hydra","minotaur","yeti","ice-lord","sea-wolf","spider-knight","spiderling","goblin-chief","goblin-commoner","goblin-soldier","grave-priest","doom-executor","abyss-eye","hell-mantis","abyss-claw-hunter","corpse-slime","scorpion-knight","ancient-treant","stone-golem","kraken","crystal-devourer","raging-treant","cerberus","mushroom-soldier","goblin-rider","abyss-harpy","orc-warrior","bone-golem","forest-fairy","mummy-guardian","soul-reaper","bone-hound","mimic","ice-princess","siren","dracula"]
const GRADES = ["normal","advanced","hero"]
const STAGES = [
	{"min":0,"counts":[1,2],"weights":[0.65,0.35],"grades":[0.90,0.10,0.0]},
	{"min":20,"counts":[2],"weights":[1.0],"grades":[0.75,0.25,0.0]},
	{"min":40,"counts":[2,3],"weights":[0.65,0.35],"grades":[0.55,0.40,0.05]},
	{"min":60,"counts":[3],"weights":[1.0],"grades":[0.35,0.50,0.15]},
	{"min":80,"counts":[3,4],"weights":[0.55,0.45],"grades":[0.20,0.55,0.25]}
]

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

static func slugs(definitions: Dictionary, contamination: int, loop: int, rng: RandomNumberGenerator, intel: Dictionary = {}) -> Array:
	var current = stage(contamination)
	var requested = int(intel.count) if not intel.is_empty() else int(weighted(current.counts,current.weights,rng))
	var count = constrained_count(requested,loop)
	var available: Array = ROSTER.filter(func(slug): return definitions.has(slug) and definitions[slug].grade in GRADES)
	var result: Array = []
	if not intel.is_empty():
		var anchors = available.filter(func(slug): return definitions[slug].grade==intel.grade and intel.legion in definitions[slug].legions)
		if not anchors.is_empty():
			var anchor = anchors[rng.randi_range(0,anchors.size()-1)]
			result.append(anchor)
			available.erase(anchor)
	while result.size()<count and not available.is_empty():
		var grade: String = weighted(GRADES,current.grades,rng)
		var candidates = available.filter(func(slug): return definitions[slug].grade==grade)
		if candidates.is_empty(): candidates = available
		var chosen = candidates[rng.randi_range(0,candidates.size()-1)]
		result.append(chosen)
		available.erase(chosen)
	return result

static func scout_intel(definitions: Dictionary, contamination: int, loop: int, rng: RandomNumberGenerator, index: int, type: String) -> Dictionary:
	var current = stage(contamination)
	var count = constrained_count(int(weighted(current.counts,current.weights,rng)),loop)
	var grade: String = weighted(GRADES,current.grades,rng)
	var pool: Array = ROSTER.filter(func(slug): return definitions.has(slug) and definitions[slug].grade in GRADES and not definitions[slug].legions.is_empty())
	var candidates = pool.filter(func(slug): return definitions[slug].grade==grade)
	if candidates.is_empty():
		grade = definitions[pool[rng.randi_range(0,pool.size()-1)]].grade
		candidates = pool.filter(func(slug): return definitions[slug].grade==grade)
	var anchor: Dictionary = definitions[candidates[rng.randi_range(0,candidates.size()-1)]]
	var legion: String = anchor.legions[rng.randi_range(0,anchor.legions.size()-1)]
	return {"index":index,"type":type,"count":count,"grade":grade,"legion":legion}
