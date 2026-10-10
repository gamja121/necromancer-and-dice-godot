extends RefCounted
const RumorBeats = preload("res://systems/village_rumor_beats.gd")
## P1-05B: village rumor entry plus persisted beat-by-beat progression.
## Commander/hunter follow-up is a separate step.

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

## Store progress as boolean event flags for backwards-compatible world snapshots.
## :beat:1 means the second scene is visible; the first scene is implicit.
static func progress_flag(event_id: String, beat_index: int) -> String:
	if event_id not in [RESCUED_ID,ABANDONED_ID]: return ""
	if beat_index<1 or beat_index>=RumorBeats.count(event_id): return ""
	return "event:%s:beat:%d" % [event_id,beat_index]

static func current_beat(session, event_id: String) -> int:
	if session == null or session.world == null: return -1
	if event_id not in [RESCUED_ID,ABANDONED_ID]: return -1
	if session.get_story_event(event_id).status!="seen": return -1
	if session.world.event_flags.get(seen_flag(event_id),false)!=true: return -1
	if session.world.event_flags.get(complete_flag(event_id),false)==true: return -1
	var position: int=0
	var found_gap: bool=false
	for i in range(1,RumorBeats.count(event_id)):
		var present: bool=session.world.event_flags.get(progress_flag(event_id,i),false)==true
		if present and found_gap: return -1
		if present: position=i
		else: found_gap=true
	return position

## Explicit '계속' saves only the next beat. Only pressing '마치기' on
## the last beat commits the whole scene and its web-compatible completion.
static func advance(session, index: int, event_id: String, visible_index: int) -> bool:
	if eligible_event_id(session,index)!=event_id: return false
	var current: int=current_beat(session,event_id)
	if current<0 or visible_index!=current: return false
	var final_beat: bool=RumorBeats.is_final(event_id,current)
	var before: Dictionary=session.world.snapshot().duplicate(true)
	if final_beat:
		session.world.story_events[event_id]={"status":"complete","choice":"","battle_result":""}
		session.world.event_flags[seen_flag(event_id)]=true
		session.world.event_flags[complete_flag(event_id)]=true
	else:
		session.world.event_flags[progress_flag(event_id,current+1)]=true
	return session.persist_change(before)
