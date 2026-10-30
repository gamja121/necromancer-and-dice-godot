extends RefCounted
## P1-05I-3: original three altar beats; explicit fight/pass choice is saved.
## Summon art is displayed after choosing fight; battle outcome follow-up stays separate.

const BASE = "res://assets/map/events/manuscript_altar_base.png"
const RITUAL = "res://assets/map/events/manuscript_altar_ritual.png"
const SUMMON = "res://assets/map/events/manuscript_altar_summon.png"
const SUMMON_EFFECT = "당신의 개입을 알아챈 광신도들이 의식을 비틀어 마물들을 불러낸다."
const PASS_EFFECT = "지금은 충돌을 피한다. 하지만 제단에서 보았던 의식과 문양은 분명히 기억해 둔다."
const FIGHT_WON_EFFECT = "소환된 마물들을 쓰러뜨렸다. 흐트러진 의식 도구 사이에서 다음 의식 장소를 가리키는 흔적을 발견했다."
const FIGHT_LOST_EFFECT = "소환된 마물들에게 밀려 물러났지만, 광신도들이 준비하던 부활 의식의 흔적은 확인했다."
const FOLLOWUP_DIALOGUE = "[마물의 왕 부활 의식의 흔적을 추적합니다.]"
const FOLLOWUP_SPEAKER = "시스템"
const INVESTIGATE_CHOICE = "협력하는 척한다"
const INQUIRY_ART = "res://assets/map/events/manuscript_cultist_inquiry_scene.png"
const INVESTIGATE_WARNING = "예언가가 알려 준 문양이 보인다. 일행에 섞이면 다음 행선지를 알아낼 수 있겠지만, 누군가에겐 한패로 보일 수 있다."
const INFILTRATION_BEATS = [
	{"id":"offer","effect":"당신은 문양을 확인하려는 뜻을 숨기고 일행에게 다가간다. 광신도 하나가 비탈 아래 멈춘 수레를 가리킨다.","dialogue":"안으로 가려면 저 수레부터 올려라. 짐만 옮기고 의식에는 끼어들지 마라.","speaker":"광신도","visual":"ritual"},
	{"id":"cart","effect":"당신의 마물들이 천으로 덮인 사체 수레를 비탈 위로 민다. 당신은 곁을 걸으며 광신도들의 말을 듣는다.","dialogue":"다음 짐은 숲 안쪽 전이문이 있는 폐허로 보낸다. 이 문양이 찍힌 천을 따라가면 돼.","speaker":"광신도","visual":"inquiry"},
	{"id":"witness","effect":"숲 가장자리에서 나뭇짐을 진 사람이 발을 멈춘다. 당신과 수레를 번갈아 본 뒤, 그 사람은 마을 쪽으로 달아난다.","dialogue":"","speaker":"","visual":"inquiry"},
	{"id":"depart","effect":"행선지를 알아낸 당신은 일행과 갈라선다. 멀어진 목격자에게는 당신이 조사하려던 뜻도 떠나는 모습도 전해지지 않았다.","dialogue":"","speaker":"","visual":"base"},
	{"id":"clue","effect":"다음 의식 장소의 흔적을 얻었다. 한편, 누군가는 당신이 광신도들과 함께 사체 수레를 옮기는 모습을 보았다.","dialogue":"[부활 의식의 흔적을 추적합니다.]","speaker":"시스템","visual":"base"}
]

static func infiltration_count() -> int:
	return INFILTRATION_BEATS.size()

static func infiltration_beat(index: int) -> Dictionary:
	if index<0 or index>=infiltration_count(): return {}
	return INFILTRATION_BEATS[index].duplicate(true)

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
