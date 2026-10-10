extends RefCounted
## P1-05H: six canonical village cultist rumor beats from HTML-final.
## The tracking quest is activated only when the player confirms the last beat.
const BASE = "res://assets/map/events/rumor-village-base.webp"
const PROCESSION = "res://assets/map/events/cultist-rumor-procession.webp"
const BEATS = [
	{"id":"arrival","effect":"밤이 깊은 마을. 평소보다 일찍 문을 닫은 집들 사이로 인기척이 드물다.","dialogue":"","speaker":"","visual":"base"},
	{"id":"procession","effect":"골목 너머로 두건을 쓴 인간들이 오염된 마물의 사체와 정체를 알 수 없는 짐을 옮기고 있다.","dialogue":"","speaker":"","visual":"procession"},
	{"id":"gossip","effect":"그들이 사라진 뒤, 숨죽이고 있던 주민이 조심스럽게 입을 연다.","dialogue":"요즘 밤마다 이상한 놈들이 성 밖으로 뭔가를 실어 나른다더군.","speaker":"주민","visual":"procession"},
	{"id":"mark","effect":"짐을 덮은 천에 새겨진 문양이 눈에 들어온다. 사냥꾼이 말했던 흔적과 같다.","dialogue":"저 문양 말이야. 다른 곳에서도 봤다는 사람이 있어.","speaker":"주민","visual":"procession"},
	{"id":"king","effect":"뜬소문처럼 흩어져 있던 이야기들이 하나의 방향을 가리키기 시작한다.","dialogue":"마물의 왕을 다시 불러내려는 자들이 있다는 말도 있어.","speaker":"주민","visual":"procession"},
	{"id":"track","effect":"같은 문양을 쓰는 자들이 향한 곳을 추적할 단서를 얻었다.","dialogue":"[광신도들의 흔적을 추적합니다.]","speaker":"시스템","visual":"procession","trackingActivated":true}
]

static func count() -> int:
	return BEATS.size()

static func beat(index: int) -> Dictionary:
	if index<0 or index>=BEATS.size(): return {}
	return BEATS[index].duplicate(true)

static func is_final(index: int) -> bool:
	return index==BEATS.size()-1

static func layer_for(visual: String) -> String:
	return PROCESSION if visual=="procession" else ""
