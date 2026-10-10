extends RefCounted
## P1-03B: four canonical beats from the frozen HTML reference.
## The artwork for the ghoul is layered on top of the base scene.

const BASE_ART = "res://assets/map/events/graveyard-child-base-v3.webp"
const GHOUL_ART = "res://assets/map/events/graveyard-child-ghoul-event-v3.webp"
const BEATS = [
	{"id":"discovery","effect":"공동묘지 안쪽에서 길을 잃은 듯한 아이를 발견했다.","dialogue":"","ghoul":false,"choice":false},
	{"id":"threat","effect":"아이는 자꾸 뒤를 돌아본다. 묘비 사이에서 마른 돌 긁는 소리가 들린다.","dialogue":"","ghoul":true,"choice":false},
	{"id":"dialogue","effect":"묘비 사이에서 구울이 몸을 일으킨다.","dialogue":"…도와주세요!","ghoul":true,"choice":false},
	{"id":"choice","effect":"아이를 구하시겠습니까?","dialogue":"…도와주세요!","ghoul":true,"choice":true}
]

static func beat(index: int) -> Dictionary:
	if index < 0 or index >= BEATS.size(): return {}
	return BEATS[index].duplicate(true)
