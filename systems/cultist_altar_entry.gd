extends RefCounted
const AltarBeats = preload("res://systems/cultist_altar_beats.gd")
## P1-05I-5: original fight, pass, battle outcome and ritual-tracking handoff.
## The separate later ritual portal / monster-king revival remains locked.

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
const BATTLE_WON_FLAG = "battle:cultist_altar_encounter_01:won"
const BATTLE_LOST_FLAG = "battle:cultist_altar_encounter_01:lost"
const RESULT_PENDING_FLAG = "story:cultist_altar_encounter_01:result_pending"
const BASE_ART = "res://assets/map/events/cultist-altar-night-base.webp"
const FIRST_BEAT = {
	"id":"arrival",
	"effect":"밤의 제단. 평소라면 비어 있어야 할 장소에 촛불과 의식 도구가 놓여 있다.",
	"dialogue":"",
	"speaker":"",
	"visual":"base"
}

## A saved choice and a concluded, acknowledged battle are the only
## eligible handoff states. Merely selecting fight never completes the story.
static func followup_ready(session, index: int) -> bool:
	if not can_enter(session,index): return false
	if current_beat(session)!=2: return false
	var state: Dictionary=session.get_story_event(EVENT_ID)
	if state.status!="active": return false
	if session.world.event_flags.get(RESULT_PENDING_FLAG,false)==true: return false
	if state.choice=="pass":
		return state.battle_result=="" and not session.world.event_flags.get(BATTLE_WON_FLAG,false)==true and not session.world.event_flags.get(BATTLE_LOST_FLAG,false)==true
	return state.choice=="fight" and state.battle_result in ["won","lost"]

## The final confirmation is the only point that awards tracking progress.
## The existing story state, completed marker, three quest flags and choice
## receipt are persisted together; failure rolls the entire save back.
static func finish(session, index: int) -> bool:
	if session == null or session.world == null: return false
	if completed(session): return true
	if not followup_ready(session,index): return false
	var state: Dictionary=session.get_story_event(EVENT_ID)
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[EVENT_ID]={"status":"complete","choice":str(state.choice),"battle_result":str(state.battle_result)}
	session.world.event_flags[SEEN_FLAG]=true
	session.world.event_flags[COMPLETE_FLAG]=true
	session.world.event_flags[RITUAL_CONFIRMED_FLAG]=true
	session.world.event_flags[TRACKING_FLAG]=false
	session.world.event_flags[RITUAL_TRACKING_FLAG]=true
	return session.persist_change(before)

## Repeated completion never writes a new receipt or re-enters the event.
static func completed(session) -> bool:
	if session == null or session.world == null: return false
	var state: Dictionary=session.get_story_event(EVENT_ID)
	var flags: Dictionary=session.world.event_flags
	if state.status!="complete" or state.choice not in ["fight","pass"]: return false
	if flags.get(SEEN_FLAG,false)!=true or flags.get(COMPLETE_FLAG,false)!=true: return false
	if flags.get(RITUAL_CONFIRMED_FLAG,false)!=true: return false
	if flags.get(TRACKING_FLAG,false)!=false or flags.get(RITUAL_TRACKING_FLAG,false)!=true: return false
	if flags.get(RESULT_PENDING_FLAG,false)==true: return false
	if state.choice=="pass":
		return state.battle_result=="" and flags.get(PASS_FLAG,false)==true and flags.get(FIGHT_FLAG,false)!=true and flags.get(BATTLE_WON_FLAG,false)!=true and flags.get(BATTLE_LOST_FLAG,false)!=true
	return flags.get(FIGHT_FLAG,false)==true and flags.get(PASS_FLAG,false)!=true and state.battle_result in ["won","lost"] and flags.get(BATTLE_WON_FLAG,false)==(state.battle_result=="won") and flags.get(BATTLE_LOST_FLAG,false)==(state.battle_result=="lost")

static func progress_flag(index: int) -> String:
	if index not in [1,2]: return ""
	return "event:%s:beat:%d" % [EVENT_ID,index]

