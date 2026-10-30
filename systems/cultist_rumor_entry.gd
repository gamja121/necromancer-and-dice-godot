extends RefCounted
const ContaminationGate = preload("res://systems/story_contamination_gate.gd")
const CultistRumorBeats = preload("res://systems/cultist_rumor_beats.gd")
const ProphetEntry = preload("res://systems/prophet_story_entry.gd")
const CommanderEntry = preload("res://systems/knight_commander_entry.gd")
## P1-05H: complete six-scene village cultist rumor and tracking quest.
## The later cultist altar encounter and its battle remain inactive.

const EVENT_ID = "cultist_rumor_01"
const SEEN_FLAG = "event:cultist_rumor_01:seen"
const COMPLETE_FLAG = "event:cultist_rumor_01:complete"
const HUNTER_ID = "monster_hunter_encounter_01"
const HUNTER_COMPLETE_FLAG = "event:monster_hunter_encounter_01:complete"
const HUNTER_QUEST_ACTIVE_FLAG = "quest:contamination_hunter_01:active"
const HUNTER_QUEST_COMPLETE_FLAG = "quest:contamination_hunter_01:complete"
const HUMAN_CLUE_FLAG = "story:cultist:human_involvement_clue"
const TRACKING_FLAG = "quest:cultist_tracking_01:active"
const KING_RUMOR_FLAG = "story:monster_king:revival_rumor"
const BASE_ART = "res://assets/map/events/manuscript_cultist_rumor_base.png"
const PROCESSION_ART = "res://assets/map/events/manuscript_cultist_procession.png"
const FIRST_BEAT = {
	"id":"arrival",
	"effect":"밤이 깊은 마을. 평소보다 일찍 문을 닫은 집들 사이로 인기척이 드물다.",
	"dialogue":"",
	"speaker":"",
	"visual":"base"
}

static func route(session) -> String:
	if session == null or session.world == null: return ""
	var w=session.world
	if w.event_flags.get(HUMAN_CLUE_FLAG,false)!=true: return ""
	if ProphetEntry.completed(session): return "prophet"
	var prophet: Dictionary=session.get_story_event(ProphetEntry.EVENT_ID)
	if prophet.status!="unseen" or prophet.choice!="" or prophet.battle_result!="": return ""
	for flag in [ProphetEntry.SEEN_FLAG,ProphetEntry.COMPLETE_FLAG,ProphetEntry.QUEST_ACTIVE_FLAG,ProphetEntry.QUEST_COMPLETE_FLAG]:
		if w.event_flags.get(flag,false)==true: return ""
	for flag in w.event_flags:
		if str(flag).begins_with("event:%s:beat:" % ProphetEntry.EVENT_ID) and w.event_flags[flag]==true: return ""
	if CommanderEntry.route(session)=="prophet": return ""
	if session.get_story_event(HUNTER_ID).status!="complete": return ""
	if w.event_flags.get(HUNTER_COMPLETE_FLAG,false)!=true: return ""
	if w.event_flags.get(HUNTER_QUEST_ACTIVE_FLAG,false)==true: return ""
	if w.event_flags.get(HUNTER_QUEST_COMPLETE_FLAG,false)!=true: return ""
	return "hunter"

static func can_enter(session, index: int) -> bool:
	if session == null or session.world == null: return false
	var w = session.world
	if not ContaminationGate.allows(session,EVENT_ID): return false
	if index<0 or index>=w.tiles.size() or index!=w.position: return false
	if w.tiles[index] not in ["village","event"]: return false
	if not session.encounter.is_empty() or not w.active_encounter.is_empty(): return false
	if not w.pending_move.is_empty() or not w.pending_reward.is_empty(): return false
	# An isolated clue is not enough; its actual source and quest must finish.
	if route(session).is_empty(): return false
	# Do not repeat an already completed branch or regress a later quest.
	if w.event_flags.get(COMPLETE_FLAG,false)==true: return false
	if w.event_flags.get(TRACKING_FLAG,false)==true: return false
	if w.event_flags.get(KING_RUMOR_FLAG,false)==true: return false
	var event: Dictionary=session.get_story_event(EVENT_ID)
	if event.status not in ["unseen","seen"]: return false
	if event.choice!="" or event.battle_result!="": return false
	# A stray seen flag or a lost receipt must never be silently repaired.
	if (event.status=="seen") != (w.event_flags.get(SEEN_FLAG,false)==true): return false
	return true

static func begin(session, index: int) -> bool:
	if not can_enter(session,index): return false
	if session.get_story_event(EVENT_ID).status=="seen": return true
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[EVENT_ID]={"status":"seen","choice":"","battle_result":""}
	session.world.event_flags[SEEN_FLAG]=true
	return session.persist_change(before)

## Existing save schema: sequential boolean markers; the arrival is implicit.
static func progress_flag(index: int) -> String:
	if index<1 or index>=CultistRumorBeats.count(): return ""
	return "event:%s:beat:%d" % [EVENT_ID,index]

static func current_beat(session) -> int:
	if session == null or session.world == null: return -1
	if route(session).is_empty(): return -1
	var w=session.world
	var event: Dictionary=session.get_story_event(EVENT_ID)
	if event.status!="seen" or event.choice!="" or event.battle_result!="": return -1
	if w.event_flags.get(SEEN_FLAG,false)!=true: return -1
	if w.event_flags.get(COMPLETE_FLAG,false)==true: return -1
	if w.event_flags.get(TRACKING_FLAG,false)==true: return -1
	if w.event_flags.get(KING_RUMOR_FLAG,false)==true: return -1
	var result: int=0
	var gap: bool=false
	for index in range(1,CultistRumorBeats.count()):
		var found: bool=w.event_flags.get(progress_flag(index),false)==true
		if found and gap: return -1
		if found: result=index
		else: gap=true
	return result

## One click == one saved beat. The final explicit '마치기' atomically
## completes the rumor and unlocks cultist tracking, but not the altar.
static func advance(session, index: int, shown_index: int) -> bool:
	if not can_enter(session,index): return false
	var current: int=current_beat(session)
	if current<0 or current!=shown_index: return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	if CultistRumorBeats.is_final(current):
		session.world.story_events[EVENT_ID]={"status":"complete","choice":"","battle_result":""}
		session.world.event_flags[SEEN_FLAG]=true
		session.world.event_flags[COMPLETE_FLAG]=true
		session.world.event_flags[TRACKING_FLAG]=true
	else:
		session.world.event_flags[progress_flag(current+1)]=true
	return session.persist_change(before)
