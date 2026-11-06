extends RefCounted

const SEEN = "story:monster_king:warp_encounter_seen"
const BEAT_ONE = "story:monster_king:warp_encounter_beat:1"
const BEAT_TWO = "story:monster_king:warp_encounter_beat:2"
const ACK = "story:monster_king:warp_encounter_ack"
const ENTRY = "wormhole"
const BEATS = [
	{"title":"봉인 폐허의 균열","effect":"세계수의 검은 자국이 웜홀 안으로 이어진다.\n균열 너머로 무너진 돌기둥이 보인다."},
	{"title":"왕의 응시","effect":"의식터에서 본 거대한 형체가 기둥 사이로 모습을 드러냈다. 고룡이 천천히 고개를 돌렸다."},
	{"title":"최후의 대면","effect":"고룡이 날개를 펴자 돌조각이 발치까지 굴러왔다."},
]

static func can_enter(session, index: int) -> bool:
	var world = session.world
	if world==null or index<0 or index!=world.position or index!=world.final_dragon_location(): return false
	return session.encounter.is_empty() and world.active_encounter.is_empty() and world.pending_move.is_empty() and world.pending_reward.is_empty()

static func beat(world) -> int:
	if world.event_flags.get(SEEN,false)!=true: return -1
	if world.event_flags.get(BEAT_ONE,false)!=true: return 0
	return 2 if world.event_flags.get(BEAT_TWO,false)==true else 1

static func begin(session, index: int) -> bool:
	if not can_enter(session,index): return false
	return beat(session.world)>=0 or session.set_event_flag(SEEN)

static func advance(session, index: int, shown: int) -> bool:
	if not can_enter(session,index) or shown not in [0,1] or beat(session.world)!=shown: return false
	return session.set_event_flag(BEAT_ONE if shown==0 else BEAT_TWO)

static func acknowledge(session, index: int) -> bool:
	if not can_enter(session,index) or beat(session.world)!=2: return false
	return session.set_event_flag(ACK)

static func battle_ready(session, index: int) -> bool:
	return can_enter(session,index) and beat(session.world)==2 and session.world.event_flags.get(ACK,false)==true
