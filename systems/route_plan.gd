extends RefCounted
const CURRENT = ["basic","basic","graveyard","forest","rest","event"]
const RESERVE = ["monster","monster","monster","monster","monster"]

static func default_plan() -> Dictionary:
	return {"current":CURRENT.duplicate(),"reserve":RESERVE.duplicate()}

static func valid(plan) -> bool:
	if not plan is Dictionary or not plan.get("current") is Array or not plan.get("reserve") is Array: return false
	if plan.current.size()!=6 or plan.reserve.size()!=5: return false
	var inventory: Array = plan.current+plan.reserve
	for type in CURRENT+RESERVE:
		if inventory.count(type)!=(CURRENT+RESERVE).count(type): return false
	return inventory.all(func(type): return type in CURRENT+RESERVE)

static func deltas(plan: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for type in CURRENT+RESERVE:
		result[type] = plan.current.count(type)-CURRENT.count(type)
	return result
