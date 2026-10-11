extends RefCounted
## P1-05K-2: the source-canonical first world-tree arrival and hunter trace.
## Revival-mode dialogue, destination, and conclusion remain later beats.
const BASE_ART = "res://assets/map/events/monster-hunter-worldtree-base.webp"
const SCENE_ART = "res://assets/map/events/monster-hunter-corrupted-beast-scene.webp"
const FIRST_BEAT = {
	"id":"arrival",
	"effect":"세계수의 뿌리 부근. 의식이 끝난 뒤에도 검은 흔적이 땅을 타고 뻗어 있다.",
	"dialogue":"",
	"speaker":"",
	"visual":"base"
}
const BEATS = [
	FIRST_BEAT,
	{"id":"trace","effect":"검게 변한 뿌리 곁에 오염된 마물의 사체가 있다. 흔적을 따라가던 마물 사냥꾼이 그 앞에 서 있다.","dialogue":"","speaker":"","visual":"scene"}
]

static func count() -> int:
	return BEATS.size()

static func beat(index: int) -> Dictionary:
	if index<0 or index>=BEATS.size(): return {}
	return BEATS[index].duplicate(true)

static func visual_art(visual: String) -> String:
	return SCENE_ART if visual=="scene" else ""
