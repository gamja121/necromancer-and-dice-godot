extends RefCounted
## P1-05B: exact narrative sequence and layer composition of HTML-final rumors.
const RUMOR_SAVED_CHILD = "rumor_saved_child_01"
const RUMOR_ABANDONED_CHILD = "rumor_abandoned_child_01"
const BASE = "res://assets/map/events/rumor-village-base.webp"
const WHISPER = "res://assets/map/events/rumor-villagers-whisper.webp"
const TURN = "res://assets/map/events/rumor-villagers-turn.webp"
const NECROMANCER = "res://assets/map/events/rumor-necromancer.webp"

const BEATS = {
	RUMOR_SAVED_CHILD: [
		{"id":"arrival","effect":"마을에 들어서자 곳곳에서 낮은 목소리의 수군거림이 들린다.","dialogue":"","speaker":"","layers":[]},
		{"id":"gossip","effect":"공동묘지에서 있었던 일이 이미 마을까지 퍼진 모양이다.","dialogue":"공동묘지에서 봤다더군. 아이를 덮치던 구울을… 다른 괴물이 죽였대.","speaker":"주민","layers":[WHISPER]},
		{"id":"detail","effect":"소문에는 사실보다 두려움이 더 빠르게 붙어 간다.","dialogue":"죽은 것들을 거느리고 있었다고 해. 사람은 아니었어.","speaker":"주민","layers":[WHISPER,TURN]},
		{"id":"noticed","effect":"한 주민이 당신을 발견한다. 수군거림이 하나둘 멎는다.","dialogue":"…쉿. 저기.","speaker":"주민","layers":[TURN,NECROMANCER]},
		{"id":"silence","effect":"아무도 당신을 영웅이라 부르지 않는다. 마을에는 ‘괴물이 아이를 구했다’는 소문만 남았다.","dialogue":"","speaker":"","layers":[TURN,NECROMANCER]}
	],
	RUMOR_ABANDONED_CHILD: [
		{"id":"arrival","effect":"마을 어귀에 들어서자, 어두운 이야기들이 낮게 흘러다닌다.","dialogue":"","speaker":"","layers":[]},
		{"id":"missing","effect":"공동묘지에서 있었던 일이 이미 마을까지 퍼진 모양이다.","dialogue":"공동묘지에서 아이 울음소리가 들렸다더군… 그런데 그 아이는 결국 마을로 돌아오지 못했대.","speaker":"주민","layers":[WHISPER]},
		{"id":"abandoned","effect":"사람들은 사실보다 더 나쁜 형태로 이야기를 덧붙인다.","dialogue":"그 자리에 이상한 괴물이 있었다고 했어. 보고도 그냥 두고 갔다더군.","speaker":"주민","layers":[WHISPER,TURN]},
		{"id":"fear","effect":"소문은 점점 하나의 확신처럼 굳어진다.","dialogue":"산 자를 구하지 않는 괴물이라면… 그건 더 위험한 거 아냐?","speaker":"주민","layers":[TURN,NECROMANCER]},
		{"id":"noticed","effect":"한 주민이 당신을 발견한다. 수군거림이 갑자기 멎는다.","dialogue":"…쉿. 저자야.","speaker":"주민","layers":[TURN,NECROMANCER]},
		{"id":"silence","effect":"마을에는 아이를 버리고 지나간 괴물에 대한 소문만 남았다.","dialogue":"","speaker":"","layers":[TURN,NECROMANCER]}
	]
}

static func count(event_id: String) -> int:
	return BEATS[event_id].size() if BEATS.has(event_id) else 0

static func beat(event_id: String, index: int) -> Dictionary:
	if not BEATS.has(event_id) or index<0 or index>=BEATS[event_id].size(): return {}
	return BEATS[event_id][index].duplicate(true)

static func is_final(event_id: String, index: int) -> bool:
	return count(event_id)>0 and index==count(event_id)-1
