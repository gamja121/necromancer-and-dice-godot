extends RefCounted
## P1-05K-1: only the source-canonical first monster king hunt arrival.
## Hunter traces, revival-mode dialogue, destination and conclusion are later.
const BASE_ART = "res://assets/map/events/monster-hunter-worldtree-base.webp"
const FIRST_BEAT = {
	"id":"arrival",
	"effect":"세계수의 뿌리 부근. 의식이 끝난 뒤에도 검은 흔적이 땅을 타고 뻗어 있다.",
	"dialogue":"",
	"speaker":"",
	"visual":"base"
}
const BEATS = [FIRST_BEAT]

static func count() -> int:
	return BEATS.size()

static func beat(index: int) -> Dictionary:
	if index<0 or index>=BEATS.size(): return {}
	return BEATS[index].duplicate(true)
