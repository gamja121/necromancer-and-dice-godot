extends RefCounted
const ContaminationGate = preload("res://systems/story_contamination_gate.gd")
const KingPortalTile = preload("res://systems/king_portal_tile.gd")
## P1-05K-5: fifth source scene and atomic king-hunt completion.
## The actual king boss encounter remains a separate implementation.
const Portal = preload("res://systems/ritual_portal_entry.gd")
const HuntBeats = preload("res://systems/monster_king_hunt_beats.gd")

const EVENT_ID = "monster_king_hunt_trace_01"
const SEEN_FLAG = "event:monster_king_hunt_trace_01:seen"
const COMPLETE_FLAG = "event:monster_king_hunt_trace_01:complete"
const HUNT_ACTIVE_FLAG = "quest:monster_king_hunt:active"
const HUNT_COMPLETE_FLAG = "quest:monster_king_hunt:complete"
const REVIVED_FLAG = "story:monster_king:revived"
const WEAKENED_FLAG = "story:monster_king:revival_weakened"
const FULL_REVIVAL_FLAG = "story:monster_king:revival_complete"
const SEALED_RUINS_FLAG = "story:monster_king:sealed_ruins_location_known"
const FINAL_BATTLE_FLAG = "quest:monster_king_final_battle:active"
const FINAL_SCENE_ACK_FLAG = "event:monster_king_hunt_trace_01:final_acknowledged"
const BASE_ART = HuntBeats.BASE_ART
const FIRST_BEAT = HuntBeats.FIRST_BEAT

static func can_enter(session, index: int) -> bool:
	if session == null or session.world == null: return false
	var w=session.world
	if not ContaminationGate.allows(session,EVENT_ID): return false
	if index<0 or index>=w.tiles.size() or index!=w.position: return false
	if w.tiles[index] not in ["unknown","event"]: return false
	if not session.encounter.is_empty() or not w.active_encounter.is_empty(): return false
	if not w.pending_move.is_empty() or not w.pending_reward.is_empty(): return false
	# A lone hunt-quest flag cannot bypass the canonical ritual encounter.
	if not Portal.completed(session): return false
	if w.event_flags.get(REVIVED_FLAG,false)!=true: return false
	if w.event_flags.get(HUNT_ACTIVE_FLAG,false)!=true: return false
	if w.event_flags.get(HUNT_COMPLETE_FLAG,false)==true: return false
	if w.event_flags.get(COMPLETE_FLAG,false)==true: return false
	if w.event_flags.get(SEALED_RUINS_FLAG,false)==true: return false
	if w.event_flags.get(FINAL_BATTLE_FLAG,false)==true: return false
	var weakened: bool=w.event_flags.get(WEAKENED_FLAG,false)==true
	var full: bool=w.event_flags.get(FULL_REVIVAL_FLAG,false)==true
	if weakened==full: return false
	var state: Dictionary=session.get_story_event(EVENT_ID)
	if state.status not in ["unseen","seen"]: return false
	if state.choice!="" or state.battle_result!="": return false
	if (state.status=="seen")!=(w.event_flags.get(SEEN_FLAG,false)==true): return false
	if w.event_flags.get(progress_flag(1),false)==true and state.status!="seen": return false
	if w.event_flags.get(progress_flag(2),false)==true and w.event_flags.get(progress_flag(1),false)!=true: return false
	if w.event_flags.get(progress_flag(3),false)==true and w.event_flags.get(progress_flag(2),false)!=true: return false
	return true

## Only record first discovery in a single world transaction. A replay of
## a previously saved first scene must never rewrite or advance the quest.
static func begin(session, index: int) -> bool:
	if not can_enter(session,index): return false
	if session.get_story_event(EVENT_ID).status=="seen": return true
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[EVENT_ID]={"status":"seen","choice":"","battle_result":""}
	session.world.event_flags[SEEN_FLAG]=true
	return session.persist_change(before)

static func progress_flag(index: int) -> String:
	if index not in [1,2,3]: return ""
	return "event:%s:beat:%d" % [EVENT_ID,index]

static func revival_mode(session) -> String:
	if session == null or session.world == null: return ""
	if not can_enter(session,session.world.position) and not completed(session): return ""
	return "weakened" if session.world.event_flags.get(WEAKENED_FLAG,false)==true else "full"

