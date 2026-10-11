extends RefCounted
## P1-05J-1: discover and reopen the original ritual portal arrival only.
## No future layers, combat, quest completion or monster-king revival are allowed.
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
	for flag in [COMPLETE_FLAG,TRACKING_COMPLETE_FLAG,PORTAL_FOUND_FLAG,SITE_LOCATION_FLAG,INTERVENTION_FLAG,REVIVED_FLAG,HUNT_FLAG,BATTLE_WON_FLAG,BATTLE_LOST_FLAG,RESULT_PENDING_FLAG]:
		if w.event_flags.get(flag,false)==true: return false
	var state: Dictionary = session.get_story_event(EVENT_ID)
	if state.status not in ["unseen","seen"]: return false
	if state.choice!="" or state.battle_result!="": return false
	var discovered: bool = w.event_flags.get(SEEN_FLAG,false)==true
	return (state.status=="seen")==discovered

## Save the discovery receipt in the same transaction as the first story
## status. Never advance past beat 0 or invent any battle/quest progress.
static func begin(session, index: int) -> bool:
	if not can_enter(session,index): return false
	if session.get_story_event(EVENT_ID).status=="seen": return true
	var before: Dictionary = session.world.snapshot().duplicate(true)
	session.world.story_events[EVENT_ID] = {"status":"seen","choice":"","battle_result":""}
	session.world.event_flags[SEEN_FLAG] = true
	return session.persist_change(before)

static func current_beat(session) -> int:
	if session == null or session.world == null: return -1
	if not can_enter(session,session.world.position): return -1
	return 0 if session.get_story_event(EVENT_ID).status=="seen" else -1
