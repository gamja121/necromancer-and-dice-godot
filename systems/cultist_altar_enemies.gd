extends RefCounted
## Original HTML-final cultistAltarEnemySlugs: four distinct grade-normal/advanced/hero units.
## First unit is always advanced or hero; fallback matches the original source.
const FALLBACK = ["death-knight","plague-doctor","ghoul","skeleton-spear"]

static func select(definitions: Dictionary, rng: RandomNumberGenerator) -> Array:
	if rng == null: return []
	var eligible: Array = []
	var elite: Array = []
	for slug in definitions:
		var grade: String=str(definitions[slug].get("grade",""))
		if grade not in ["normal","advanced","hero"]: continue
		eligible.append(str(slug))
		if grade in ["advanced","hero"]: elite.append(str(slug))
	if elite.is_empty() or eligible.size()<4:
		for slug in FALLBACK:
			if not definitions.has(slug): return []
		return FALLBACK.duplicate()
	var chosen: Array = []
	var anchor: String=str(elite[rng.randi_range(0,elite.size()-1)])
	chosen.append(anchor)
	eligible.erase(anchor)
	while chosen.size()<4 and not eligible.is_empty():
		chosen.append(eligible.pop_at(rng.randi_range(0,eligible.size()-1)))
	return chosen

static func valid(definitions: Dictionary, slugs: Array) -> bool:
	if slugs.size()!=4 or slugs.duplicate().count(slugs[0])!=1: return false
	var seen: Dictionary = {}
	for i in range(slugs.size()):
		var slug: String=str(slugs[i])
		if seen.has(slug) or not definitions.has(slug): return false
		seen[slug]=true
		var grade: String=str(definitions[slug].get("grade",""))
		if grade not in ["normal","advanced","hero"]: return false
		if i==0 and grade not in ["advanced","hero"]: return false
	return true
