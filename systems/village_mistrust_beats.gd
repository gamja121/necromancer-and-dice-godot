extends RefCounted
## An eyewitness saw cooperation; the village never heard the investigation.
const BASE = "res://assets/map/events/manuscript_village_base.png"
const VILLAGERS = "res://assets/map/events/manuscript_village_villagers.png"
const PLAYER = "res://assets/map/events/manuscript_village_necromancer.png"
const BEATS = [
	{"id":"arrival","effect":"마을 어귀의 주민들이 당신을 보자 목소리를 낮춘다. 제단으로 향하던 길에서 본 사람이 이야기를 전한 모양이다.","dialogue":"","speaker":"","layers":[]},
	{"id":"eyewitness","effect":"주민 하나가 숲길 쪽을 가리킨다.","dialogue":"봤다는 사람이 있어. 저자가 두건 쓴 놈들과 함께 사체 수레를 밀고 있었다더군.","speaker":"주민","layers":[VILLAGERS]},
	{"id":"distortion","effect":"누군가 목격담에 공동묘지의 소문을 보탠다.","dialogue":"그럼 돌아오지 않은 아이도… 저들과 관계있는 거 아냐?","speaker":"주민","layers":[VILLAGERS]},
	{"id":"doubt","effect":"옆의 주민이 섣부른 말을 끊는다.","dialogue":"직접 봤다는 건 수레 곁에 있었다는 것뿐이잖아. 아이 일까지 엮을 증거는 없어.","speaker":"다른 주민","layers":[VILLAGERS]},
	{"id":"fear","effect":"반론이 나오지만 두려움은 쉽게 가라앉지 않는다.","dialogue":"함께 있었던 건 맞다며. 아이 앞에서도 그냥 지나갔다던 자야. 가까이하지 않는 게 좋겠어.","speaker":"주민","layers":[VILLAGERS]},
	{"id":"noticed","effect":"당신이 다가서자 주민들은 말을 멈추고 문 안으로 물러난다. 아무도 먼저 말을 걸지 않는다.","dialogue":"","speaker":"","layers":[VILLAGERS,PLAYER]},
	{"id":"mistrust","effect":"당신이 알아낸 행선지는 소문에 실리지 않았다. 광신도들과 함께 사체를 옮겼다는 이야기만 남아, 주민들의 불신이 커졌다.","dialogue":"","speaker":"","layers":[VILLAGERS,PLAYER]}
]

static func count() -> int:
	return BEATS.size()

static func beat(index: int) -> Dictionary:
	if index<0 or index>=count(): return {}
	return BEATS[index].duplicate(true)

static func is_final(index: int) -> bool:
	return index==count()-1
