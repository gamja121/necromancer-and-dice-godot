extends RefCounted
## The final king is met ON the already-painted warp, after the actual
## last hunt scene and contamination gate. Three acknowledged story beats
## lead to the existing owned-monster deck picker; no automatic battle.
const KingTile = preload("res://systems/king_portal_tile.gd")
const SEEN = "story:monster_king:warp_encounter_seen"
const BEAT_ONE = "story:monster_king:warp_encounter_beat:1"
const BEAT_TWO = "story:monster_king:warp_encounter_beat:2"
const ACK = "story:monster_king:warp_encounter_ack"
const WON = "story:monster_king:boss_won"
const ENDING_ACK = "story:monster_king:ending_ack"
const BEATS = [
	{"title":"봉인 폐허의 균열","effect":"오래된 봉인이 부서진 자리에서 검은 소용돌이가 맥동한다. 마물의 왕이 지나간 흔적이 이 웜홀에 남아 있다."},
	{"title":"왕의 응시","effect":"균열 너머로 거대한 용의 머리가 떠오른다. 사냥꾼이 추적하던 마물의 왕이 마침내 당신을 바라본다."},
	{"title":"최후의 대면","effect":"왕의 포효가 폐허를 흔든다. 더는 추적할 필요가 없다. 마물들을 이끌고 결전에 나설 시간이다."}
]

static func location_ready(world, index: int) -> bool:
	return world!=null and world.tiles.size()==24 and index==world.position and KingTile.target(world)==index and world.boss_available() and world.event_flags.get(WON,false)!=true

static func can_enter(session, index: int) -> bool:
	if session==null or session.world==null or not location_ready(session.world,index): return false
	var w=session.world
	return session.encounter.is_empty() and w.active_encounter.is_empty() and w.pending_move.is_empty() and w.pending_reward.is_empty() and w.run_result.is_empty()

static func begin(session, index: int) -> bool:
	if not can_enter(session,index): return false
	if session.world.event_flags.get(SEEN,false)==true: return true
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.event_flags[SEEN]=true
	return session.persist_change(before)

static func beat(world) -> int:
	if world==null or world.event_flags.get(SEEN,false)!=true: return -1
	if world.event_flags.get(BEAT_TWO,false)==true: return 2
	if world.event_flags.get(BEAT_ONE,false)==true: return 1
	return 0

static func advance(session,index: int,shown: int) -> bool:
	if not can_enter(session,index) or session.world.event_flags.get(ACK,false)==true: return false
	if shown not in [0,1] or beat(session.world)!=shown: return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.event_flags[BEAT_ONE if shown==0 else BEAT_TWO]=true
	return session.persist_change(before)

static func acknowledge(session,index: int) -> bool:
	if not can_enter(session,index) or beat(session.world)!=2: return false
	if session.world.event_flags.get(ACK,false)==true: return true
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.event_flags[ACK]=true
	return session.persist_change(before)

static func battle_ready(world,index: int) -> bool:
	return location_ready(world,index) and world.event_flags.get(ACK,false)==true

static func ending_pending(world) -> bool:
	return world!=null and world.event_flags.get(WON,false)==true and world.event_flags.get(ENDING_ACK,false)!=true and world.run_result.is_empty()

static func acknowledge_ending(session) -> bool:
	if session==null or session.world==null or not ending_pending(session.world): return false
	if not session.encounter.is_empty() or not session.world.active_encounter.is_empty(): return false
	var before: Dictionary=session.world.snapshot().duplicate(true)
	session.world.event_flags[ENDING_ACK]=true
	return session.persist_change(before)