static func can_enter(session, index: int) -> bool:
	if session == null or session.world == null: return false
	var w = session.world
	if index<0 or index>=w.tiles.size() or index!=w.position: return false
	if w.tiles[index] not in ["altar","event"]: return false
	if not session.encounter.is_empty() or not w.active_encounter.is_empty(): return false
	if not w.pending_move.is_empty() or not w.pending_reward.is_empty(): return false
	if session.get_story_event(RUMOR_ID).status!="complete": return false
	if w.event_flags.get(RUMOR_COMPLETE_FLAG,false)!=true: return false
	if w.event_flags.get(TRACKING_FLAG,false)!=true: return false
	for flag in [COMPLETE_FLAG,RITUAL_CONFIRMED_FLAG,RITUAL_TRACKING_FLAG]:
		if w.event_flags.get(flag,false)==true: return false
	var state: Dictionary=session.get_story_event(EVENT_ID)
	if state.status not in ["unseen","seen","active"]: return false
	if state.battle_result not in ["","won","lost"]: return false
	# A committed battle result may re-open for follow-up, but must match
	# its original fight choice and the actual battle outcome receipts.
	if state.battle_result!="":
		if state.status!="active" or state.choice!="fight": return false
		if w.event_flags.get(BATTLE_WON_FLAG,false)!=(state.battle_result=="won"): return false
		if w.event_flags.get(BATTLE_LOST_FLAG,false)!=(state.battle_result=="lost"): return false
	var discovered: bool=w.event_flags.get(SEEN_FLAG,false)==true
	if (state.status!="unseen") != discovered: return false
	var has_ritual: bool=w.event_flags.get(progress_flag(1),false)==true
	var has_choice: bool=w.event_flags.get(progress_flag(2),false)==true
	if has_choice and not has_ritual: return false
	var fight: bool=w.event_flags.get(FIGHT_FLAG,false)==true
	var passed_choice: bool=w.event_flags.get(PASS_FLAG,false)==true
	if state.status=="active":
		# An unfinished decision must be one of the two original choices.
		# A fight/pass receipt on an unseen or unchosen scene is corruption.
		if not has_choice or fight==passed_choice: return false
		return (state.choice=="fight" and fight) or (state.choice=="pass" and passed_choice)
	if state.choice!="" or fight or passed_choice: return false
	if state.status=="unseen" and (has_ritual or has_choice): return false
	return true

## Discovery saves only the arrival receipt; reopened scenes remain unchanged.
static func begin(session, index: int) -> bool:
	if not can_enter(session,index): return false
	if session.get_story_event(EVENT_ID).status!="unseen": return true
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[EVENT_ID]={"status":"seen","choice":"","battle_result":""}
	session.world.event_flags[SEEN_FLAG]=true
	return session.persist_change(before)

static func current_beat(session) -> int:
	if session == null or session.world == null: return -1
	if not can_enter(session,session.world.position): return -1
	if session.get_story_event(EVENT_ID).status=="unseen": return -1
	if session.world.event_flags.get(progress_flag(2),false)==true: return 2
	if session.world.event_flags.get(progress_flag(1),false)==true: return 1
	return 0

## Exactly one explicit click advances exactly one checkpoint (arrival→ritual→choice).
static func advance(session, index: int, shown_index: int) -> bool:
	if not can_enter(session,index): return false
	if session.get_story_event(EVENT_ID).status!="seen": return false
	if current_beat(session)!=shown_index or shown_index not in [0,1]: return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.event_flags[progress_flag(shown_index+1)]=true
	return session.persist_change(before)

## Save the intent first; resolution happens only on the separate final confirmation.
static func choose(session, index: int, shown_index: int, decision: String) -> bool:
	if not can_enter(session,index): return false
	if current_beat(session)!=2 or shown_index!=2: return false
	if session.get_story_event(EVENT_ID).status!="seen": return false
	if decision not in ["fight","pass"]: return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[EVENT_ID]={"status":"active","choice":decision,"battle_result":""}
	session.world.event_flags[FIGHT_FLAG if decision=="fight" else PASS_FLAG]=true
	return session.persist_change(before)

## Before a battle has a committed result, allow deliberate decision changes
## without rewinding arrival or replaying ritual reveal.
static func reconsider(session, index: int) -> bool:
	if not can_enter(session,index): return false
	if current_beat(session)!=2: return false
	if session.get_story_event(EVENT_ID).status!="active": return false
	if session.get_story_event(EVENT_ID).battle_result!="": return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[EVENT_ID]={"status":"seen","choice":"","battle_result":""}
	session.world.event_flags.erase(FIGHT_FLAG)
	session.world.event_flags.erase(PASS_FLAG)
	return session.persist_change(before)
