extends RefCounted
const Mistrust = preload("res://systems/village_mistrust_entry.gd")
const Beats = preload("res://systems/commander_inquiry_beats.gd")
## A new visit and an acknowledged witness rumor precede the inquiry.
## Original commander/quest receipts are historical and never rewritten here.
const EVENT_ID = "knight_commander_inquiry_01"
const SEEN_FLAG = "event:knight_commander_inquiry_01:seen"
const COMPLETE_FLAG = "event:knight_commander_inquiry_01:complete"
const EXPLAIN_FLAG = "event:knight_commander_inquiry_01:choice_explain"
const WITHHOLD_FLAG = "event:knight_commander_inquiry_01:choice_withhold"
const TESTIMONY_FLAG = "story:commander_inquiry_01:account_recorded"
const DEFERRED_FLAG = "story:commander_inquiry_01:judgment_deferred"
const WITHHELD_FLAG = "story:commander_inquiry_01:account_withheld"
const WATCH_FLAG = "story:commander_inquiry_01:watch_ordered"
const ESCALATED_FLAG = "story:commander_inquiry_01:distrust_escalated"

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

static func valid_state(session) -> bool:
	if not Mistrust.completed(session): return false
	var state: Dictionary=session.get_story_event(EVENT_ID)
	var flags: Dictionary=session.world.event_flags
	var current: int=checkpoint(session)
	if current<0 or state.battle_result!="": return false
	if state.status not in ["unseen","seen","active","complete"]: return false
	if (state.status!="unseen")!=(flags.get(SEEN_FLAG,false)==true): return false
	var complete: bool=state.status=="complete"
	if complete!=(flags.get(COMPLETE_FLAG,false)==true): return false
	var decided: bool=state.status in ["active","complete"]
	if decided:
		if state.choice not in ["explain","withhold"] or current<3: return false
		if complete and not Beats.is_final(current): return false
	else:
		if state.choice!="" or current>2 or (state.status=="unseen" and current!=0): return false
	if (flags.get(EXPLAIN_FLAG,false)==true)!=(decided and state.choice=="explain"): return false
	if (flags.get(WITHHOLD_FLAG,false)==true)!=(decided and state.choice=="withhold"): return false
	for key in [TESTIMONY_FLAG,DEFERRED_FLAG]:
		if (flags.get(key,false)==true)!=(complete and state.choice=="explain"): return false
	for key in [WITHHELD_FLAG,WATCH_FLAG,ESCALATED_FLAG]:
		if (flags.get(key,false)==true)!=(complete and state.choice=="withhold"): return false
	return true

static func can_enter(session, index: int) -> bool:
	if not valid_state(session): return false
	var w=session.world
	if not w.run_result.is_empty(): return false
	if index<0 or index>=w.tiles.size() or w.position!=index or w.tiles[index]!="village": return false
	if not session.encounter.is_empty() or not w.active_encounter.is_empty(): return false
	if not w.pending_move.is_empty() or not w.pending_reward.is_empty(): return false
	var state: Dictionary=session.get_story_event(EVENT_ID)
	if state.status=="complete": return false
	if state.status=="unseen" and w.event_flags.get(Mistrust.finished_visit_flag(session,index),false)==true: return false
	return true

static func begin(session, index: int) -> bool:
	if not can_enter(session,index): return false
	if session.get_story_event(EVENT_ID).status!="unseen": return true
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[EVENT_ID]={"status":"seen","choice":"","battle_result":""}
	session.world.event_flags[SEEN_FLAG]=true
	return session.persist_change(before)

static func current_beat(session) -> int:
	if session==null or session.world==null or not can_enter(session,session.world.position): return -1
	if session.get_story_event(EVENT_ID).status=="unseen": return -1
	return checkpoint(session)

static func choose(session, index: int, shown_index: int, decision: String) -> bool:
	if not can_enter(session,index) or shown_index!=2 or current_beat(session)!=2: return false
	if session.get_story_event(EVENT_ID).status!="seen" or decision not in ["explain","withhold"]: return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[EVENT_ID]={"status":"active","choice":decision,"battle_result":""}
	session.world.event_flags[EXPLAIN_FLAG if decision=="explain" else WITHHOLD_FLAG]=true
	session.world.event_flags[progress_flag(3)]=true
	return session.persist_change(before)

## Intent can change until the first response has been acknowledged.
static func reconsider(session, index: int) -> bool:
	if not can_enter(session,index) or current_beat(session)!=3: return false
	if session.get_story_event(EVENT_ID).status!="active": return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[EVENT_ID]={"status":"seen","choice":"","battle_result":""}
	for key in [EXPLAIN_FLAG,WITHHOLD_FLAG,progress_flag(3)]: session.world.event_flags.erase(key)
	return session.persist_change(before)

static func advance(session, index: int, shown_index: int) -> bool:
	if not can_enter(session,index): return false
	var current: int=current_beat(session)
	if current<0 or current!=shown_index or current==2: return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	if Beats.is_final(current):
		var decision: String=session.get_story_event(EVENT_ID).choice
		session.world.story_events[EVENT_ID]={"status":"complete","choice":decision,"battle_result":""}
		session.world.event_flags[COMPLETE_FLAG]=true
		for key in ([TESTIMONY_FLAG,DEFERRED_FLAG] if decision=="explain" else [WITHHELD_FLAG,WATCH_FLAG,ESCALATED_FLAG]):
			session.world.event_flags[key]=true
	else:
		session.world.event_flags[progress_flag(current+1)]=true
	return session.persist_change(before)

static func completed(session) -> bool:
	return valid_state(session) and session.get_story_event(EVENT_ID).status=="complete"
