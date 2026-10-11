extends RefCounted
## P1-05J-5: original intervention beat and saved fight commitment.
## The king's actual revival and completed tracking quest are later.
const CultistAltar = preload("res://systems/cultist_altar_entry.gd")
const PortalBeats = preload("res://systems/ritual_portal_beats.gd")

const EVENT_ID = "ritual_portal_trace_01"
const SEEN_FLAG = "event:ritual_portal_trace_01:seen"
const COMPLETE_FLAG = "event:ritual_portal_trace_01:complete"
const RITUAL_CONFIRMED_FLAG = "story:monster_king:ritual_confirmed"
const TRACKING_FLAG = "quest:ritual_site_tracking:active"
const TRACKING_COMPLETE_FLAG = "quest:ritual_site_tracking:complete"
const PORTAL_FOUND_FLAG = "story:ritual_portal:found"
const SITE_LOCATION_FLAG = "story:monster_king:ritual_site_location_known"
const INTERVENTION_FLAG = "quest:ritual_intervention:active"
const REVIVED_FLAG = "story:monster_king:revived"
const HUNT_FLAG = "quest:monster_king_hunt:active"
const BATTLE_WON_FLAG = "battle:ritual_portal_trace_01:won"
const BATTLE_LOST_FLAG = "battle:ritual_portal_trace_01:lost"
const RESULT_PENDING_FLAG = "story:ritual_portal_trace_01:result_pending"
const INTERVENE_CHOICE_FLAG = "event:ritual_portal_trace_01:choice_intervene"
const BASE_ART = PortalBeats.BASE_ART
const FIRST_BEAT = {
	"id":"arrival",
	"effect":"제단에서 이어진 흔적을 따라가자 숲 깊은 폐허에서 거대한 전이문을 발견한다.",
	"dialogue":"",
	"speaker":"",
	"visual":"base"
}

static func can_enter(session, index: int) -> bool:
	if session == null or session.world == null: return false
	var w = session.world
	if index<0 or index>=w.tiles.size() or index!=w.position: return false
	if w.tiles[index] not in ["forest","event"]: return false
	if not session.encounter.is_empty() or not w.active_encounter.is_empty(): return false
	if not w.pending_move.is_empty() or not w.pending_reward.is_empty(): return false
	# The previous altar must be *completed* with consistent choice/result
	# receipts; a lone quest flag is never enough to unlock this scene.
	if not CultistAltar.completed(session): return false
	if w.event_flags.get(RITUAL_CONFIRMED_FLAG,false)!=true: return false
	if w.event_flags.get(TRACKING_FLAG,false)!=true: return false
	for flag in [COMPLETE_FLAG,TRACKING_COMPLETE_FLAG,PORTAL_FOUND_FLAG,SITE_LOCATION_FLAG,INTERVENTION_FLAG,REVIVED_FLAG,HUNT_FLAG]:
		if w.event_flags.get(flag,false)==true: return false
	var state: Dictionary = session.get_story_event(EVENT_ID)
	if state.status not in ["unseen","seen","active"]: return false
	if state.battle_result not in ["","won","lost"]: return false
	var discovered: bool = w.event_flags.get(SEEN_FLAG,false)==true
	if (state.status!="unseen")!=discovered: return false
	# Receipts must be sequential: arrival → energy → cultists → omen → intervene.
	var energy_saved: bool=w.event_flags.get(progress_flag(1),false)==true
	var cultists_saved: bool=w.event_flags.get(progress_flag(2),false)==true
	var omen_saved: bool=w.event_flags.get(progress_flag(3),false)==true
	var intervene_saved: bool=w.event_flags.get(progress_flag(4),false)==true
	if intervene_saved and not omen_saved: return false
	if omen_saved and not cultists_saved: return false
	if cultists_saved and not energy_saved: return false
	if energy_saved and not discovered: return false
	var chosen: bool=w.event_flags.get(INTERVENE_CHOICE_FLAG,false)==true
	if chosen != (state.status=="active" and state.choice=="intervene"): return false
	if state.status in ["unseen","seen"] and (state.choice!="" or state.battle_result!=""): return false
	if state.status=="active" and not intervene_saved: return false
	# Completed fights stay resumable for their later story resolution,
	# but must match exactly one real outcome receipt.
	if state.battle_result!="":
		if state.status!="active": return false
		if w.event_flags.get(BATTLE_WON_FLAG,false)!=(state.battle_result=="won"): return false
		if w.event_flags.get(BATTLE_LOST_FLAG,false)!=(state.battle_result=="lost"): return false
	elif w.event_flags.get(BATTLE_WON_FLAG,false)==true or w.event_flags.get(BATTLE_LOST_FLAG,false)==true:
		return false
	if w.event_flags.get(RESULT_PENDING_FLAG,false)==true and state.battle_result=="": return false
	return true

## Save discovery once. Reopening retains the latest visual checkpoint;
## no scene grants ritual-completion or battle progress.
static func begin(session, index: int) -> bool:
	if not can_enter(session,index): return false
	if session.get_story_event(EVENT_ID).status=="seen": return true
	var before: Dictionary = session.world.snapshot().duplicate(true)
	session.world.story_events[EVENT_ID] = {"status":"seen","choice":"","battle_result":""}
	session.world.event_flags[SEEN_FLAG] = true
	return session.persist_change(before)

static func progress_flag(index: int) -> String:
	if index not in [1,2,3,4]: return ""
	return "event:%s:beat:%d" % [EVENT_ID,index]

static func current_beat(session) -> int:
	if session == null or session.world == null: return -1
	if not can_enter(session,session.world.position): return -1
	if session.get_story_event(EVENT_ID).status not in ["seen","active"]: return -1
	if session.world.event_flags.get(progress_flag(4),false)==true: return 4
	if session.world.event_flags.get(progress_flag(3),false)==true: return 3
	if session.world.event_flags.get(progress_flag(2),false)==true: return 2
	return 1 if session.world.event_flags.get(progress_flag(1),false)==true else 0

## Each explicit Continue advances exactly one persisted scene:
## arrival → energy → cultists → omen → intervention. Never skip a beat.
static func advance(session, index: int, shown_index: int) -> bool:
	if not can_enter(session,index): return false
	if session.get_story_event(EVENT_ID).status!="seen": return false
	if shown_index not in [0,1,2,3] or current_beat(session)!=shown_index: return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.event_flags[progress_flag(shown_index+1)]=true
	return session.persist_change(before)


## Only a deliberate button on the canonical fifth beat commits to intervening.
## This is not a battle result or revival event; the deck is chosen separately.
static func choose_intervention(session, index: int, shown_index: int) -> bool:
	if not can_enter(session,index): return false
	if shown_index!=4 or current_beat(session)!=4: return false
	if session.get_story_event(EVENT_ID).status!="seen": return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.story_events[EVENT_ID]={"status":"active","choice":"intervene","battle_result":""}
	session.world.event_flags[INTERVENE_CHOICE_FLAG]=true
	return session.persist_change(before)
