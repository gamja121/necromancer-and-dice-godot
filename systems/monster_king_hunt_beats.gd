extends RefCounted
## P1-05K-4: source-canonical fourth destination clue after saved hunter dialogue.
## Exact ruins location, hunt completion and final king battle remain locked.
const BASE_ART = "res://assets/map/events/monster-hunter-worldtree-base.webp"
const SCENE_ART = "res://assets/map/events/monster-hunter-corrupted-beast-scene.webp"
const PORTRAIT_ART = "res://assets/map/events/monster-hunter-pen-clean.webp"
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
const DESTINATION_BEAT = {
	"id":"destination",
	"effect":"오염된 흔적이 숲 너머의 오래된 봉인 폐허를 향해 이어진다.",
	"dialogue":"왕은 그 폐허로 향했어. 봉인이 남아 있던 곳이지.",
	"speaker":"마물 사냥꾼",
	"visual":"portrait"
}
const REVIVAL = {
	"weakened":{"id":"revival","effect":"마물 사냥꾼이 끊겼다 이어진 흔적을 가리킨다.","dialogue":"몸이 아직 온전하지 않아. 하지만 멀리 가진 못했어.","speaker":"마물 사냥꾼","visual":"portrait"},
	"full":{"id":"revival","effect":"세계수의 뿌리까지 죽어 가고 있다. 사냥꾼은 주변의 오염을 살핀다.","dialogue":"뿌리 깊은 곳까지 죽었군. 저 힘으로 놈을 상대해야 한다니.","speaker":"마물 사냥꾼","visual":"portrait"}
}

static func count() -> int:
	return 4

static func beat(index: int, revival_mode: String = "") -> Dictionary:
	if index==3: return DESTINATION_BEAT.duplicate(true)
	if index==2:
		if not REVIVAL.has(revival_mode): return {}
		return REVIVAL[revival_mode].duplicate(true)
	if index<0 or index>=BEATS.size(): return {}
	return BEATS[index].duplicate(true)

static func visual_art(visual: String) -> String:
	if visual=="scene": return SCENE_ART
	if visual=="portrait": return PORTRAIT_ART
	return ""
