extends RefCounted
## P1-05K-5: fifth original location scene. Completion unlocks the final
## battle quest flag, but the actual king battle is a later system.
const BASE_ART = "res://assets/map/events/manuscript_hunt_base.png"
const SCENE_ART = "res://assets/map/events/manuscript_hunt_scene.png"
const PORTRAIT_ART = "res://assets/map/events/manuscript_hunt_scene.png"
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
const LOCATED_BEAT = {
	"id":"located",
	"effect":"숲속 봉인 폐허의 위치를 파악했다. 추적은 끝났지만 왕과의 싸움은 아직 시작되지 않았다.",
	"dialogue":"[마물의 왕이 향한 봉인 폐허의 위치를 알아냈습니다.]",
	"speaker":"시스템",
	"visual":"scene",
	"locationKnown":true
}
const REVIVAL = {
	"weakened":{"id":"revival","effect":"마물 사냥꾼이 끊겼다 이어진 흔적을 가리킨다.","dialogue":"몸이 아직 온전하지 않아. 하지만 멀리 가진 못했어.","speaker":"마물 사냥꾼","visual":"portrait"},
	"full":{"id":"revival","effect":"세계수의 뿌리까지 죽어 가고 있다. 사냥꾼은 주변의 오염을 살핀다.","dialogue":"뿌리 깊은 곳까지 죽었군. 저 힘으로 놈을 상대해야 한다니.","speaker":"마물 사냥꾼","visual":"portrait"}
}

const RUIN_EFFECTS = {
	"winter":{
		0:"세계수가 쓰러진 자리. 얼어붙은 그루터기 아래로 검은 자국이 이어져 있다.",
		1:"서리가 내려앉은 그루터기 곁에 오염된 마물의 사체가 있다. 마물 사냥꾼이 그 앞에 서 있다.",
		2:"얼어붙은 뿌리 사이로 검은 흔적이 번져 있다. 사냥꾼은 주변의 오염을 살핀다.",
		4:"폐허로 향하던 흔적이 웜홀 앞에서 끊겼다. 안쪽에서 그루터기 아래에 남은 것과 같은 빛이 새어 나온다."
	},
	"hell":{
		0:"세계수가 타 버린 자리. 잿더미 사이로 검은 자국이 이어져 있다.",
		1:"그을린 뿌리 곁에 오염된 마물의 사체가 있다. 마물 사냥꾼이 그 앞에 서 있다.",
		2:"그을린 뿌리 사이로 검은 흔적이 번져 있다. 사냥꾼은 주변의 오염을 살핀다.",
		4:"폐허로 향하던 흔적이 웜홀 앞에서 끊겼다. 안쪽에서 잿더미에 남은 것과 같은 빛이 새어 나온다."
	}
}
const RUIN_HUNTER_DIALOGUE = "뿌리 깊은 곳까지 번졌군. 저 힘으로 놈을 상대해야 한다니."

static func count() -> int:
	return 5

static func beat(index: int, revival_mode: String = "", region: String = "default") -> Dictionary:
	if index<0 or index>=count(): return {}
	var source: Dictionary
	match index:
		4: source=LOCATED_BEAT
		3: source=DESTINATION_BEAT
		2:
			if not REVIVAL.has(revival_mode): return {}
			source=REVIVAL[revival_mode]
		_: source=BEATS[index]
	var scene: Dictionary=source.duplicate(true)
	var ruins: Dictionary=RUIN_EFFECTS.get(region,{})
	if ruins.has(index) and (index!=2 or revival_mode=="full"):
		scene.effect=ruins[index]
		if index==2: scene.dialogue=RUIN_HUNTER_DIALOGUE
	return scene

static func visual_art(visual: String) -> String:
	if visual=="scene": return SCENE_ART
	if visual=="portrait": return PORTRAIT_ART
	return ""
