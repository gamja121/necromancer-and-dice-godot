extends RefCounted
## P1-04B: data-driven outcome persistence and return presentation.
## Never starts an event; an encounter must be created through the deck picker.
const Registry = preload("res://systems/story_battle_registry.gd")

static func apply(world, event_id: String, spec: Dictionary, won: bool) -> String:
	if world == null or not Registry.valid_definition(spec): return ""
	if str(spec.event_id) != event_id: return ""
	var state: Dictionary = world.story_events.get(event_id,{})
	if state.get("status","") != "active" or state.get("choice","") != spec.choice: return ""
	var result: String = "won" if won else "lost"
	var outcome: Dictionary = spec.outcomes.get(result,{})
	if outcome.is_empty(): return ""
	world.story_events[event_id] = {"status":str(outcome.status),"choice":str(spec.choice),"battle_result":result}
	world.event_flags[spec.pending_flag] = true
	for flag in outcome.flags: world.event_flags[flag] = outcome.flags[flag]
	return str(outcome.notice)

static func valid_result(world, event_id: String, spec: Dictionary) -> bool:
	if world == null or not Registry.valid_definition(spec): return false
	if str(spec.event_id) != event_id: return false
	if world.event_flags.get(spec.pending_flag,false) != true: return false
	var event: Dictionary = world.story_events.get(event_id,{})
	if event.get("choice","") != spec.choice: return false
	var result: String = str(event.get("battle_result",""))
	if result not in ["won","lost"]: return false
	var outcome: Dictionary = spec.outcomes.get(result,{})
	if event.get("status","") != outcome.get("status",""): return false
	for flag in outcome.flags:
		if world.event_flags.get(flag,null) != outcome.flags[flag]: return false
	if result=="lost" and world.event_flags.get(spec.complete_flag,false)==true: return false
	return true

static func presentation(spec: Dictionary, event: Dictionary) -> Dictionary:
	if not Registry.valid_definition(spec): return {}
	var result: String = str(event.get("battle_result",""))
	if result not in ["won","lost"]: return {}
	if event.get("status","") != spec.outcomes[result].status or event.get("choice","") != spec.choice: return {}
	return spec.outcomes[result].presentation.duplicate(true)
