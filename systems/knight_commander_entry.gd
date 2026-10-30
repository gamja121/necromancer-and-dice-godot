extends RefCounted
const ContaminationGate = preload("res://systems/story_contamination_gate.gd")
const CommanderBeats = preload("res://systems/knight_commander_beats.gd")
## P1-05D: complete source dialogue, saved beat progression and atomic quest acceptance.
## Monster-hunter meeting remains a separate event.

const EVENT_ID = "knight_commander_contamination_01"
const SEEN_FLAG = "event:knight_commander_contamination_01:seen"
const COMPLETE_FLAG = "event:knight_commander_contamination_01:complete"
const RECOGNIZED_FLAG = "story:knight_commander:recognizes_player"
const QUEST_ACTIVE_FLAG = "quest:contamination_hunter_01:active"
const QUEST_COMPLETE_FLAG = "quest:contamination_hunter_01:complete"
const PROPHET_QUEST_ACTIVE_FLAG = "quest:prophet_cultist_01:active"
const PROPHET_QUEST_COMPLETE_FLAG = "quest:prophet_cultist_01:complete"
const RESCUED_FLAG = "event:graveyard_child_ambush_01:rescued"
const ABANDONED_FLAG = "event:graveyard_child_ambush_01:abandoned"
const RUMOR_ID = "rumor_saved_child_01"
const RUMOR_SEEN_FLAG = "event:rumor_saved_child_01:seen"
const RUMOR_COMPLETE_FLAG = "event:rumor_saved_child_01:complete"
const ABANDONED_RUMOR_ID = "rumor_abandoned_child_01"
const ABANDONED_RUMOR_SEEN_FLAG = "event:rumor_abandoned_child_01:seen"
const ABANDONED_RUMOR_COMPLETE_FLAG = "event:rumor_abandoned_child_01:complete"
const ART = "res://assets/map/events/manuscript_commander_base.png"
const PORTRAIT = "res://assets/map/events/manuscript_commander_actor.png"
const FIRST_BEAT = {"id":"arrival","effect":"길목에서 무장한 기사가 당신을 기다리고 있었다.","dialogue":"여기 있었구만.","speaker":"기사단장"}

## The actual child outcome and completed matching rumor select the referral.
## Keep this readable after the commander event finishes.
static func route(session) -> String:
	if session == null or session.world == null: return ""
	var w=session.world
	var grave: Dictionary=session.get_story_event("graveyard_child_ambush_01")
	if grave.status!="complete": return ""
	if w.event_flags.get("event:graveyard_child_ambush_01:complete",false)!=true: return ""
	if w.event_flags.get("story:graveyard_child_ambush_01:result_pending",false)==true: return ""
	var rescued: bool=w.event_flags.get(RESCUED_FLAG,false)==true
	var abandoned: bool=w.event_flags.get(ABANDONED_FLAG,false)==true
	if rescued==abandoned: return ""
	if rescued:
		if grave.choice!="protect_child" or grave.battle_result!="won": return ""
		if session.get_story_event(RUMOR_ID).status!="complete": return ""
		if w.event_flags.get(RUMOR_SEEN_FLAG,false)!=true or w.event_flags.get(RUMOR_COMPLETE_FLAG,false)!=true: return ""
		return "hunter"
	if grave.choice!="leave" or grave.battle_result!="": return ""
	var rumor: Dictionary=session.get_story_event(ABANDONED_RUMOR_ID)
	if rumor.status!="complete" or rumor.choice!="" or rumor.battle_result!="": return ""
	if w.event_flags.get(ABANDONED_RUMOR_SEEN_FLAG,false)!=true or w.event_flags.get(ABANDONED_RUMOR_COMPLETE_FLAG,false)!=true: return ""
	return "prophet"

static func can_enter(session, index: int) -> bool:
	if session == null or session.world == null: return false
	var w = session.world
	if not ContaminationGate.allows(session,EVENT_ID): return false
	if index<0 or index>=w.tiles.size() or w.position!=index: return false
	if w.tiles[index] not in ["village","event"]: return false
	if not session.encounter.is_empty() or not w.active_encounter.is_empty(): return false
	if not w.pending_move.is_empty() or not w.pending_reward.is_empty(): return false
	if not w.run_result.is_empty() or route(session).is_empty(): return false
	# Never start the commander twice, or after the later quest is unlocked.
	if w.event_flags.get(COMPLETE_FLAG,false)==true: return false
	if w.event_flags.get(RECOGNIZED_FLAG,false)==true: return false
	if w.event_flags.get(QUEST_ACTIVE_FLAG,false)==true or w.event_flags.get(QUEST_COMPLETE_FLAG,false)==true: return false
	if w.event_flags.get(PROPHET_QUEST_ACTIVE_FLAG,false)==true or w.event_flags.get(PROPHET_QUEST_COMPLETE_FLAG,false)==true: return false
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
static func progress_flag(beat_index: int, selected_route: String = "hunter") -> String:
	if beat_index<1 or beat_index>=CommanderBeats.count(selected_route): return ""
	return "event:%s:beat:%d" % [EVENT_ID,beat_index]

static func current_beat(session) -> int:
	if session == null or session.world == null: return -1
	var selected_route: String=route(session)
	if selected_route.is_empty(): return -1
	var state: Dictionary=session.get_story_event(EVENT_ID)
	if state.status!="seen" or state.choice!="" or state.battle_result!="": return -1
	if session.world.event_flags.get(SEEN_FLAG,false)!=true: return -1
	if session.world.event_flags.get(COMPLETE_FLAG,false)==true: return -1
	if session.world.event_flags.get(RECOGNIZED_FLAG,false)==true: return -1
	if session.world.event_flags.get(QUEST_ACTIVE_FLAG,false)==true: return -1
	if session.world.event_flags.get(QUEST_COMPLETE_FLAG,false)==true: return -1
	if session.world.event_flags.get(PROPHET_QUEST_ACTIVE_FLAG,false)==true or session.world.event_flags.get(PROPHET_QUEST_COMPLETE_FLAG,false)==true: return -1
	var position: int=0
	var gap: bool=false
	for index in range(1,CommanderBeats.count(selected_route)):
		var found: bool=session.world.event_flags.get(progress_flag(index,selected_route),false)==true
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
	var selected_route: String=route(session)
	var before: Dictionary=session.world.snapshot().duplicate(true)
	if CommanderBeats.is_final(current,selected_route):
		session.world.story_events[EVENT_ID]={"status":"complete","choice":"","battle_result":""}
		session.world.event_flags[SEEN_FLAG]=true
		session.world.event_flags[COMPLETE_FLAG]=true
		if selected_route=="prophet":
			session.world.event_flags[PROPHET_QUEST_ACTIVE_FLAG]=true
			session.world.event_flags[PROPHET_QUEST_COMPLETE_FLAG]=false
		else:
			session.world.event_flags[RECOGNIZED_FLAG]=true
			session.world.event_flags[QUEST_ACTIVE_FLAG]=true
			session.world.event_flags[QUEST_COMPLETE_FLAG]=false
	else:
		session.world.event_flags[progress_flag(current+1,selected_route)]=true
	return session.persist_change(before)
