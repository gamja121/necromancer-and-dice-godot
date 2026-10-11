extends RefCounted
## Original ritualPortalEnemySlugs: four distinct normal/advanced/hero
## enemies; first is hero if available, otherwise advanced.
const FALLBACK = ["death-knight","doom-executor","plague-doctor","hydra"]

static func select(definitions: Dictionary, rng: RandomNumberGenerator) -> Array:
	if rng==null: return []
	var eligible: Array=[]
	var heroes: Array=[]
	var advanced: Array=[]
	for slug in definitions:
		var grade: String=str(definitions[slug].get("grade",""))
		if grade not in ["normal","advanced","hero"]: continue
		eligible.append(str(slug))
		if grade=="hero": heroes.append(str(slug))
		elif grade=="advanced": advanced.append(str(slug))
	if eligible.size()<4:
		return FALLBACK.duplicate() if valid(definitions,FALLBACK) else []
	var anchor_pool: Array=heroes if not heroes.is_empty() else advanced
	if anchor_pool.is_empty(): return []
	var anchor: String=str(anchor_pool[rng.randi_range(0,anchor_pool.size()-1)])
	var chosen: Array=[anchor]
	eligible.erase(anchor)
	while chosen.size()<4 and not eligible.is_empty():
		chosen.append(eligible.pop_at(rng.randi_range(0,eligible.size()-1)))
	return chosen

static func valid(definitions: Dictionary, slugs: Array) -> bool:
	if slugs.size()!=4: return false
	var found: Dictionary={}
	var has_hero: bool=false
	for slug in definitions:
		if str(definitions[slug].get("grade",""))=="hero":
			has_hero=true
			break
	for i in range(slugs.size()):
		var slug: String=str(slugs[i])
		if found.has(slug) or not definitions.has(slug): return false
		found[slug]=true
		var grade: String=str(definitions[slug].get("grade",""))
		if grade not in ["normal","advanced","hero"]: return false
		if i==0 and grade!=("hero" if has_hero else "advanced"): return false
	return true
