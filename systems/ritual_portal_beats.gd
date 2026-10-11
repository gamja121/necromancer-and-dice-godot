extends RefCounted
## P1-05J-2: first arrival and original portal-energy reveal only.
## The cultists/omen layers, battle and revival are later beats.

const BASE_ART = "res://assets/map/events/ritual-portal-ruins-base.webp"
const ENERGY_ART = "res://assets/map/events/ritual-portal-energy-layer.webp"
const BEATS = [
	{"id":"arrival","effect":"제단에서 이어진 흔적을 따라가자 숲 깊은 폐허에서 거대한 전이문을 발견한다.","dialogue":"","speaker":"","visual":"base"},
	{"id":"portal_reveal","effect":"제단에서 보았던 문양과 같은 빛이 석문 전체를 타고 흐르며 전이문이 거세게 요동친다.","dialogue":"","speaker":"","visual":"energy"}
]

static func count() -> int:
	return BEATS.size()

static func beat(index: int) -> Dictionary:
	if index<0 or index>=BEATS.size(): return {}
	return BEATS[index].duplicate(true)

static func layer_for(visual: String) -> String:
	return ENERGY_ART if visual=="energy" else ""