static func current_beat(session) -> int:
	if session == null or session.world == null: return -1
	if can_resume_completion(session,session.world.position): return 4
	if not can_enter(session,session.world.position): return -1
	if session.get_story_event(EVENT_ID).status!="seen": return -1
	if session.world.event_flags.get(progress_flag(3),false)==true: return 3
	if session.world.event_flags.get(progress_flag(2),false)==true: return 2
	return 1 if session.world.event_flags.get(progress_flag(1),false)==true else 0

## Each explicit Continue saves exactly one source beat. Invalid revival
## state, stale click, wrong tile or failed storage never creates dialogue.
static func advance(session, index: int, shown_index: int) -> bool:
	if not can_enter(session,index): return false
	if session.get_story_event(EVENT_ID).status!="seen": return false
	if shown_index not in [0,1,2] or current_beat(session)!=shown_index: return false
	if revival_mode(session) not in ["weakened","full"]: return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.event_flags[progress_flag(shown_index+1)]=true
	return session.persist_change(before)

## Commit all story/quest/final-battle-availability flags in ONE save.
## The fourth source beat only points toward the ruins; pressing Continue
## there is the sole valid transition into the fifth 'located' beat.
static func finish(session, index: int) -> bool:
	if not can_enter(session,index): return false
	if session.get_story_event(EVENT_ID).status!="seen" or current_beat(session)!=3: return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[EVENT_ID]={"status":"complete","choice":"","battle_result":""}
	var flags: Dictionary=session.world.event_flags
	flags[COMPLETE_FLAG]=true
	flags[HUNT_ACTIVE_FLAG]=false
	flags[HUNT_COMPLETE_FLAG]=true
	flags[SEALED_RUINS_FLAG]=true
	flags[FINAL_BATTLE_FLAG]=true
	return session.persist_change(before)

## Read-only proof that a completed hunt matches the real portal outcome.
static func completed(session) -> bool:
	if session == null or session.world == null or not Portal.completed(session): return false
	var state: Dictionary=session.get_story_event(EVENT_ID)
	if state.status!="complete" or state.choice!="" or state.battle_result!="": return false
	var flags: Dictionary=session.world.event_flags
	for key in [SEEN_FLAG,COMPLETE_FLAG,HUNT_COMPLETE_FLAG,SEALED_RUINS_FLAG,FINAL_BATTLE_FLAG,REVIVED_FLAG]:
		if flags.get(key,false)!=true: return false
	if flags.get(HUNT_ACTIVE_FLAG,false)!=false: return false
	for i in [1,2,3]:
		if flags.get(progress_flag(i),false)!=true: return false
	var weakened: bool=flags.get(WEAKENED_FLAG,false)==true
	var full: bool=flags.get(FULL_REVIVAL_FLAG,false)==true
	return weakened!=full

## An unacknowledged final screen can be restored, but never starts a
## new event or battle just because a game save was loaded.
static func can_resume_completion(session, index: int) -> bool:
	if not completed(session): return false
	var w=session.world
	if index<0 or index>=w.tiles.size() or index!=w.position: return false
	if w.tiles[index] not in ["unknown","event"]: return false
	if not session.encounter.is_empty() or not w.active_encounter.is_empty(): return false
	if not w.pending_move.is_empty() or not w.pending_reward.is_empty(): return false
	return w.event_flags.get(FINAL_SCENE_ACK_FLAG,false)!=true

## Save the deliberate '마치기' acknowledgment, preserving navigation.
static func acknowledge_completion(session, index: int) -> bool:
	if not completed(session): return false
	var w=session.world
	if index<0 or index>=w.tiles.size() or index!=w.position: return false
	if w.tiles[index] not in ["unknown","event"]: return false
	if not session.encounter.is_empty() or not w.active_encounter.is_empty(): return false
	if not w.pending_move.is_empty() or not w.pending_reward.is_empty(): return false
	if w.event_flags.get(FINAL_SCENE_ACK_FLAG,false)==true: return true
	var before: Dictionary=w.snapshot().duplicate(true)
	w.event_flags[FINAL_SCENE_ACK_FLAG]=true
	# Both weakened and complete revival lead to the SAME final location.
	# If blocking succeeded, this is when the dormant warp wakes; if the
	# ritual was allowed, reuse its already-painted warp unchanged.
	if not KingPortalTile.activate(w):
		w.restore(before)
		return false
	return session.persist_change(before)
