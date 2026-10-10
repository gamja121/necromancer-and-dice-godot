extends RefCounted
## P1-05D: canonical seven beats from reference/html-final/v2-map-practice.js.
## The player reply uses the existing protagonist portrait (no new image).
const COMMANDER = "res://assets/map/events/knight-commander-upperbody-hd.webp"
const PLAYER = "res://assets/map/events/necromancer-upperbody-hd.webp"
const BEATS = [
	{"id":"arrival","effect":"길목에서 무장한 기사가 당신을 기다리고 있었다.","dialogue":"여기 있었구만.","speaker":"기사단장","portrait":COMMANDER},
	{"id":"confirm","effect":"기사단장은 당신을 한동안 말없이 훑어본다.","dialogue":"공동묘지에서 아이를 구한 게 당신인가?","speaker":"기사단장","portrait":COMMANDER},
	{"id":"player_reply","effect":"당신은 대답 대신 잠시 그를 바라본다.","dialogue":"...","speaker":"주인공","portrait":PLAYER},
	{"id":"recognition","effect":"그의 경계가 조금 누그러진다.","dialogue":"소문은 들었다. 네가 무엇을 거느리든, 아이를 구한 일만큼은 인정하지.","speaker":"기사단장","portrait":COMMANDER},
	{"id":"contamination","effect":"기사단장은 목소리를 낮춘다.","dialogue":"문제는 다른 곳에 있다. 성 밖의 오염이 점점 짙어지고 있어.","speaker":"기사단장","portrait":COMMANDER},
	{"id":"hunter","effect":"그는 한 사람의 이름을 꺼낸다.","dialogue":"마물 사냥꾼 하나가 오염에 대해 뭔가 알고 있는 눈치더군. 그자를 찾아가 봐라.","speaker":"기사단장","portrait":COMMANDER},
	{"id":"quest","effect":"기사단장의 의뢰가 새로운 목적이 된다.","dialogue":"[오염에 대한 의뢰를 받았습니다.]","speaker":"시스템","portrait":COMMANDER,"quest_accepted":true}
]

static func count() -> int:
	return BEATS.size()

static func beat(index: int) -> Dictionary:
	if index<0 or index>=BEATS.size(): return {}
	return BEATS[index].duplicate(true)

static func is_final(index: int) -> bool:
	return index==BEATS.size()-1
