extends RefCounted
## P1-05I-3: original three altar beats; explicit fight/pass choice is saved.
## No combat or post-choice quest/story consequences are triggered yet.

const BASE = "res://assets/map/events/cultist-altar-night-base.webp"
const RITUAL = "res://assets/map/events/cultist-altar-ritual-layer.webp"
const BEATS = [
	{"id":"arrival","effect":"밤의 제단. 평소라면 비어 있어야 할 장소에 촛불과 의식 도구가 놓여 있다.","dialogue":"","speaker":"","visual":"base"},
	{"id":"ritual_reveal","effect":"광신도들이 제단을 둘러싸고 마물의 왕을 위한 의식을 준비하고 있다.","dialogue":"","speaker":"","visual":"ritual"},
	{"id":"choice","effect":"아직 그들은 당신을 눈치채지 못했다.","dialogue":"","speaker":"","visual":"ritual","choice":true}
]

static func count() -> int:
	return BEATS.size()

static func beat(index: int) -> Dictionary:
	if index<0 or index>=BEATS.size(): return {}
	return BEATS[index].duplicate(true)

static func layer_for(visual: String) -> String:
	return RITUAL if visual=="ritual" else ""
