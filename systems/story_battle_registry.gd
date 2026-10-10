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
		"outcomes":{
			"won":{
				"status":"complete",
				"notice":"구울 격퇴 · 아이 구조 성공",
				"flags":{
					"battle:graveyard_child_ambush_01:won":true,
					"battle:graveyard_child_ambush_01:lost":false,
					"event:graveyard_child_ambush_01:seen":true,
					"event:graveyard_child_ambush_01:complete":true,
					"event:graveyard_child_ambush_01:rescued":true,
					"event:graveyard_child_ambush_01:abandoned":false
				},
				"presentation":{
					"title":"아이 구조 성공",
					"narration":"구울이 쓰러지자 아이는 당신을 바라본다. 그러나 안도하기보다 겁에 질린 표정으로 뒷걸음치더니, 묘비 사이로 달아나 버린다.",
					"dialogue":"아이: ……!",
					"background":"res://assets/map/events/graveyard-child-base-v3.webp",
					"overlay":"",
					"retry":false
				}
			},
			"lost":{
				"status":"active",
				"notice":"구울 전투 패배 · 구조 미완료 · 생존 마물로 다시 도전할 수 있습니다.",
				"flags":{
					"battle:graveyard_child_ambush_01:won":false,
					"battle:graveyard_child_ambush_01:lost":true
				},
				"presentation":{
					"title":"아이 구조 실패",
					"narration":"구울을 막지 못했습니다. 아이를 구하지 못했으며, 아직 구조를 완료한 것은 아닙니다.",
					"dialogue":"남은 마물로 다시 도전할 수 있습니다.",
					"background":"res://assets/map/events/graveyard-child-base-v3.webp",
					"overlay":"res://assets/map/events/graveyard-child-ghoul-event-v3.webp",
					"retry":true
				}
			}
		}
	}
}

static func definition(event_id: String) -> Dictionary:
	if event_id.is_empty() or not DEFINITIONS.has(event_id): return {}
	return DEFINITIONS[event_id].duplicate(true)

static func registered_ids() -> Array:
	return DEFINITIONS.keys().duplicate()

static func valid_definition(spec: Dictionary) -> bool:
	if spec.is_empty(): return false
	for key in ["event_id","encounter_type","choice","complete_flag","pending_flag"]:
		if not spec.get(key) is String or str(spec[key]).is_empty(): return false
	if not str(spec.encounter_type).begins_with("event-"): return false
	if not spec.get("tiles") is Array or spec.tiles.is_empty(): return false
	if not spec.get("enemies") is Array or spec.enemies.is_empty(): return false
	for tile in spec.tiles:
		if not tile is String or tile.is_empty(): return false
	for slug in spec.enemies:
		if not slug is String or slug.is_empty(): return false
	if not spec.get("outcomes") is Dictionary: return false
	for result_id in ["won","lost"]:
		var outcome: Dictionary = spec.outcomes.get(result_id,{})
		if outcome.get("status","") not in ["active","complete"]: return false
		if not outcome.get("notice") is String: return false
		if not outcome.get("flags") is Dictionary: return false
		for flag in outcome.flags:
			if not flag is String or flag.is_empty() or not outcome.flags[flag] is bool: return false
		var view: Dictionary = outcome.get("presentation",{})
		for key in ["title","narration","dialogue","background","overlay"]:
			if not view.get(key) is String: return false
		if str(view.title).is_empty() or str(view.background).is_empty(): return false
		if not view.get("retry") is bool: return false
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
