extends RefCounted
## P1-05J-4: original arrival, energy, cultists and king-omen scenes.
## Intervention, combat and revival are strictly later beats.

const BASE_ART = "res://assets/map/events/ritual-portal-ruins-base.webp"
const ENERGY_ART = "res://assets/map/events/ritual-portal-energy-layer.webp"
const CULTISTS_ART = "res://assets/map/events/ritual-portal-cultists-layer.webp"
const OMEN_ART = "res://assets/map/events/ritual-portal-omen-layer.webp"
const BEATS = [
	{"id":"arrival","effect":"제단에서 이어진 흔적을 따라가자 숲 깊은 폐허에서 거대한 전이문을 발견한다.","dialogue":"","speaker":"","visual":"base"},
	{"id":"portal_reveal","effect":"제단에서 보았던 문양과 같은 빛이 석문 전체를 타고 흐르며 전이문이 거세게 요동친다.","dialogue":"","speaker":"","visual":"energy"},
	{"id":"final_ritual","effect":"광신도들이 의식 재료를 문 앞에 쏟아 놓고 마지막 부활 의식을 시작한다. 전이문은 이동 통로가 아니라 왕을 불러내는 문이었다.","dialogue":"","speaker":"","visual":"cultists"},
	{"id":"omen","effect":"문 너머에서 거대한 형체가 몸을 일으킨다. 마물의 왕의 존재가 이미 현세와 맞닿기 시작했다.","dialogue":"","speaker":"","visual":"omen"}
]

static func count() -> int:
	return BEATS.size()

static func beat(index: int) -> Dictionary:
	if index<0 or index>=BEATS.size(): return {}
	return BEATS[index].duplicate(true)

static func layer_for(visual: String) -> String:
	match visual:
		"energy": return ENERGY_ART
		"cultists": return CULTISTS_ART
		"omen": return OMEN_ART
		_: return ""
