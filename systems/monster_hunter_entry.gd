extends RefCounted
## P1-05E: source-canonical first encounter at world-tree/event.
## The actual hunter dialogue, human/cultist clue, and quest completion are
## separate future stages; this file never grants any of them.

const EVENT_ID = "monster_hunter_encounter_01"
const SEEN_FLAG = "event:monster_hunter_encounter_01:seen"
const COMPLETE_FLAG = "event:monster_hunter_encounter_01:complete"
const COMMANDER_ID = "knight_commander_contamination_01"
const COMMANDER_COMPLETE_FLAG = "event:knight_commander_contamination_01:complete"
const RECOGNITION_FLAG = "story:knight_commander:recognizes_player"
const QUEST_ACTIVE_FLAG = "quest:contamination_hunter_01:active"
const QUEST_COMPLETE_FLAG = "quest:contamination_hunter_01:complete"
const CULTIST_CLUE_FLAG = "story:cultist:human_involvement_clue"
const BASE_ART = "res://assets/map/events/monster-hunter-worldtree-base.webp"
const SCENE_ART = "res://assets/map/events/monster-hunter-corrupted-beast-scene.webp"
const PORTRAIT_ART = "res://assets/map/events/monster-hunter-pen-clean.webp"
const FIRST_BEAT = {
	"id":"arrival",
	"effect":"세계수 성역 안쪽. 오래된 성역 사이로 불길한 오염의 흔적이 이어져 있다.",
	"dialogue":"",
	"speaker":"",
	"visual":"base"
}

static func can_enter(session, index: int) -> bool:
	if session == null or session.world == null: return false
	var w = session.world
	if index<0 or index>=w.tiles.size() or w.position!=index: return false
	if w.tiles[index] not in ["unknown","event"]: return false
	if not session.encounter.is_empty() or not w.active_encounter.is_empty(): return false
	if not w.pending_move.is_empty() or not w.pending_reward.is_empty(): return false
	# A quest flag alone is insufficient: the actual commander story must
	# have completed, and recognized the player through the rescue route.
	var commander: Dictionary=session.get_story_event(COMMANDER_ID)
	if commander.status!="complete": return false
	if w.event_flags.get(COMMANDER_COMPLETE_FLAG,false)!=true: return false
	if w.event_flags.get(RECOGNITION_FLAG,false)!=true: return false
	if w.event_flags.get(QUEST_ACTIVE_FLAG,false)!=true: return false
	if w.event_flags.get(QUEST_COMPLETE_FLAG,false)==true: return false
	if w.event_flags.get(COMPLETE_FLAG,false)==true: return false
	if w.event_flags.get(CULTIST_CLUE_FLAG,false)==true: return false
	var state: Dictionary=session.get_story_event(EVENT_ID)
	if state.status not in ["unseen","seen"]: return false
	if state.choice!="" or state.battle_result!="": return false
	# Fail closed for contradictory seen flags instead of silently repairing
	# or repeating a possibly already-consumed story event.
	if (state.status=="seen") != (w.event_flags.get(SEEN_FLAG,false)==true): return false
	return true

static func begin(session, index: int) -> bool:
	if not can_enter(session,index): return false
	var w=session.world
	if session.get_story_event(EVENT_ID).status=="seen": return true
	var before: Dictionary=w.snapshot().duplicate(true)
	w.story_events[EVENT_ID]={"status":"seen","choice":"","battle_result":""}
	w.event_flags[SEEN_FLAG]=true
	return session.persist_change(before)
