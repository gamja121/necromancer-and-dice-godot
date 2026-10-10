extends RefCounted
## P1-04A: explicit, fail-closed story battle contracts.
## Registering a definition does NOT launch an event; its story scene must first
## commit its own active stage and choice, then call start_story_encounter().
## Only the fully implemented graveyard event is enabled here.

const GRAVEYARD_ID = "graveyard_child_ambush_01"
const DEFINITIONS = {
	GRAVEYARD_ID: {
		"event_id":GRAVEYARD_ID,
		"encounter_type":"event-graveyard-child",
		"tiles":["graveyard","event"],
		"choice":"protect_child",
		"enemies":["ghoul"],
		"complete_flag":"event:graveyard_child_ambush_01:complete",
		"pending_flag":"story:graveyard_child_ambush_01:result_pending",
		"result_handler":"graveyard_child"
	}
}

static func definition(event_id: String) -> Dictionary:
	if event_id.is_empty() or not DEFINITIONS.has(event_id): return {}
	return DEFINITIONS[event_id].duplicate(true)

static func valid_definition(spec: Dictionary) -> bool:
	if spec.is_empty(): return false
	for key in ["event_id","encounter_type","choice","complete_flag","pending_flag","result_handler"]:
		if not spec.get(key) is String or str(spec[key]).is_empty(): return false
	if not str(spec.encounter_type).begins_with("event-"): return false
	if not spec.get("tiles") is Array or spec.tiles.is_empty(): return false
	if not spec.get("enemies") is Array or spec.enemies.is_empty(): return false
	for tile in spec.tiles:
		if not tile is String or tile.is_empty(): return false
	for slug in spec.enemies:
		if not slug is String or slug.is_empty(): return false
	return true

static func can_start(world, event: Dictionary, index: int, spec: Dictionary) -> bool:
	if world == null or not valid_definition(spec): return false
	if index < 0 or index >= world.tiles.size() or index != world.position: return false
	if not world.tiles[index] in spec.tiles: return false
	if event.get("status","") != "active" or event.get("choice","") != spec.choice: return false
	if event.get("battle_result","") not in ["","lost"]: return false
	if world.event_flags.get(spec.complete_flag,false) == true: return false
	for slug in spec.enemies:
		if not world.definitions.has(slug): return false
	return true
