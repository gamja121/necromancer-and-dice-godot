extends RefCounted
## Story contamination gates are checked ONLY on the first discovery.
## Previously seen/active stories and saved continuations must remain playable
## even when prayer lowers the contamination below their original threshold.
## Existing story prerequisites, tile guards, choices and completion rules
## remain owned by their original entry modules.
const MINIMUMS = {
	"graveyard_child_ambush_01":10,
	"rumor_saved_child_01":15,
	"rumor_abandoned_child_01":15,
	"knight_commander_contamination_01":20,
	"monster_hunter_encounter_01":30,
	"cultist_rumor_01":40,
	"cultist_altar_encounter_01":50,
	"ritual_portal_trace_01":75,
	"monster_king_hunt_trace_01":80
}

static func allows(session, event_id: String) -> bool:
	if session == null or session.world == null or not MINIMUMS.has(event_id): return false
	var state: Dictionary = session.get_story_event(event_id)
	if state.get("status","unseen") != "unseen": return true
	return int(session.world.contamination) >= int(MINIMUMS[event_id])
