extends RefCounted
const AltarBeats = preload("res://systems/cultist_altar_beats.gd")
## P1-05I-2: first arrival and ritual-reveal scenes only.
## The fight/pass choice, battle and later quest outcomes stay locked.

const EVENT_ID = "cultist_altar_encounter_01"
const SEEN_FLAG = "event:cultist_altar_encounter_01:seen"
const COMPLETE_FLAG = "event:cultist_altar_encounter_01:complete"
const FIGHT_FLAG = "event:cultist_altar_encounter_01:choice_fight"
const PASS_FLAG = "event:cultist_altar_encounter_01:choice_pass"
const RUMOR_ID = "cultist_rumor_01"
const RUMOR_COMPLETE_FLAG = "event:cultist_rumor_01:complete"
const TRACKING_FLAG = "quest:cultist_tracking_01:active"
const RITUAL_CONFIRMED_FLAG = "story:monster_king:ritual_confirmed"
const RITUAL_TRACKING_FLAG = "quest:ritual_site_tracking:active"
const BASE_ART = "res://assets/map/events/cultist-altar-night-base.webp"
const FIRST_BEAT = {
	"id":"arrival",
	"effect":"밤의 제단. 평소라면 비어 있어야 할 장소에 촛불과 의식 도구가 놓여 있다.",
	"dialogue":"",
	"speaker":"",
	"visual":"base"
}

static func can_enter(session, index: int) -> bool:
	if session == null or session.world == null: return false
	var w = session.world
	if index<0 or index>=w.tiles.size() or index!=w.position: return false
	if w.tiles[index] not in ["altar","event"]: return false
	if not session.encounter.is_empty() or not w.active_encounter.is_empty(): return false
	if not w.pending_move.is_empty() or not w.pending_reward.is_empty(): return false
	# Both the completed preceding story AND the tracking quest must exist.
	if session.get_story_event(RUMOR_ID).status!="complete": return false
	if w.event_flags.get(RUMOR_COMPLETE_FLAG,false)!=true: return false
	if w.event_flags.get(TRACKING_FLAG,false)!=true: return false
	# Never backtrack into a story that was completed elsewhere.
	for flag in [COMPLETE_FLAG,FIGHT_FLAG,PASS_FLAG,RITUAL_CONFIRMED_FLAG,RITUAL_TRACKING_FLAG]:
		if w.event_flags.get(flag,false)==true: return false
	var state: Dictionary=session.get_story_event(EVENT_ID)
	if state.status not in ["unseen","seen"]: return false
	if state.choice!="" or state.battle_result!="": return false
	# Refuse inconsistent saves instead of silently granting a scene.
	if (state.status=="seen") != (w.event_flags.get(SEEN_FLAG,false)==true): return false
	# An unvisited altar cannot already have progressed to the ritual layer.
	if state.status=="unseen" and w.event_flags.get(progress_flag(1),false)==true: return false
	return true

## Discovery persists only the first arrival receipt. No choice or reward.
static func begin(session, index: int) -> bool:
	if not can_enter(session,index): return false
	if session.get_story_event(EVENT_ID).status=="seen": return true
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[EVENT_ID]={"status":"seen","choice":"","battle_result":""}
	session.world.event_flags[SEEN_FLAG]=true
	return session.persist_change(before)

## Persist one extra beat in the existing boolean event_flags schema.
## Beat 1 displays the ritual layer. The original next beat (choice) is locked.
static func progress_flag(index: int) -> String:
	if index!=1: return ""
	return "event:%s:beat:%d" % [EVENT_ID,index]

static func current_beat(session) -> int:
	if session == null or session.world == null: return -1
	if not can_enter(session,session.world.position): return -1
	if session.get_story_event(EVENT_ID).status!="seen": return -1
	return 1 if session.world.event_flags.get(progress_flag(1),false)==true else 0

static func advance(session, index: int, shown_index: int) -> bool:
	if not can_enter(session,index): return false
	if current_beat(session)!=0 or shown_index!=0: return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.event_flags[progress_flag(1)]=true
	return session.persist_change(before)
