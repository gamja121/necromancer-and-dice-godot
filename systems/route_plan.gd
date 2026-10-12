extends RefCounted
## A new expedition begins with a road instead of the locked graveyard.
const CURRENT = ["basic","basic","basic","forest","rest","event"]
## v1 patrol inventories with a graveyard are still valid on reload.
const LEGACY_CURRENT = ["basic","basic","graveyard","forest","rest","event"]
const RESERVE = ["monster","monster","monster","monster","monster"]

static func default_plan() -> Dictionary:
	return {"current":CURRENT.duplicate(),"reserve":RESERVE.duplicate()}

static func valid(plan) -> bool:
	if not plan is Dictionary or not plan.get("current") is Array or not plan.get("reserve") is Array: return false
	if plan.current.size()!=6 or plan.reserve.size()!=5: return false
	var inventory: Array = plan.current+plan.reserve
	var baseline: Array = LEGACY_CURRENT+RESERVE if inventory.has("graveyard") else CURRENT+RESERVE
	for type in baseline:
		if inventory.count(type)!=baseline.count(type): return false
	return inventory.all(func(type): return type in baseline)

static func deltas(plan: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var baseline: Array = LEGACY_CURRENT if (plan.current+plan.reserve).has("graveyard") else CURRENT
	for type in CURRENT+RESERVE+LEGACY_CURRENT:
		result[type] = plan.current.count(type)-baseline.count(type)
	return result
