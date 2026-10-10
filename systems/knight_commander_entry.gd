extends RefCounted
## P1-05C: first encounter with the knight commander on the rescue route.
## Later dialogue, recognition, quest activation and hunter meeting are NOT
## committed by discovering the commander.

const EVENT_ID = "knight_commander_contamination_01"
const SEEN_FLAG = "event:knight_commander_contamination_01:seen"
const COMPLETE_FLAG = "event:knight_commander_contamination_01:complete"
const RECOGNIZED_FLAG = "story:knight_commander:recognizes_player"
const QUEST_ACTIVE_FLAG = "quest:contamination_hunter_01:active"
const QUEST_COMPLETE_FLAG = "quest:contamination_hunter_01:complete"
const RESCUED_FLAG = "event:graveyard_child_ambush_01:rescued"
const ABANDONED_FLAG = "event:graveyard_child_ambush_01:abandoned"
const RUMOR_ID = "rumor_saved_child_01"
const RUMOR_SEEN_FLAG = "event:rumor_saved_child_01:seen"
const RUMOR_COMPLETE_FLAG = "event:rumor_saved_child_01:complete"
const ART = "res://assets/map/events/knight-commander-village-day.webp"
const PORTRAIT = "res://assets/map/events/knight-commander-upperbody-hd.webp"
const FIRST_BEAT = {"id":"arrival","effect":"길목에서 무장한 기사가 당신을 기다리고 있었다.","dialogue":"여기 있었구만.","speaker":"기사단장"}

static func can_enter(session, index: int) -> bool:
	if session == null or session.world == null: return false
	var w = session.world
	if index<0 or index>=w.tiles.size() or w.position!=index: return false
	if w.tiles[index] not in ["village","event"]: return false
	if not session.encounter.is_empty() or not w.active_encounter.is_empty(): return false
	if not w.pending_move.is_empty() or not w.pending_reward.is_empty(): return false
	# The first rescued-child rumor must be completely finished first.
	if session.get_story_event("graveyard_child_ambush_01").status!="complete": return false
	var grave: Dictionary=session.get_story_event("graveyard_child_ambush_01")
	if grave.choice!="protect_child" or grave.battle_result!="won": return false
	if w.event_flags.get("event:graveyard_child_ambush_01:complete",false)!=true: return false
	if w.event_flags.get("story:graveyard_child_ambush_01:result_pending",false)==true: return false
	if w.event_flags.get(RESCUED_FLAG,false)!=true or w.event_flags.get(ABANDONED_FLAG,false)==true: return false
	if session.get_story_event(RUMOR_ID).status!="complete": return false
	if w.event_flags.get(RUMOR_SEEN_FLAG,false)!=true or w.event_flags.get(RUMOR_COMPLETE_FLAG,false)!=true: return false
	# Never start the commander twice, or after the later quest is unlocked.
	if w.event_flags.get(COMPLETE_FLAG,false)==true: return false
	if w.event_flags.get(RECOGNIZED_FLAG,false)==true: return false
	if w.event_flags.get(QUEST_ACTIVE_FLAG,false)==true or w.event_flags.get(QUEST_COMPLETE_FLAG,false)==true: return false
	var state: Dictionary=session.get_story_event(EVENT_ID)
	if state.status not in ["unseen","seen"]: return false
	if state.choice!="" or state.battle_result!="": return false
	# A seen event must have its persisted seen marker; inconsistent saves are
	# not converted into a new event or silently rewritten.
	if state.status=="seen" and w.event_flags.get(SEEN_FLAG,false)!=true: return false
	if state.status=="unseen" and w.event_flags.get(SEEN_FLAG,false)==true: return false
	return true

static func begin(session, index: int) -> bool:
	if not can_enter(session,index): return false
	var w=session.world
	if session.get_story_event(EVENT_ID).status=="seen": return true
	var before: Dictionary=w.snapshot().duplicate(true)
	w.story_events[EVENT_ID]={"status":"seen","choice":"","battle_result":""}
	w.event_flags[SEEN_FLAG]=true
	return session.persist_change(before)
