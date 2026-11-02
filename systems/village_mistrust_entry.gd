extends RefCounted
const Altar = preload("res://systems/cultist_altar_entry.gd")
const Beats = preload("res://systems/village_mistrust_beats.gd")
## A delayed, one-time consequence of the actual covert altar investigation.
## No contamination threshold: the pending witness account follows the act.
const EVENT_ID = "village_mistrust_01"
const SEEN_FLAG = "event:village_mistrust_01:seen"
const COMPLETE_FLAG = "event:village_mistrust_01:complete"
const PENDING_FLAG = Altar.MISTRUST_PENDING_FLAG
const WITNESS_FLAG = Altar.COOPERATION_WITNESSED_FLAG
const DISTRUST_FLAG = "story:village:trust_eroded"

static func source_valid(session) -> bool:
	if session==null or session.world==null: return false
	return Altar.completed(session) and session.get_story_event(Altar.EVENT_ID).choice=="infiltrate" and session.world.event_flags.get(WITNESS_FLAG,false)==true

static func progress_flag(index: int) -> String:
	if index<1 or index>=Beats.count(): return ""
	return "event:%s:beat:%d" % [EVENT_ID,index]

static func checkpoint(session) -> int:
	if session==null or session.world==null: return -1
	var prefix: String="event:%s:beat:" % EVENT_ID
	for key in session.world.event_flags:
		if str(key).begins_with(prefix) and session.world.event_flags[key]==true:
			var suffix: String=str(key).trim_prefix(prefix)
			if not suffix.is_valid_int() or str(int(suffix))!=suffix or int(suffix)<1 or int(suffix)>=Beats.count(): return -1
	var result: int=0
	var gap: bool=false
	for index in range(1,Beats.count()):
		if session.world.event_flags.get(progress_flag(index),false)==true:
			if gap: return -1
			result=index
		else: gap=true
	return result

static func can_enter(session, index: int) -> bool:
	if not source_valid(session): return false
	var w=session.world
	if not w.run_result.is_empty(): return false
	if index<0 or index>=w.tiles.size() or w.position!=index or w.tiles[index]!="village": return false
	if not session.encounter.is_empty() or not w.active_encounter.is_empty(): return false
	if not w.pending_move.is_empty() or not w.pending_reward.is_empty(): return false
	if w.event_flags.get(PENDING_FLAG,false)!=true: return false
	if w.event_flags.get(COMPLETE_FLAG,false)==true or w.event_flags.get(DISTRUST_FLAG,false)==true: return false
	var state: Dictionary=session.get_story_event(EVENT_ID)
	if state.status not in ["unseen","seen"] or state.choice!="" or state.battle_result!="": return false
	if (state.status=="seen")!=(w.event_flags.get(SEEN_FLAG,false)==true): return false
	var current: int=checkpoint(session)
	return current>=0 and (state.status=="seen" or current==0)

static func begin(session, index: int) -> bool:
	if not can_enter(session,index): return false
	if session.get_story_event(EVENT_ID).status=="seen": return true
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[EVENT_ID]={"status":"seen","choice":"","battle_result":""}
	session.world.event_flags[SEEN_FLAG]=true
	return session.persist_change(before)

static func current_beat(session) -> int:
	if not source_valid(session): return -1
	var state: Dictionary=session.get_story_event(EVENT_ID)
	if state.status!="seen" or state.choice!="" or state.battle_result!="": return -1
	var flags: Dictionary=session.world.event_flags
	if flags.get(SEEN_FLAG,false)!=true or flags.get(PENDING_FLAG,false)!=true: return -1
	if flags.get(COMPLETE_FLAG,false)==true or flags.get(DISTRUST_FLAG,false)==true: return -1
	return checkpoint(session)

static func advance(session, index: int, shown_index: int) -> bool:
	if not can_enter(session,index): return false
	var current: int=current_beat(session)
	if current<0 or current!=shown_index: return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	if Beats.is_final(current):
		session.world.story_events[EVENT_ID]={"status":"complete","choice":"","battle_result":""}
		session.world.event_flags[COMPLETE_FLAG]=true
		session.world.event_flags[PENDING_FLAG]=false
		session.world.event_flags[DISTRUST_FLAG]=true
	else:
		session.world.event_flags[progress_flag(current+1)]=true
	return session.persist_change(before)

static func completed(session) -> bool:
	if not source_valid(session): return false
	var state: Dictionary=session.get_story_event(EVENT_ID)
	if state.status!="complete" or state.choice!="" or state.battle_result!="": return false
	var flags: Dictionary=session.world.event_flags
	return flags.get(SEEN_FLAG,false)==true and flags.get(COMPLETE_FLAG,false)==true and flags.get(DISTRUST_FLAG,false)==true and flags.get(PENDING_FLAG,false)!=true and checkpoint(session)==Beats.count()-1
