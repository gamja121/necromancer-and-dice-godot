extends RefCounted
## The commander separates the eyewitness account from the village's fear.
const ART = "res://assets/map/events/manuscript_commander_inquiry_scene.png"
const EXPLAIN_CHOICE = "조사 경위를 설명한다"
const WITHHOLD_CHOICE = "조사 경위를 숨긴다"
const BEATS = [
	{"id":"arrival","effect":"마을 길목에서 경비병이 당신을 부른다. 소문을 들은 기사단장이 주민들의 시선 앞에 서 있다.","dialogue":"","speaker":""},
	{"id":"account","effect":"기사단장은 경비병에게 물러서라 손짓하고, 당신을 바라본다.","dialogue":"광신도들과 사체 수레를 옮겼다는 목격담이 왔다. 아이에 대한 소문까지 뒤섞였더군.","speaker":"기사단장"},
	{"id":"question","effect":"그는 소문과 목격담을 구별한 뒤, 당신의 설명을 기다린다.","dialogue":"내가 조사를 맡겼으니 네 말부터 듣겠다. 수레는 왜 옮긴 건가?","speaker":"기사단장"}
]
const RESPONSES = {
	"explain":[
		{"id":"explain","effect":"예언가가 보여 준 문양과 제단에서 들은 행선지를 설명한다. 수레를 옮긴 것은 의식 장소를 알아내기 위해서였다고 밝힌다.","dialogue":"","speaker":""},
		{"id":"defer","effect":"기사단장은 경위를 받아 적게 한다. 그러나 당신의 설명만으로 목격담이 사라지는 것은 아니다.","dialogue":"네 설명도 보고에 남기겠다. 예언가와 목격자의 말을 따로 확인하기 전까지 판단을 미루지.","speaker":"기사단장"},
		{"id":"recorded","effect":"조사 경위가 공식 기록에 남았다. 기사단장은 판단을 보류했지만, 멀리서 지켜보던 주민들의 경계는 아직 풀리지 않았다.","dialogue":"","speaker":""}
	],
	"withhold":[
		{"id":"withhold","effect":"조사 내용을 어디까지 믿고 맡겨도 될지 알 수 없다. 문양과 행선지를 밝히지 않은 채, 수레를 옮긴 까닭에도 답하지 않는다.","dialogue":"","speaker":""},
		{"id":"watch","effect":"기사단장은 잠시 기다리다가 경비병을 부른다. 침묵은 목격담에 대한 반박으로 기록되지 못한다.","dialogue":"소문만으로 죄를 묻진 않겠다. 다만 경위를 확인할 때까지 네 행적을 살피도록 하겠다.","speaker":"기사단장"},
		{"id":"watched","effect":"보고에는 목격담과 해명을 듣지 못했다는 사실이 남았다. 경비병의 눈길을 본 주민들은 수군거린다. 불신에 감시가 더해졌다.","dialogue":"","speaker":""}
	]
}

static func count() -> int:
	return 6

static func beat(index: int, choice: String="") -> Dictionary:
	if index<0 or index>=count(): return {}
	if index<BEATS.size(): return BEATS[index].duplicate(true)
	if not RESPONSES.has(choice): return {}
	return RESPONSES[choice][index-BEATS.size()].duplicate(true)

static func is_final(index: int) -> bool:
	return index==count()-1
