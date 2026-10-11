extends RefCounted
## P1-05J-6: five source portal beats and the two canonical revival endings.
## Monster king hunting scenes are a separate next story stage.

const BASE_ART = "res://assets/map/events/ritual-portal-ruins-base.webp"
const ENERGY_ART = "res://assets/map/events/ritual-portal-energy-layer.webp"
const CULTISTS_ART = "res://assets/map/events/ritual-portal-cultists-layer.webp"
const OMEN_ART = "res://assets/map/events/ritual-portal-omen-layer.webp"
const BEATS = [
	{"id":"arrival","effect":"제단에서 이어진 흔적을 따라가자 숲 깊은 폐허에서 거대한 전이문을 발견한다.","dialogue":"","speaker":"","visual":"base"},
	{"id":"portal_reveal","effect":"제단에서 보았던 문양과 같은 빛이 석문 전체를 타고 흐르며 전이문이 거세게 요동친다.","dialogue":"","speaker":"","visual":"energy"},
	{"id":"final_ritual","effect":"광신도들이 의식 재료를 문 앞에 쏟아 놓고 마지막 부활 의식을 시작한다. 전이문은 이동 통로가 아니라 왕을 불러내는 문이었다.","dialogue":"","speaker":"","visual":"cultists"},
	{"id":"omen","effect":"문 너머에서 거대한 형체가 몸을 일으킨다. 마물의 왕의 존재가 이미 현세와 맞닿기 시작했다.","dialogue":"","speaker":"","visual":"omen"},
	{"id":"intervene","effect":"의식은 마지막 단계다. 지금 광신도들을 쓰러뜨리면 완전한 부활만큼은 막을 수 있다.","dialogue":"[마물의 왕 부활 의식을 저지합니다.]","speaker":"시스템","visual":"omen","battleReady":true}
]

static func count() -> int:
	return BEATS.size()

static func beat(index: int) -> Dictionary:
	if index<0 or index>=BEATS.size(): return {}
	return BEATS[index].duplicate(true)

const INTERVENTION_EFFECT = "광신도들이 남은 힘을 전이문에 쏟아붓는다. 완전한 부활을 막기 위한 마지막 저지전이 시작된다."

## The original battle-return scene, not a new sixth portal beat.
const AFTER_BATTLE = {
	"won":{
		"effect":"의식의 핵심을 파괴했다. 하지만 이미 넘어온 왕의 존재까지 되돌리지는 못했다. 불완전한 육체로 현세에 떨어진 마물의 왕이 어둠 속으로 사라진다.",
		"dialogue":"[불완전하게 부활한 마물의 왕을 추적합니다.]",
		"speaker":"시스템",
		"visual":"omen"
	},
	"lost":{
		"effect":"저지선이 무너지자 전이문이 완전히 열린다. 마물의 왕은 온전한 힘을 되찾은 채 현세에 모습을 드러내고, 곧 어둠 속으로 사라진다.",
		"dialogue":"[완전히 부활한 마물의 왕을 추적합니다.]",
		"speaker":"시스템",
		"visual":"omen"
	}
}

static func aftermath(result: String) -> Dictionary:
	if result not in ["won","lost"]: return {}
	return AFTER_BATTLE[result].duplicate(true)

static func layer_for(visual: String) -> String:
	match visual:
		"energy": return ENERGY_ART
		"cultists": return CULTISTS_ART
		"omen": return OMEN_ART
		_: return ""
