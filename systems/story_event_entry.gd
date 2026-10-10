extends RefCounted
## P1-03A: discover the graveyard child on the first eligible landing.
## Actual choices, battle entry and event completion belong to later steps.

const EVENT_ID = "graveyard_child_ambush_01"
const SEEN_FLAG = "event:graveyard_child_ambush_01:seen"
const COMPLETE_FLAG = "event:graveyard_child_ambush_01:complete"

static func can_enter(session, index: int) -> bool:
	if session == null or session.world == null: return false
	var world = session.world
	# A map tile preview must never advance the hero's story.
	if index < 0 or index >= world.tiles.size() or index != world.position: return false
	if not world.tiles[index] in ["graveyard","event"]: return false
	if not session.encounter.is_empty() or not world.active_encounter.is_empty(): return false
	if not world.pending_move.is_empty() or not world.pending_reward.is_empty(): return false
	if world.roster.is_empty(): return false
	# Seen is a journal marker, not a consumed event. Completion is final.
	if world.event_flags.get(COMPLETE_FLAG,false) == true: return false
	return session.get_story_event(EVENT_ID).status != "complete"

## Commits the selected action without claiming a battle victory.
## "protect_child" only reserves the rescue route; winning the ghoul fight is
## required before the rescued flag may ever become true.
static func choose(session, index: int, choice_id: String) -> bool:
	if choice_id not in ["protect_child","leave"]: return false
	if not can_enter(session,index): return false
	var world = session.world
	var current: Dictionary = session.get_story_event(EVENT_ID)
	if current.status not in ["seen","active"]: return false
	if not current.choice.is_empty(): return current.status == "active" and current.choice == choice_id
	var before: Dictionary = world.snapshot().duplicate(true)
	if choice_id == "protect_child":
		world.story_events[EVENT_ID] = {"status":"active","choice":choice_id,"battle_result":""}
	else:
		world.story_events[EVENT_ID] = {"status":"complete","choice":choice_id,"battle_result":""}
		world.event_flags[COMPLETE_FLAG] = true
		world.event_flags["event:graveyard_child_ambush_01:abandoned"] = true
		world.event_flags["event:graveyard_child_ambush_01:rescued"] = false
	return session.persist_change(before)

static func begin(session, index: int) -> bool:
	if not can_enter(session,index): return false
	var world = session.world
	var current: Dictionary = session.get_story_event(EVENT_ID)
	if current.status != "unseen" and world.event_flags.get(SEEN_FLAG,false) == true:
		return true
	var before: Dictionary = world.snapshot().duplicate(true)
	if current.status == "unseen":
		world.story_events[EVENT_ID] = {"status":"seen","choice":"","battle_result":""}
	world.event_flags[SEEN_FLAG] = true
	# State and web-compatible flag either both persist, or neither persists.
	return session.persist_change(before)
