extends RefCounted
## Six possible stage bosses; draw three distinct species once per NEW run.
## Only the three actually assigned for this expedition stay out of normal
## hero-grade encounters and random rewards. Unchosen candidates are regular
## hero species. The dragon stays final-only.
## A separate RNG uses the expedition seed so boss selection never
## advances map/dice RNG. Each stage assignment is stored in the save.
## Old saves without assignments retain the historical provisional roster.
const CANDIDATES = ["death-knight","hydra","kraken","spider-knight","goblin-chief","grave-priest"]
const ASSIGNMENTS = {20:"death-knight",40:"hydra",60:"kraken"} # legacy saves ONLY
const STAGES = [20,40,60]
const FINAL = 80
const PREFIX = "boss:contamination:"

# Restore the original tier escorts around the assigned boss in slot 1.
# Normal combat uses slots 0–3 and leaves slot 4 available for summons.
const FORMATIONS = {
	"death-knight": {
		20: ["skeleton-spear", "death-knight", "bone-hound"],
		40: ["skeleton-archer", "death-knight", "doom-executor", "bone-hound"],
		60: ["doom-executor", "death-knight", "cerberus", "bone-hound"]
	},
	"hydra": {
		20: ["plague-frog", "hydra", "corpse-slime"],
		40: ["plague-frog", "hydra", "flesh-golem", "corpse-slime"],
		60: ["flesh-golem", "hydra", "plague-doctor", "grave-worm"]
	},
	"kraken": {
		20: ["sea-wolf", "kraken", "corpse-slime"],
		40: ["sea-wolf", "kraken", "ice-lord", "corpse-slime"],
		60: ["ice-lord", "kraken", "siren", "sea-wolf"]
	},
	"spider-knight": {
		20: ["plague-frog", "spider-knight", "corpse-slime"],
		40: ["plague-frog", "spider-knight", "abyss-claw-hunter", "corpse-slime"],
		60: ["abyss-claw-hunter", "spider-knight", "scorpion-knight", "plague-doctor"]
	},
	"goblin-chief": {
		20: ["goblin-soldier", "goblin-chief", "bone-hound"],
		40: ["goblin-soldier", "goblin-chief", "orc-warrior", "goblin-rider"],
		60: ["minotaur", "goblin-chief", "orc-warrior", "goblin-rider"]
	},
	"grave-priest": {
		20: ["skeleton-spear", "grave-priest", "ghoul"],
		40: ["skeleton-archer", "grave-priest", "skeleton-cavalry", "ghoul"],
		60: ["bone-golem", "grave-priest", "skeleton-cavalry", "skeleton-archer"]
	}
}

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

## Actual appearances, not historical pollution peaks, survive purification.
static func revealed_flag(stage: int) -> String:
	return "%s%d:revealed" % [PREFIX,stage]

static func highest_revealed(flags: Dictionary) -> int:
	var highest: int = 0
	for stage in [20,40,60,80]:
		if flags.get(revealed_flag(stage),false)==true: highest=stage
	return highest

static func defeated(flags: Dictionary, stage: int) -> bool:
	return flags.get(stage_flag(stage),false)==true

static func boss_slug(stage: int, assignments: Dictionary = {}) -> String:
	if stage==FINAL: return "dragon"
	return str(assignments.get(str(stage),ASSIGNMENTS.get(stage,"")))

static func formation(stage: int, assignments: Dictionary) -> Array:
	var slug := boss_slug(stage,assignments)
	if stage == FINAL: return [slug]
	return FORMATIONS.get(slug,{}).get(stage,[]).duplicate()


static func reserved_slugs(assignments: Dictionary = {}) -> Array:
	var reserved: Array = ["dragon"]
	for stage in STAGES:
		var slug: String = boss_slug(stage,assignments)
		if not slug.is_empty() and not slug in reserved: reserved.append(slug)
	return reserved

static func valid(definitions: Dictionary, assignments: Dictionary = {}) -> bool:
	var seen: Array = []
	for stage in STAGES:
		var slug: String = boss_slug(stage,assignments)
		if slug.is_empty() or slug in seen or slug not in CANDIDATES: return false
		if not definitions.has(slug) or str(definitions[slug].grade) not in ["normal","advanced","hero"]: return false
		seen.append(slug)
	return true
