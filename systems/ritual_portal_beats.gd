extends RefCounted
## P1-05J-1: only the original first ritual portal arrival scene.
## The energy/cultists/omen layers and final intervention are later beats.

const BASE_ART = "res://assets/map/events/ritual-portal-ruins-base.webp"
const BEATS = [
	{"id":"arrival","effect":"제단에서 이어진 흔적을 따라가자 숲 깊은 폐허에서 거대한 전이문을 발견한다.","dialogue":"","speaker":"","visual":"base"}
]

static func count() -> int:
	return BEATS.size()

static func beat(index: int) -> Dictionary:
	if index<0 or index>=BEATS.size(): return {}
	return BEATS[index].duplicate(true)
