extends RefCounted
## Three different heroes are reserved for the 20/40/60 boss gates at run creation.
## The unselected candidates remain in the ordinary reward/encounter roster.
const CANDIDATES = ["grave-priest","spider-knight","goblin-chief","kraken","crystal-devourer","hydra"]
const TIERS = [20,40,60]
# Formation order is enemy slot 0, 1 (boss), 2, 3. Slot 4 is for summons.
const FORMATIONS = {
	"grave-priest": {
		20:["skeleton-spear","grave-priest","ghoul"],
		40:["skeleton-archer","grave-priest","skeleton-cavalry","ghoul"],
		60:["bone-golem","grave-priest","skeleton-cavalry","skeleton-archer"]},
	"spider-knight": {
		20:["plague-frog","spider-knight","corpse-slime"],
		40:["plague-frog","spider-knight","abyss-claw-hunter","corpse-slime"],
		60:["abyss-claw-hunter","spider-knight","scorpion-knight","plague-doctor"]},
	"goblin-chief": {
		20:["goblin-soldier","goblin-chief","bone-hound"],
		40:["goblin-soldier","goblin-chief","orc-warrior","goblin-rider"],
		60:["minotaur","goblin-chief","orc-warrior","goblin-rider"]},
	"kraken": {
		20:["sea-wolf","kraken","corpse-slime"],
		40:["sea-wolf","kraken","ice-lord","corpse-slime"],
		60:["ice-lord","kraken","siren","sea-wolf"]},
	"crystal-devourer": {
		20:["plague-frog","crystal-devourer","grave-worm"],
		40:["mushroom-soldier","crystal-devourer","raging-treant","plague-frog"],
		60:["raging-treant","crystal-devourer","forest-fairy","mushroom-soldier"]},
	"hydra": {
		20:["plague-frog","hydra","corpse-slime"],
		40:["plague-frog","hydra","flesh-golem","corpse-slime"],
		60:["flesh-golem","hydra","plague-doctor","grave-worm"]}
}

static func roll(rng: RandomNumberGenerator) -> Array:
	var pool: Array = CANDIDATES.duplicate()
	var result: Array = []
	for i in range(3):
		result.append(pool.pop_at(rng.randi_range(0,pool.size()-1)))
	return result

static func valid_order(order: Array) -> bool:
	if order.size()!=3: return false
	var seen: Array = []
	for slug in order:
		if not slug is String or not slug in CANDIDATES or slug in seen: return false
		seen.append(slug)
	return true

static func formation(slug: String, tier: int) -> Array:
	return FORMATIONS.get(slug,{}).get(tier,[]).duplicate()

static func valid_formation(definitions: Dictionary, slug: String, tier: int, reserved: Array) -> bool:
	var members: Array = formation(slug,tier)
	if not tier in TIERS or members.size() != (3 if tier==20 else 4) or members[1]!=slug: return false
	if members.count(slug)!=1: return false
	var legion_counts: Dictionary = {}
	var has_advanced := false
	for i in range(members.size()):
		var member: String = str(members[i])
		if not definitions.has(member) or (i!=1 and member in reserved): return false
		var grade: String = str(definitions[member].grade)
		if i==1 and grade!="hero": return false
		if i!=1 and tier==20 and grade!="normal": return false
		if i!=1 and tier==40:
			if grade=="advanced": has_advanced=true
			elif grade!="normal": return false
		for legion in definitions[member].legions:
			legion_counts[legion]=int(legion_counts.get(legion,0))+1
	if tier==40 and not has_advanced: return false
	if tier==60:
		var thresholds={"skeleton":3,"beast":3,"corpse":2,"plague":3,"ice":3,"summon":2,"demon":3,"plant":2,"insect":2,"element":2}
		for legion in thresholds:
			if int(legion_counts.get(legion,0))>=int(thresholds[legion]): return true
		return false
	return true
