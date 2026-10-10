extends RefCounted
const CommanderBeats = preload("res://systems/knight_commander_beats.gd")
## P1-05D: complete source dialogue, saved beat progression and atomic quest acceptance.
## Monster-hunter meeting remains a separate event.

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

## Beat progress uses existing world.event_flags so old map_run_v1 saves
## remain compatible. Beat 0 is implicit after the first discovery.
static func progress_flag(beat_index: int) -> String:
	if beat_index<1 or beat_index>=CommanderBeats.count(): return ""
	return "event:%s:beat:%d" % [EVENT_ID,beat_index]

static func current_beat(session) -> int:
	if session == null or session.world == null: return -1
	var state: Dictionary=session.get_story_event(EVENT_ID)
	if state.status!="seen" or state.choice!="" or state.battle_result!="": return -1
	if session.world.event_flags.get(SEEN_FLAG,false)!=true: return -1
	if session.world.event_flags.get(COMPLETE_FLAG,false)==true: return -1
	if session.world.event_flags.get(RECOGNIZED_FLAG,false)==true: return -1
	if session.world.event_flags.get(QUEST_ACTIVE_FLAG,false)==true: return -1
	var position: int=0
	var gap: bool=false
	for index in range(1,CommanderBeats.count()):
		var found: bool=session.world.event_flags.get(progress_flag(index),false)==true
		if found and gap: return -1
		if found: position=index
		else: gap=true
	return position

## Only a fresh button click at the displayed beat may advance.
## Final '마치기' saves recognition, event completion and hunter quest in
## a SINGLE persist_change transaction. On failure every field rolls back.
static func advance(session, index: int, shown_index: int) -> bool:
	if not can_enter(session,index): return false
	var current: int=current_beat(session)
	if current<0 or current!=shown_index: return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	if CommanderBeats.is_final(current):
		session.world.story_events[EVENT_ID]={"status":"complete","choice":"","battle_result":""}
		session.world.event_flags[SEEN_FLAG]=true
		session.world.event_flags[COMPLETE_FLAG]=true
		session.world.event_flags[RECOGNIZED_FLAG]=true
		session.world.event_flags[QUEST_ACTIVE_FLAG]=true
		# This quest will be completed by the separate hunter encounter.
		session.world.event_flags[QUEST_COMPLETE_FLAG]=false
	else:
		session.world.event_flags[progress_flag(current+1)]=true
	return session.persist_change(before)
