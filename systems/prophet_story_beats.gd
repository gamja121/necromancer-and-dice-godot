extends RefCounted
## Reports and uncertain images reveal a human trail, not the child's fate
## or any hidden identity. The final acknowledgement owns the actual clue.
const BASE = "res://assets/map/events/manuscript_prophet_base.png"
const PROPHET = "res://assets/map/events/manuscript_prophet_actor.png"
const PLAYER = "res://assets/map/events/manuscript_village_necromancer.png"
const BEATS = [
	{"id":"arrival","effect":"점술가의 막사 안. 낡은 천 사이로 희미한 보랏빛이 새어 나온다.","dialogue":"","speaker":"","visual":"base"},
	{"id":"reveal","effect":"기운 두건 아래 주름진 얼굴이 드러난다. 예언가의 손안에서 수정구가 보랏빛으로 일렁인다.","dialogue":"","speaker":"","visual":"portrait"},
	{"id":"greeting","effect":"예언가는 수정구에서 눈을 떼고 당신을 바라본다.","dialogue":"기사단장이 보냈느냐. 밤길의 소문을 물으러 왔겠구나.","speaker":"예언가","visual":"portrait"},
	{"id":"reports","effect":"탁자에는 여행자들이 남긴 짧은 증언과 문양을 베낀 천 조각이 놓여 있다.","dialogue":"밤마다 마물의 사체를 옮기는 사람들을 봤다는 이들이 있다. 서로 다른 길에서도 같은 문양을 달고 있었다더구나.","speaker":"예언가","visual":"portrait"},
	{"id":"vision","effect":"수정구 안에 어둑한 길과 무거운 짐을 끄는 흐릿한 형상이 스친다.","dialogue":"내가 본 것도 짐을 나르는 사람들의 그림자뿐이다. 무엇을 꾸미는지까지 보여 주지는 않더구나.","speaker":"예언가","visual":"portrait"},
	{"id":"symbol","effect":"예언가는 천 조각에 베껴진 문양을 당신이 볼 수 있도록 돌려놓는다.","dialogue":"이 문양을 기억해라. 마물의 발자국만 쫓지 말고, 사체를 나르는 사람들을 찾아보거라.","speaker":"예언가","visual":"portrait"},
	{"id":"player_reply","effect":"당신은 천에 새겨진 선을 눈에 담는다.","dialogue":"...","speaker":"주인공","visual":"player"},
	{"id":"caution","effect":"예언가는 다시 수정구를 두 손으로 감싼다.","dialogue":"목격담도 내가 본 그림자도 전부는 아니다. 마을에서 그 문양을 다시 보거든, 네 눈으로 확인해라.","speaker":"예언가","visual":"portrait"},
	{"id":"clue","effect":"오염된 마물의 사체를 옮기는 인간들과 그들이 쓰는 문양에 대한 단서를 얻었다.","dialogue":"[오염을 퍼뜨리는 자들에 대한 단서를 얻었습니다.]","speaker":"시스템","visual":"portrait","clue_obtained":true}
]

static func count() -> int:
	return BEATS.size()

static func beat(index: int) -> Dictionary:
	if index<0 or index>=BEATS.size(): return {}
	return BEATS[index].duplicate(true)

static func is_final(index: int) -> bool:
	return index==BEATS.size()-1

static func visual_art(visual: String) -> String:
	match visual:
		"portrait": return PROPHET
		"player": return PLAYER
	return ""
