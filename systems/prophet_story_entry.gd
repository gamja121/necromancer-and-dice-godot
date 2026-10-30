extends RefCounted
const ContaminationGate = preload("res://systems/story_contamination_gate.gd")
const Commander = preload("res://systems/knight_commander_entry.gd")
const CommanderBeats = preload("res://systems/knight_commander_beats.gd")
const ProphetBeats = preload("res://systems/prophet_story_beats.gd")
const EVENT_ID = "prophet_cultist_clue_01"
const SEEN_FLAG = "event:prophet_cultist_clue_01:seen"
const COMPLETE_FLAG = "event:prophet_cultist_clue_01:complete"
const QUEST_ACTIVE_FLAG = "quest:prophet_cultist_01:active"
const QUEST_COMPLETE_FLAG = "quest:prophet_cultist_01:complete"
const HUMAN_CLUE_FLAG = "story:cultist:human_involvement_clue"
const CULTIST_CLUE_FLAG = HUMAN_CLUE_FLAG
const BASE_ART = "res://assets/map/events/manuscript_prophet_base.png"
const PORTRAIT_ART = "res://assets/map/events/manuscript_prophet_actor.png"
const FIRST_BEAT = {"id":"arrival","effect":"점술가의 막사 안. 낡은 천 사이로 희미한 보랏빛이 새어 나온다.","dialogue":"","speaker":"","visual":"base"}

static func hunter_untouched(session) -> bool:
	if session == null or session.world == null: return false
	var w=session.world
	var hunter: Dictionary=session.get_story_event("monster_hunter_encounter_01")
	if hunter.status!="unseen" or hunter.choice!="" or hunter.battle_result!="": return false
	for flag in [Commander.RECOGNIZED_FLAG,Commander.QUEST_ACTIVE_FLAG,Commander.QUEST_COMPLETE_FLAG,"event:monster_hunter_encounter_01:seen","event:monster_hunter_encounter_01:complete"]:
		if w.event_flags.get(flag,false)==true: return false
	for flag in w.event_flags:
		if str(flag).begins_with("event:monster_hunter_encounter_01:beat:") and w.event_flags[flag]==true: return false
	return true

static func referral_valid(session) -> bool:
	if session == null or session.world == null: return false
	if Commander.route(session)!="prophet" or not hunter_untouched(session): return false
	var w=session.world
	var commander: Dictionary=session.get_story_event(Commander.EVENT_ID)
	if commander.status!="complete" or commander.choice!="" or commander.battle_result!="": return false
	if w.event_flags.get(Commander.SEEN_FLAG,false)!=true or w.event_flags.get(Commander.COMPLETE_FLAG,false)!=true: return false
	for index in range(1,CommanderBeats.count("prophet")):
		if w.event_flags.get(Commander.progress_flag(index,"prophet"),false)!=true: return false
	return true

static func progress_flag(index: int) -> String:
	if index<1 or index>=ProphetBeats.count(): return ""
	return "event:%s:beat:%d" % [EVENT_ID,index]

static func checkpoint(session) -> int:
	if session == null or session.world == null: return -1
	var w=session.world
	var prefix: String="event:%s:beat:" % EVENT_ID
	for flag in w.event_flags:
		if not str(flag).begins_with(prefix) or w.event_flags[flag]!=true: continue
		var suffix: String=str(flag).trim_prefix(prefix)
		if not suffix.is_valid_int(): return -1
		var receipt_index: int=int(suffix)
		if receipt_index<1 or receipt_index>=ProphetBeats.count(): return -1
	var current: int=0
	var gap: bool=false
	for index in range(1,ProphetBeats.count()):
		var found: bool=w.event_flags.get(progress_flag(index),false)==true
		if found and gap: return -1
		if found: current=index
		else: gap=true
	return current

static func current_beat(session) -> int:
	if not referral_valid(session): return -1
	var w=session.world
	var state: Dictionary=session.get_story_event(EVENT_ID)
	if state.status!="seen" or state.choice!="" or state.battle_result!="": return -1
	if w.event_flags.get(SEEN_FLAG,false)!=true: return -1
	if w.event_flags.get(COMPLETE_FLAG,false)==true: return -1
	if w.event_flags.get(QUEST_ACTIVE_FLAG,false)!=true: return -1
	if w.event_flags.get(QUEST_COMPLETE_FLAG,false)==true: return -1
	if w.event_flags.get(HUMAN_CLUE_FLAG,false)==true: return -1
	return checkpoint(session)

static func can_enter(session, index: int) -> bool:
	if session == null or session.world == null: return false
	var w=session.world
	if not w.run_result.is_empty(): return false
	if not ContaminationGate.allows(session,EVENT_ID): return false
	if index<0 or index>=w.tiles.size() or w.position!=index: return false
	if w.tiles[index]!="fortune-teller-camp": return false
	if not session.encounter.is_empty() or not w.active_encounter.is_empty(): return false
	if not w.pending_move.is_empty() or not w.pending_reward.is_empty(): return false
	if not referral_valid(session): return false
	if w.event_flags.get(QUEST_ACTIVE_FLAG,false)!=true: return false
	if w.event_flags.get(QUEST_COMPLETE_FLAG,false)==true: return false
	if w.event_flags.get(COMPLETE_FLAG,false)==true or w.event_flags.get(HUMAN_CLUE_FLAG,false)==true: return false
	var state: Dictionary=session.get_story_event(EVENT_ID)
	if state.status not in ["unseen","seen"]: return false
	if state.choice!="" or state.battle_result!="": return false
	if (state.status=="seen") != (w.event_flags.get(SEEN_FLAG,false)==true): return false
	if state.status=="seen": return current_beat(session)>=0
	return checkpoint(session)==0

static func begin(session, index: int) -> bool:
	if not can_enter(session,index): return false
	if session.get_story_event(EVENT_ID).status=="seen": return true
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[EVENT_ID]={"status":"seen","choice":"","battle_result":""}
	session.world.event_flags[SEEN_FLAG]=true
	return session.persist_change(before)

static func advance(session, index: int, shown_index: int) -> bool:
	if not can_enter(session,index): return false
	var current: int=current_beat(session)
	if current<0 or current!=shown_index: return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	if ProphetBeats.is_final(current):
		session.world.story_events[EVENT_ID]={"status":"complete","choice":"","battle_result":""}
		session.world.event_flags[SEEN_FLAG]=true
		session.world.event_flags[COMPLETE_FLAG]=true
		session.world.event_flags[QUEST_ACTIVE_FLAG]=false
		session.world.event_flags[QUEST_COMPLETE_FLAG]=true
		session.world.event_flags[HUMAN_CLUE_FLAG]=true
	else:
		session.world.event_flags[progress_flag(current+1)]=true
	return session.persist_change(before)

static func completed(session) -> bool:
	if not referral_valid(session): return false
	var w=session.world
	var state: Dictionary=session.get_story_event(EVENT_ID)
	if state.status!="complete" or state.choice!="" or state.battle_result!="": return false
	if w.event_flags.get(SEEN_FLAG,false)!=true or w.event_flags.get(COMPLETE_FLAG,false)!=true: return false
	if w.event_flags.get(QUEST_ACTIVE_FLAG,false)==true or w.event_flags.get(QUEST_COMPLETE_FLAG,false)!=true: return false
	if w.event_flags.get(HUMAN_CLUE_FLAG,false)!=true: return false
	return checkpoint(session)==ProphetBeats.count()-1
