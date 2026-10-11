extends RefCounted
## P1-05I-3: original three altar beats; explicit fight/pass choice is saved.
## Summon art is displayed after choosing fight; battle outcome follow-up stays separate.

const BASE = "res://assets/map/events/cultist-altar-night-base.webp"
const RITUAL = "res://assets/map/events/cultist-altar-ritual-layer.webp"
const SUMMON = "res://assets/map/events/cultist-altar-summon-layer.webp"
const SUMMON_EFFECT = "당신의 개입을 알아챈 광신도들이 의식을 비틀어 마물들을 불러낸다."
const PASS_EFFECT = "지금은 충돌을 피한다. 하지만 제단에서 보았던 의식과 문양은 분명히 기억해 둔다."
const FIGHT_WON_EFFECT = "소환된 마물들을 쓰러뜨렸다. 흐트러진 의식 도구 사이에서 다음 의식 장소를 가리키는 흔적을 발견했다."
const FIGHT_LOST_EFFECT = "소환된 마물들에게 밀려 물러났지만, 광신도들이 준비하던 부활 의식의 흔적은 확인했다."
const FOLLOWUP_DIALOGUE = "[마물의 왕 부활 의식의 흔적을 추적합니다.]"
const FOLLOWUP_SPEAKER = "시스템"

static func followup_effect(choice: String, result: String) -> String:
	if choice=="pass" and result=="": return PASS_EFFECT
	if choice=="fight" and result=="won": return FIGHT_WON_EFFECT
	if choice=="fight" and result=="lost": return FIGHT_LOST_EFFECT
	return ""

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
