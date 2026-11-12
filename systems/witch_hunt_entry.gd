extends RefCounted
const Inquiry=preload("res://systems/commander_inquiry_entry.gd")
const Beats=preload("res://systems/witch_hunt_beats.gd")
const Riot=preload("res://systems/witch_hunt_riot.gd")
const IDS=["witness_confrontation_01","village_mob_01","home_arson_01"]
const PUBLIC_FLAG="story:witness_confrontation_01:public_account"
const REFUSED_FLAG="story:witness_confrontation_01:confrontation_refused"
const ESCORT_FLAG="story:village_mob_01:guard_escort"
const ALONE_FLAG="story:village_mob_01:returned_alone"
const PROTECTED_FLAG="story:home_arson_01:protected"
const DAMAGED_FLAG="story:home_arson_01:damaged"
const BURNED_FLAG="story:home_arson_01:burned"
const RESCUED_FLAG="story:home_arson_01:resident_rescued_by_player"
const INJURED_FLAG="story:home_arson_01:resident_injured"
const ARSON_FLAG="story:home_arson_01:mob_arson_attempt"

static func flag(stage: int, suffix: String) -> String:
	return "event:%s:%s" % [IDS[stage],suffix] if stage in [0,1,2] else ""
static func progress_flag(stage: int, index: int) -> String:
	return flag(stage,"beat:%d" % index) if index>0 and index<Beats.count() else ""
static func finished_visit_flag(session, stage: int, index: int) -> String:
	return session.place_visit_id("witch-hunt-%d-finished" % stage,index)
static func checkpoint(session, stage: int) -> int:
	if session==null or session.world==null or stage not in [0,1,2]: return -1
	var prefix: String=flag(stage,"beat:")
	for key in session.world.event_flags:
		if str(key).begins_with(prefix) and session.world.event_flags[key]==true:
			var suffix: String=str(key).trim_prefix(prefix)
			if not suffix.is_valid_int() or str(int(suffix))!=suffix or int(suffix)<1 or int(suffix)>=Beats.count(): return -1
	var current: int=0
	var gap: bool=false
	for index in range(1,Beats.count()):
		if session.world.event_flags.get(progress_flag(stage,index),false)==true:
			if gap: return -1
			current=index
		else: gap=true
	return current
static func outcome_flags(session, stage: int, decision: String) -> Array:
	if stage==0: return [PUBLIC_FLAG] if decision=="confront" else [REFUSED_FLAG]
	if stage==1: return [ESCORT_FLAG] if decision=="escort" else [ALONE_FLAG]
	var escorted: bool=session.get_story_event(IDS[1]).choice=="escort"
	var outcome: String=Beats.outcome(decision,escorted)
	var result: Array=[ARSON_FLAG,PROTECTED_FLAG if outcome=="protected" else (BURNED_FLAG if outcome=="burned" else DAMAGED_FLAG)]
	if decision=="rescue": result.append(RESCUED_FLAG)
	if outcome=="damaged": result.append(INJURED_FLAG)
	return result
static func all_outcome_flags(stage: int) -> Array:
	if stage==0: return [PUBLIC_FLAG,REFUSED_FLAG]
	if stage==1: return [ESCORT_FLAG,ALONE_FLAG]
	return [PROTECTED_FLAG,DAMAGED_FLAG,BURNED_FLAG,RESCUED_FLAG,INJURED_FLAG,ARSON_FLAG]
static func valid_state(session, stage: int) -> bool:
	if stage not in [0,1,2] or session==null or session.world==null: return false
	if stage==0:
		if not Inquiry.completed(session): return false
	elif not completed(session,stage-1): return false
	var state: Dictionary=session.get_story_event(IDS[stage])
	var flags: Dictionary=session.world.event_flags
	var current: int=checkpoint(session,stage)
	if current<0 or state.battle_result!="" or state.status not in ["unseen","seen","active","complete"]: return false
	if (state.status!="unseen")!=(flags.get(flag(stage,"seen"),false)==true): return false
	var complete: bool=state.status=="complete"
	if complete!=(flags.get(flag(stage,"complete"),false)==true): return false
	var decided: bool=state.status in ["active","complete"]
	if decided:
		if state.choice not in Beats.DECISIONS[stage] or current<=Beats.CHOICE_INDEX: return false
		if complete and current!=Beats.count()-1: return false
	elif state.choice!="" or current>Beats.CHOICE_INDEX or (state.status=="unseen" and current!=0): return false
	for decision in Beats.DECISIONS[stage]:
		if (flags.get(flag(stage,"choice_"+decision),false)==true)!=(decided and state.choice==decision): return false
	var expected: Array=outcome_flags(session,stage,state.choice) if complete else []
	for key in all_outcome_flags(stage):
		if (flags.get(key,false)==true)!=(key in expected): return false
	return true
