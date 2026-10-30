extends RefCounted
## P1-05D: canonical seven beats from reference/html-final/v2-map-practice.js.
## The player reply uses the existing protagonist portrait (no new image).
const COMMANDER = "res://assets/map/events/manuscript_commander_actor.png"
const PLAYER = "res://assets/map/events/manuscript_village_necromancer.png"
const BEATS = [
	{"id":"arrival","effect":"길목에서 무장한 기사가 당신을 기다리고 있었다.","dialogue":"여기 있었구만.","speaker":"기사단장","portrait":COMMANDER},
	{"id":"confirm","effect":"기사단장은 당신을 한동안 말없이 훑어본다.","dialogue":"공동묘지에서 아이를 구한 게 당신인가?","speaker":"기사단장","portrait":COMMANDER},
	{"id":"player_reply","effect":"당신은 대답 대신 잠시 그를 바라본다.","dialogue":"...","speaker":"주인공","portrait":PLAYER},
	{"id":"recognition","effect":"그의 경계가 조금 누그러진다.","dialogue":"소문은 들었다. 네가 무엇을 거느리든, 아이를 구한 일만큼은 인정하지.","speaker":"기사단장","portrait":COMMANDER},
	{"id":"contamination","effect":"기사단장은 목소리를 낮춘다.","dialogue":"문제는 다른 곳에 있다. 성 밖의 오염이 점점 짙어지고 있어.","speaker":"기사단장","portrait":COMMANDER},
	{"id":"hunter","effect":"그는 한 사람의 이름을 꺼낸다.","dialogue":"마물 사냥꾼 하나가 오염에 대해 뭔가 알고 있는 눈치더군. 그자를 찾아가 봐라.","speaker":"기사단장","portrait":COMMANDER},
	{"id":"quest","effect":"기사단장의 의뢰가 새로운 목적이 된다.","dialogue":"[오염에 대한 의뢰를 받았습니다.]","speaker":"시스템","portrait":COMMANDER,"quest_accepted":true}
]

const PROPHET_BEATS = [
	{"id":"arrival","effect":"길목에서 무장한 기사가 당신을 기다리고 있었다.","dialogue":"여기 있었구만.","speaker":"기사단장","portrait":COMMANDER},
	{"id":"contamination","effect":"기사단장은 성 밖의 길을 가리킨다.","dialogue":"성 밖의 오염이 점점 짙어지고 있다. 원인을 조사할 사람이 필요해.","speaker":"기사단장","portrait":COMMANDER},
	{"id":"reports","effect":"그는 최근 들어온 보고를 떠올린다.","dialogue":"밤마다 수상한 사람들이 마물의 사체를 옮긴다는 말이 있더군.","speaker":"기사단장","portrait":COMMANDER},
	{"id":"prophet","effect":"기사단장은 점술가의 막사가 있는 쪽을 가리킨다.","dialogue":"막사에 머무는 예언가가 그 일에 관한 목격담을 모으고 있다. 그자를 찾아가 봐라.","speaker":"기사단장","portrait":COMMANDER},
	{"id":"player_reply","effect":"당신은 그가 가리킨 방향을 바라본다.","dialogue":"...","speaker":"주인공","portrait":PLAYER},
	{"id":"investigate","effect":"기사단장은 짧게 말을 덧붙인다.","dialogue":"들은 이야기를 직접 확인해라. 소문만으로는 아무것도 단정할 수 없다.","speaker":"기사단장","portrait":COMMANDER},
	{"id":"quest","effect":"예언가를 찾아 오염의 단서를 확인할 목적이 생겼다.","dialogue":"[예언가를 찾아가는 의뢰를 받았습니다.]","speaker":"시스템","portrait":COMMANDER,"quest_accepted":true}
]

static func count(route: String = "hunter") -> int:
	return PROPHET_BEATS.size() if route=="prophet" else BEATS.size()

static func beat(index: int, route: String = "hunter") -> Dictionary:
	var selected: Array=PROPHET_BEATS if route=="prophet" else BEATS
	if index<0 or index>=selected.size(): return {}
	return selected[index].duplicate(true)

static func is_final(index: int, route: String = "hunter") -> bool:
	return index==count(route)-1
