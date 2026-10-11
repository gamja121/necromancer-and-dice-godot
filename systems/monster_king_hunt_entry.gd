extends RefCounted
## P1-05K-4: fourth-scene destination clue after saved revival dialogue.
## Weakened/full revival never mix; location receipt and final battle stay locked.
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
const BASE_ART = HuntBeats.BASE_ART
const FIRST_BEAT = HuntBeats.FIRST_BEAT

static func can_enter(session, index: int) -> bool:
	if session == null or session.world == null: return false
	var w=session.world
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
	if not can_enter(session,session.world.position): return ""
	return "weakened" if session.world.event_flags.get(WEAKENED_FLAG,false)==true else "full"

static func current_beat(session) -> int:
	if session == null or session.world == null: return -1
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
