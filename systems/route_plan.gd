extends RefCounted
## Six optional patrol stones. Five ordinary monster stones are AUTO-placed
## independently, so the player spends none of these slots to obtain them.
## Two roads remain reserved for later contamination -> swamp conversion.
## Optional hill stones become selectable only after a genuine event discovery.
## The discovery already grants one permanent hill independent of these slots.
const OPTIONAL_CAPACITY = 6
const AUTO_MONSTERS = 5
const RESERVED_SWAMP_ROADS = 2
const REST_LIMIT = 3
const CHOICES = ["monster","rest","forest"]
const CURRENT = ["basic","basic","basic","forest","rest","event"]
const LEGACY_CURRENT = ["basic","basic","graveyard","forest","rest","event"]
const RESERVE = ["monster","monster","monster","monster","monster"]

static func default_plan() -> Dictionary:
	return {"selection":{"monster":0,"rest":0,"forest":0},"rest_unlocked":false,"rest_discovered":false}

static func is_new(plan) -> bool:
	return plan is Dictionary and plan.has("selection") and plan.get("selection") is Dictionary

static func valid(plan) -> bool:
	if not plan is Dictionary: return false
	if is_new(plan):
		if not plan.get("rest_unlocked",false) is bool: return false
		if not plan.get("rest_discovered",false) is bool: return false
		if bool(plan.get("rest_discovered",false)) and not bool(plan.rest_unlocked): return false
		var selected: Dictionary=plan.selection
		# Legacy modern-plan saves still have only monster/rest. Treat the
		# missing forest count as zero; UI/confirm migrates it on next save.
		if selected.size() not in [2,CHOICES.size()]: return false
		if selected.keys().any(func(kind): return not kind in CHOICES): return false
		var total: int=0
		for tile in CHOICES:
			if not selected.has(tile) and tile!="forest": return false
			var count=selected.get(tile,0)
			if not (count is int or count is float): return false
			if float(count)!=float(int(count)) or int(count)<0: return false
			total+=int(count)
		if total>OPTIONAL_CAPACITY: return false
		# Discovery itself provides one permanent rest tile. Total max 3.
		if int(selected["rest"])>REST_LIMIT-(1 if bool(plan.get("rest_discovered",false)) else 0): return false
		if not plan.rest_unlocked and int(selected["rest"])>0: return false
		return true
	# Old saves continue to restore exactly the original 6+5 inventory.
	if not plan.get("current") is Array or not plan.get("reserve") is Array: return false
	if plan.current.size()!=6 or plan.reserve.size()!=5: return false
	var inventory: Array=plan.current+plan.reserve
	var baseline: Array=LEGACY_CURRENT+RESERVE if inventory.has("graveyard") else CURRENT+RESERVE
	for tile in baseline:
		if inventory.count(tile)!=baseline.count(tile): return false
	return inventory.all(func(tile): return tile in baseline)

static func total_selected(plan: Dictionary) -> int:
	if not is_new(plan): return 0
	return int(plan.selection.get("monster",0))+int(plan.selection.get("rest",0))+int(plan.selection.get("forest",0))

static func available(plan: Dictionary) -> int:
	return OPTIONAL_CAPACITY-total_selected(plan)

static func adjust(plan: Dictionary, tile: String, difference: int) -> Dictionary:
	if not valid(plan) or not is_new(plan) or not tile in CHOICES: return plan.duplicate(true)
	if difference!=1 and difference!=-1: return plan.duplicate(true)
	var next: Dictionary=plan.duplicate(true)
	if not next.selection.has("forest"): next.selection["forest"]=0
	var before: int=int(next.selection[tile])
	next.selection[tile]=before+difference
	return next if valid(next) else plan.duplicate(true)

static func deltas(plan: Dictionary) -> Dictionary:
	if is_new(plan):
		# Every selected optional monster, rest or forest consumes exactly one
		# ordinary road. AUTO_MONSTERS and protected roads are not spendable.
		var monsters: int=int(plan.selection.get("monster",0))
		var rests: int=int(plan.selection.get("rest",0))
		var forests: int=int(plan.selection.get("forest",0))
		return {"basic":-(monsters+rests+forests),"monster":monsters,"rest":rests,"forest":forests}
	# A legacy save used a DIFFERENT old baseline: 6 roads, 2 rests,
	# 2 events, 2 swamps. Preserve its count and route editor semantics
	# without rewriting the saved 24-tile map during migration.
	var result: Dictionary={"basic":-5,"rest":2,"event":1,"swamp":2}
	var baseline: Array=LEGACY_CURRENT if (plan.current+plan.reserve).has("graveyard") else CURRENT
	for tile in ["basic","graveyard","forest","rest","event","monster"]:
		result[tile]=int(result.get(tile,0))+plan.current.count(tile)-baseline.count(tile)
	return result