static func completed(session, stage: int) -> bool:
	return valid_state(session,stage) and session.get_story_event(IDS[stage]).status=="complete"
static func can_enter(session, stage: int, index: int) -> bool:
	if not valid_state(session,stage): return false
	var w=session.world
	if not w.run_result.is_empty(): return false
	if index<0 or index>=w.tiles.size() or w.position!=index: return false
	if stage==0 and w.tiles[index]!="village": return false
	if stage==2 and (w.tiles[index]!="home" or not w.riot.is_empty()): return false
	if not session.encounter.is_empty() or not w.active_encounter.is_empty() or not w.pending_move.is_empty() or not w.pending_reward.is_empty(): return false
	var state: Dictionary=session.get_story_event(IDS[stage])
	if state.status=="complete": return false
	if state.status=="unseen":
		var previous_visit: String=Inquiry.finished_visit_flag(session,index) if stage==0 else finished_visit_flag(session,stage-1,index)
		if w.event_flags.get(previous_visit,false)==true: return false
	return true
static func eligible_stage(session, index: int) -> int:
	for stage in range(3):
		if can_enter(session,stage,index): return stage
	return -1
static func begin(session, stage: int, index: int) -> bool:
	if not can_enter(session,stage,index): return false
	if session.get_story_event(IDS[stage]).status!="unseen": return true
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[IDS[stage]]={"status":"seen","choice":"","battle_result":""}
	session.world.event_flags[flag(stage,"seen")]=true
	return session.persist_change(before)
static func current_beat(session, stage: int) -> int:
	if session==null or session.world==null or not can_enter(session,stage,session.world.position): return -1
	return -1 if session.get_story_event(IDS[stage]).status=="unseen" else checkpoint(session,stage)
static func choose(session, stage: int, index: int, shown_index: int, decision: String) -> bool:
	if not can_enter(session,stage,index) or shown_index!=Beats.CHOICE_INDEX or current_beat(session,stage)!=shown_index: return false
	if session.get_story_event(IDS[stage]).status!="seen" or decision not in Beats.DECISIONS[stage]: return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[IDS[stage]]={"status":"active","choice":decision,"battle_result":""}
	session.world.event_flags[flag(stage,"choice_"+decision)]=true
	session.world.event_flags[progress_flag(stage,shown_index+1)]=true
	return session.persist_change(before)
static func reconsider(session, stage: int, index: int) -> bool:
	if not can_enter(session,stage,index) or current_beat(session,stage)!=Beats.CHOICE_INDEX+1: return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[IDS[stage]]={"status":"seen","choice":"","battle_result":""}
	for decision in Beats.DECISIONS[stage]: session.world.event_flags.erase(flag(stage,"choice_"+decision))
	session.world.event_flags.erase(progress_flag(stage,Beats.CHOICE_INDEX+1))
	return session.persist_change(before)
static func advance(session, stage: int, index: int, shown_index: int) -> bool:
	if not can_enter(session,stage,index): return false
	var current: int=current_beat(session,stage)
	if current<0 or current!=shown_index or current==Beats.CHOICE_INDEX: return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	if current==Beats.count()-1:
		var decision: String=session.get_story_event(IDS[stage]).choice
		session.world.story_events[IDS[stage]]={"status":"complete","choice":decision,"battle_result":""}
		session.world.event_flags[flag(stage,"complete")]=true
		session.world.event_flags[finished_visit_flag(session,stage,index)]=true
		for key in outcome_flags(session,stage,decision): session.world.event_flags[key]=true
		if stage == 1: Riot.start(session.world)
	else: session.world.event_flags[progress_flag(stage,current+1)]=true
	return session.persist_change(before)
static func home_in_progress(session) -> bool:
	return valid_state(session,2) and session.get_story_event(IDS[2]).status in ["seen","active"]
static func home_burned(session) -> bool:
	if session != null and session.world != null and session.world.riot.get("state", "") == "burned": return true
	return completed(session,2) and session.world.event_flags.get(BURNED_FLAG,false)==true
static func current_scene(session, stage: int) -> Dictionary:
	var current: int=current_beat(session,stage)
	if current<0: return {}
	return Beats.beat(stage,current,session.get_story_event(IDS[stage]).choice,session.get_story_event(Inquiry.EVENT_ID).choice=="explain",session.get_story_event(IDS[0]).choice=="confront",session.get_story_event(IDS[1]).choice=="escort")
