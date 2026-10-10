extends RefCounted
## P1-05A: first landing and durable discovery of the two village rumors.
## Dialogue progression, scene completion and the commander follow-up are
## intentionally not part of this step.

const RESCUED_ID = "rumor_saved_child_01"
const ABANDONED_ID = "rumor_abandoned_child_01"
const GRAVEYARD_ID = "graveyard_child_ambush_01"
const RESCUED_FLAG = "event:graveyard_child_ambush_01:rescued"
const ABANDONED_FLAG = "event:graveyard_child_ambush_01:abandoned"
const SCENE_ART = "res://assets/map/events/rumor-village-base.webp"
const INTRO = {
	RESCUED_ID:"마을에 들어서자 곳곳에서 낮은 목소리의 수군거림이 들린다.",
	ABANDONED_ID:"마을 어귀에 들어서자, 어두운 이야기들이 낮게 흘러다닌다."
}

static func seen_flag(event_id: String) -> String:
	return "event:%s:seen" % event_id if event_id in [RESCUED_ID,ABANDONED_ID] else ""

static func complete_flag(event_id: String) -> String:
	return "event:%s:complete" % event_id if event_id in [RESCUED_ID,ABANDONED_ID] else ""

static func eligible_event_id(session, index: int) -> String:
	if session == null or session.world == null: return ""
	var world = session.world
	# Tiles visible elsewhere on the map must never trigger or save a rumor.
	if index<0 or index>=world.tiles.size() or index!=world.position: return ""
	if not world.tiles[index] in ["village","event"]: return ""
	if not session.encounter.is_empty() or not world.active_encounter.is_empty(): return ""
	if not world.pending_move.is_empty() or not world.pending_reward.is_empty(): return ""
	# The child result must have been presented and explicitly acknowledged
	# before a follow-up rumor is eligible.
	if world.event_flags.get("story:graveyard_child_ambush_01:result_pending",false)==true: return ""
	var graveyard: Dictionary = session.get_story_event(GRAVEYARD_ID)
	if graveyard.status!="complete": return ""
	if world.event_flags.get("event:graveyard_child_ambush_01:complete",false)!=true: return ""
	var rescued: bool = world.event_flags.get(RESCUED_FLAG,false)==true
	var abandoned: bool = world.event_flags.get(ABANDONED_FLAG,false)==true
	if rescued==abandoned: return ""
	if rescued and (graveyard.choice!="protect_child" or graveyard.battle_result!="won"): return ""
	if abandoned and graveyard.choice!="leave": return ""
	var event_id: String = RESCUED_ID if rescued else ABANDONED_ID
	if world.event_flags.get(complete_flag(event_id),false)==true: return ""
	if session.get_story_event(event_id).status=="complete": return ""
	return event_id

static func begin(session, index: int) -> String:
	var event_id: String = eligible_event_id(session,index)
	if event_id.is_empty(): return ""
	var world = session.world
	var current: Dictionary = session.get_story_event(event_id)
	if current.status!="unseen" and world.event_flags.get(seen_flag(event_id),false)==true:
		return event_id
	if current.status not in ["unseen","seen"]: return ""
	var before: Dictionary = world.snapshot().duplicate(true)
	if current.status=="unseen":
		world.story_events[event_id]={"status":"seen","choice":"","battle_result":""}
	world.event_flags[seen_flag(event_id)]=true
	return event_id if session.persist_change(before) else ""
