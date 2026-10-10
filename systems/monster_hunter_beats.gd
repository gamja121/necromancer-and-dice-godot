extends RefCounted
## P1-05F: 11 canonical monster-hunter beats from HTML final.
## Complete hunter quest, human-involvement clue and story ONLY after a
## deliberate final acknowledgement, not on displaying the last beat.
const BASE = "res://assets/map/events/monster-hunter-worldtree-base.webp"
const SCENE = "res://assets/map/events/monster-hunter-corrupted-beast-scene.webp"
const HUNTER = "res://assets/map/events/monster-hunter-pen-clean.webp"
const PLAYER = "res://assets/map/events/necromancer-upperbody-hd.webp"
const BEATS = [
	{"id":"arrival","effect":"세계수 성역 안쪽. 오래된 성역 사이로 불길한 오염의 흔적이 이어져 있다.","dialogue":"","speaker":"","visual":"base"},
	{"id":"warning_reveal","effect":"다음 순간, 오염된 마물의 사체를 조사하던 노인이 당신의 기척을 알아챈다.","dialogue":"","speaker":"","visual":"scene"},
	{"id":"warning","effect":"노인이 천천히 당신 쪽으로 고개를 돌린다.","dialogue":"거기서 멈춰.","speaker":"마물 사냥꾼","visual":"scene"},
	{"id":"identify","effect":"그가 천천히 고개를 들고 당신을 훑어본다.","dialogue":"죽은 것들을 끌고 다니는 놈이 있다는 소문은 들었는데… 네가 그놈이군.","speaker":"마물 사냥꾼","visual":"portrait"},
	{"id":"player_reply","effect":"당신은 아무 말 없이 그를 바라본다.","dialogue":"...","speaker":"주인공","visual":"player"},
	{"id":"sent_by_commander","effect":"사냥꾼은 다시 오염된 사체 쪽으로 시선을 돌린다.","dialogue":"기사단장이 보냈나? 오염에 대해 묻고 싶은 거겠지.","speaker":"마물 사냥꾼","visual":"portrait"},
	{"id":"unnatural","effect":"보랏빛 오염이 사체의 상처를 따라 비정상적으로 굳어 있다.","dialogue":"이건 자연스럽게 퍼지는 게 아니야.","speaker":"마물 사냥꾼","visual":"scene"},
	{"id":"gathered","effect":"오염된 마물들이 같은 방향으로 모였다는 흔적이 남아 있다.","dialogue":"누군가 오염된 마물들을 모으고 있다. 일부러 말이지.","speaker":"마물 사냥꾼","visual":"scene"},
	{"id":"mark","effect":"사냥꾼은 여러 현장에서 반복해서 본 흔적을 떠올린다.","dialogue":"놈들이 남긴 흔적을 몇 번 봤다. 같은 문양을 쓰더군.","speaker":"마물 사냥꾼","visual":"portrait"},
	{"id":"human","effect":"오염 뒤에 마물이 아닌 누군가의 의지가 있음을 알게 된다.","dialogue":"사람들이야. 마물이 아니라.","speaker":"마물 사냥꾼","visual":"portrait"},
	{"id":"clue","effect":"오염을 의도적으로 퍼뜨리는 자들에 대한 단서를 확보했다.","dialogue":"[오염을 퍼뜨리는 자들에 대한 단서를 얻었습니다.]","speaker":"시스템","visual":"scene","clue_obtained":true}
]

static func count() -> int:
	return BEATS.size()

static func beat(index: int) -> Dictionary:
	if index<0 or index>=BEATS.size(): return {}
	return BEATS[index].duplicate(true)

static func is_final(index: int) -> bool:
	return index==BEATS.size()-1

static func visual_art(visual: String) -> String:
	match visual:
		"scene": return SCENE
		"portrait": return HUNTER
		"player": return PLAYER
	return ""
